import 'dart:convert';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

import '../models/table_model.dart';
import '../models/product_model.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';
import '../models/daily_revenue_model.dart';
// GEREKLİ IMPORT: VeresiyeModel'i kullanabilmek için eklendi
import '../screens/veresiye_screen.dart';
import '../models/category_model.dart'; // YENİ: Kategori modelini ekledik

class DatabaseHelper {
  static Database? _database;
  static const _databaseName = "masa_takip_app.db";
  // Veritabanı sürümünü 13'e yükseltiyoruz (Ürün Resimleri ve Acıklamalar için)
  static const _databaseVersion = 13;

  // Tablo isimleri
  static const tableTables = 'tables';
  static const tableProducts = 'products';
  static const tableCategories = 'categories'; // YENİ: Kategori tablosu adı
  static const tableMainOrders = 'main_orders';
  static const tableOrderItems = 'order_items';
  static const tableDailyRevenues = 'daily_revenues';
  static const tableClosedOrders = 'closed_orders';
  // YENİ TABLO: Veresiye kayıtları için eklendi
  static const tableVeresiye = 'veresiye_kayitlari';
  static const tableSections = 'table_sections'; // YENİ: Masa bölgeleri tablosu
  static const tableAppLogs = 'app_logs'; // YENİ: İşlem geçmişi tablosu

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Veritabanı şemasını oluşturma (Uygulama ilk kez kurulduğunda çalışır)
  Future _onCreate(Database db, int version) async {
    // Kategori tablosu (YENİ - Hata çözümü için en başa alındı)
    await db.execute('''
      CREATE TABLE $tableCategories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    // Masalar tablosu
    await db.execute('''
      CREATE TABLE $tableTables (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        isOccupied INTEGER NOT NULL,
        startTime TEXT,
        totalRevenue REAL NOT NULL DEFAULT 0.0,
        position INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        sectionId TEXT -- YENİ: Bölge ID alanı
      )
    ''');

    // Ürünler tablosu
    await db.execute('''
      CREATE TABLE $tableProducts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        salesCount INTEGER NOT NULL DEFAULT 0,
        categoryId TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        imageUrl TEXT NOT NULL DEFAULT ''
      )
    ''');

    // Ana Siparişler tablosu
    await db.execute('''
      CREATE TABLE $tableMainOrders (
        id INTEGER PRIMARY KEY,
        tableId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (tableId) REFERENCES $tableTables(id) ON DELETE CASCADE
      )
    ''');

    // Sipariş Ürün Kalemleri tablosu
    await db.execute('''
      CREATE TABLE $tableOrderItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        productPrice REAL NOT NULL,
        quantity INTEGER NOT NULL,
        isSpecialProduct INTEGER NOT NULL,
        FOREIGN KEY (orderId) REFERENCES $tableMainOrders(id) ON DELETE CASCADE
      )
    ''');

    // Günlük Cirolar tablosu
    await db.execute('''
      CREATE TABLE $tableDailyRevenues (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        revenue REAL NOT NULL
      )
    ''');

    // Kapatılmış oturumlar tablosu (history)
    await db.execute('''
      CREATE TABLE $tableClosedOrders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableId TEXT NOT NULL,
        tableName TEXT NOT NULL,
        startTime TEXT,
        endTime TEXT,
        durationSeconds INTEGER NOT NULL,
        total REAL NOT NULL,
        itemsJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        note TEXT
      )
    ''');

    // YENİ: Masa Bölümleri (Sekmeler) tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    
    // Varsayılan bir bölge oluştur (Genel)
    await db.insert(tableSections, {
      'id': 'default_section',
      'name': 'Genel',
    });

    // İşlem Günlükleri (Logs) tablosu
    await db.execute('''
      CREATE TABLE $tableAppLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userName TEXT NOT NULL,
        actionType TEXT NOT NULL,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // Veritabanı yükseltme metodu (Mevcut kullanıcılar için çalışır)
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE $tableTables ADD COLUMN position INTEGER NOT NULL DEFAULT 0;");
    }

    if (oldVersion < 4) {
      await db.execute('''
            ALTER TABLE $tableProducts
            ADD COLUMN categoryId TEXT NOT NULL DEFAULT ''
        ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableClosedOrders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tableId TEXT NOT NULL,
          tableName TEXT NOT NULL,
          startTime TEXT,
          endTime TEXT,
          durationSeconds INTEGER NOT NULL,
          total REAL NOT NULL,
          itemsJson TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      await db.execute("ALTER TABLE $tableTables ADD COLUMN note TEXT;");
    }

    if (oldVersion < 7) {
      await db.execute("ALTER TABLE $tableClosedOrders ADD COLUMN note TEXT;");
    }

    // Sürüm 9'dan düşükse Veresiye tablosunu ekle
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableVeresiye (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerName TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          itemsJson TEXT NOT NULL,
          note TEXT,
          date TEXT NOT NULL,
          isPaid INTEGER NOT NULL DEFAULT 0
        )
      ''');
      // Kategori tablosu da eksikse eklenmeli
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCategories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 11) {
      // Masa Bölümleri tablosunu oluştur
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSections (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      
      // Mevcut masalar tablosuna sectionId ekle
      try {
        await db.execute("ALTER TABLE $tableTables ADD COLUMN sectionId TEXT;");
      } catch (e) {
        print("sectionId sütunu zaten mevcut olabilir: $e");
      }
      
      // Varsayılan bir bölge oluştur (Genel)
      const String defaultSectionId = 'default_section';
      await db.insert(tableSections, {
        'id': defaultSectionId,
        'name': 'Genel',
      });
      
      // Mevcut tüm masaları bu bölgeye ata
      await db.update(tableTables, {'sectionId': defaultSectionId});
    }

    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableAppLogs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userName TEXT NOT NULL,
          actionType TEXT NOT NULL,
          details TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 13) {
      await db.execute("ALTER TABLE $tableProducts ADD COLUMN description TEXT NOT NULL DEFAULT '';");
      await db.execute("ALTER TABLE $tableProducts ADD COLUMN imageUrl TEXT NOT NULL DEFAULT '';");
    }
  }

  // ---- Masa CRUD İşlemleri ----
  Future<int> insertTable(TableModel table) async {
    Database db = await instance.database;
    return await db.insert(tableTables, table.toMap());
  }

  Future<List<TableModel>> getTables() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTables,
      orderBy: 'position ASC',
    );

    List<TableModel> tables = [];
    for (var map in maps) {
      // Varsayımsal olarak TableModel'i import ettiniz.
      // tables.add(TableModel.fromMap(map));
      tables.add(TableModel.fromMap(map as Map<String, dynamic>));
    }
    return tables;
  }

  Future<int> updateTable(TableModel table) async {
    Database db = await instance.database;
    return await db.update(
      tableTables,
      table.toMap(),
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  Future<void> updateTablePositions(List<TableModel> tables) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < tables.length; i++) {
        final table = tables[i];
        await txn.update(
          tableTables,
          {'position': table.position},
          where: 'id = ?',
          whereArgs: [table.id],
        );
      }
    });
  }

  Future<int> deleteTable(String id) async { // ADDED: Missing deleteTable method
    Database db = await instance.database;
    return await db.delete(
      tableTables,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearTable(String tableId) async {
    final activeOrder = await getActiveOrderByTableId(tableId);
    if (activeOrder != null && activeOrder.id != null) {
      await deleteMainOrder(activeOrder.id!);
    }
  }

  Future<void> moveTable(String fromId, String toId) async {
    final activeOrder = await getActiveOrderByTableId(fromId);
    if (activeOrder != null) {
      final updatedOrder = activeOrder.copyWith(tableId: toId);
      await updateMainOrder(updatedOrder);
    }
  }

  // --- Ürün CRUD İşlemleri ---
  Future<int> insertProduct(ProductModel product) async {
    Database db = await instance.database;
    return await db.insert(tableProducts, product.toMap());
  }

  Future<List<ProductModel>> getProducts() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableProducts);
    return List.generate(maps.length, (i) {
      return ProductModel.fromMap(maps[i]);
    });
  }

  Future<int> updateProduct(ProductModel product) async {
    Database db = await instance.database;
    return await db.update(
      tableProducts,
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(String id) async {
    Database db = await instance.database;
    return await db.delete(
      tableProducts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Kategori CRUD İşlemleri ---
  // ProductProvider'da bu metotlara ihtiyaç duyulduğu varsayılıyor
  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert(tableCategories, category.toJson());
  }

  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCategories);
    return List.generate(maps.length, (i) {
      return CategoryModel.fromJson(maps[i]);
    });
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return await db.update(
      tableCategories,
      category.toJson(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    return await db.delete(
      tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // --- Kategori CRUD İşlemleri Sonu ---

  // --- Masa Bölümleri (Section) CRUD İşlemleri ---
  Future<int> insertSection(String name) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return await db.insert(tableSections, {
      'id': id,
      'name': name,
    });
  }

  Future<List<Map<String, dynamic>>> getSections() async {
    final db = await database;
    return await db.query(tableSections);
  }

  Future<int> updateSection(String id, String name) async {
    final db = await database;
    return await db.update(
      tableSections,
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSection(String id) async {
    final db = await database;
    // Bu bölgedeki masaları 'default_section' bölgesine taşıyalım.
    await db.update(
      tableTables,
      {'sectionId': 'default_section'},
      where: 'sectionId = ?',
      whereArgs: [id],
    );
    
    return await db.delete(
      tableSections,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---- Ana Sipariş (OrderModel) İşlemleri ----
  Future<OrderModel> insertMainOrder(OrderModel order) async {
    final db = await database;
    final int newId = await db.insert(
      tableMainOrders,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // OrderModel'de copyWith metodu tanımlı OLMALIDIR
    return order.copyWith(id: newId); // FIXED: return order; -> return order.copyWith(id: newId);
  }

  Future<OrderModel?> getActiveOrderByTableId(String tableId) async {
    final db = await database;
    final result = await db.query(
      tableMainOrders,
      where: 'tableId = ?',
      whereArgs: [tableId],
      orderBy: 'createdAt DESC', // En son oluşturulanı al
      limit: 1,
    );
    if (result.isNotEmpty) {
      return OrderModel.fromMap(result.first);
    }
    return null;
  }

  Future<void> updateMainOrder(OrderModel orderModel) async {
    final db = await database;
    if (orderModel.id == null) return; // ID yoksa güncelleme yapma

    await db.update(
      tableMainOrders,
      {'tableId': orderModel.tableId},
      where: 'id = ?',
      whereArgs: [orderModel.id],
    );
  }

  Future<int> deleteMainOrder(int orderId) async {
    final db = await instance.database;
    return await db.delete(
      tableMainOrders,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // ---- Sipariş Ürün Kalemi (OrderItem) İşlemleri ----
  Future<OrderItem?> findExistingOrderItem(
      int orderId, OrderItem itemToFind) async {
    final db = await instance.database;
    List<Map<String, dynamic>> maps;

    if (itemToFind.isSpecialProduct) {
      maps = await db.query(
        tableOrderItems,
        where:
            'orderId = ? AND productId = ? AND isSpecialProduct = 1 AND productName = ? AND productPrice = ?',
        whereArgs: [
          orderId,
          itemToFind.productId,
          itemToFind.productName,
          itemToFind.productPrice
        ],
        limit: 1, // Sadece bir tane bulmamız yeterli
      );
    } else {
      maps = await db.query(
        tableOrderItems,
        where: 'orderId = ? AND productId = ? AND isSpecialProduct = 0',
        whereArgs: [orderId, itemToFind.productId],
        limit: 1,
      );
    }

    if (maps.isNotEmpty) {
      return OrderItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertOrderItem(OrderItem item) async {
    final db = await database;
    return await db.insert(
      tableOrderItems,
      item.toMap(),
    );
  }

  Future<List<OrderItem>> getOrderItemsForOrder(int orderId) async {
    final db = await instance.database;
    final maps = await db.query(
      tableOrderItems,
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    return maps.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<int> updateOrderItem(OrderItem item) async {
    final db = await instance.database;
    if (item.id == null) {
      print(
          "HATA: OrderItem ID'si update için null olamaz. Item: ${item.toMap()}");
      return 0; // Veya bir hata fırlat
    }
    return await db.update(
      tableOrderItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteOrderItem(int orderItemId) async {
    final db = await instance.database;
    return await db.delete(
      tableOrderItems,
      where: 'id = ?',
      whereArgs: [orderItemId],
    );
  }

  Future<int> deleteOrderItemsByOrderId(int orderId) async {
    final db = await instance.database;
    return await db.delete(
      tableOrderItems,
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
  }

  // ---- Günlük Ciro İşlemleri ----
  Future<void> insertOrUpdateDailyRevenue(DailyRevenue dailyRevenue) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      int count = await txn.rawUpdate(
        'UPDATE $tableDailyRevenues SET revenue = revenue + ? WHERE date = ?',
        [dailyRevenue.revenue, dailyRevenue.date],
      );
      if (count == 0) {
        await txn.insert(tableDailyRevenues, dailyRevenue.toMap());
      }
    });
  }

  Future<void> addRevenueToToday(double amount) async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await db.transaction((txn) async {
      final result = await txn.query(
        tableDailyRevenues,
        where: 'date = ?',
        whereArgs: [today],
        limit: 1,
      );

      if (result.isNotEmpty) {
        await txn.rawUpdate(
          'UPDATE $tableDailyRevenues SET revenue = revenue + ? WHERE date = ?',
          [amount, today],
        );
      } else {
        await txn.insert(tableDailyRevenues, {
          'id': today,
          'date': today,
          'revenue': amount,
        });
      }
    });
  }

  Future<List<DailyRevenue>> getDailyRevenues() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyRevenues,
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return DailyRevenue.fromMap(maps[i]);
    });
  }

  Future<List<DailyRevenue>> _enrichDailyRevenuesWithSoldProducts(
      List<Map<String, dynamic>> maps, DateTime startDate, DateTime endDate) async {
    final closedOrders = await getClosedOrdersByDateRange(startDate, endDate);
    final Map<String, Map<String, int>> dailySoldProducts = {};

    for (var order in closedOrders) {
      final String? createdAt = order['createdAt'] as String?;
      if (createdAt == null || createdAt.length < 10) continue;
      final dateStr = createdAt.substring(0, 10);
      final String itemsJson = order['itemsJson'] ?? '[]';
      if (itemsJson.isNotEmpty) {
        try {
          final List<dynamic> itemsList = jsonDecode(itemsJson);
          for (var itemMap in itemsList) {
            final String name = (itemMap['productName'] ?? itemMap['name'] ?? '').toString().trim();
            final int qty = (itemMap['quantity'] as num?)?.toInt() ?? 0;
            if (name.isNotEmpty && qty > 0) {
              dailySoldProducts.putIfAbsent(dateStr, () => {});
              dailySoldProducts[dateStr]![name] = (dailySoldProducts[dateStr]![name] ?? 0) + qty;
            }
          }
        } catch (_) {}
      }
    }

    return List.generate(maps.length, (i) {
      final row = maps[i];
      final date = row['date'] as String? ?? '';
      return DailyRevenue(
        id: row['id'] ?? '',
        date: date,
        revenue: (row['revenue'] as num?)?.toDouble() ?? 0.0,
        soldProducts: dailySoldProducts[date] ?? {},
      );
    });
  }

  Future<List<DailyRevenue>> getDailyRevenuesByRange(
      DateTime startDate, DateTime endDate) async {
    Database db = await instance.database;

    final start = DateFormat('yyyy-MM-dd').format(startDate);
    final end = DateFormat('yyyy-MM-dd').format(endDate);

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyRevenues,
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );

    return _enrichDailyRevenuesWithSoldProducts(maps, startDate, endDate);
  }

  // YENİ METOT: AI Servisinin beklediği hata veren fonksiyonun tanımı
  Future<List<DailyRevenue>> getDailyRevenuesByDateRange(
      DateTime startDate, DateTime endDate) async {
    return getDailyRevenuesByRange(startDate, endDate);
  }

  Future<Map<String, dynamic>> exportDatabaseToJson(Database db) async {
    final data = <String, dynamic>{};

    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");

    for (var table in tables) {
      final tableName = table['name'] as String;
      final rows = await db.query(tableName);
      data[tableName] = rows;
    }

    return data;
  }

  Future<void> restoreDatabaseFromJson(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Önce Foreign Key kısıtlamalarını kapat (Tablo silme/ekleme sırasında hata almamak için)
      await txn.execute('PRAGMA foreign_keys = OFF');

      try {
        // 2. Mevcut tüm tabloları bul
        final tables = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");

        // 3. Tüm tabloların içini boşalt
        for (var table in tables) {
          final tableName = table['name'] as String;
          await txn.delete(tableName);
        }

        // 4. Yedekteki verileri ekle
        for (var tableName in data.keys) {
          final rows = data[tableName] as List;
          for (var row in rows) {
             // row bir Map<String, dynamic> olmalı, cast edelim
             final rowMap = Map<String, dynamic>.from(row as Map);
             await txn.insert(tableName, rowMap);
          }
        }
      } finally {
        // 5. Her durumda Foreign Key kısıtlamalarını tekrar aç
        await txn.execute('PRAGMA foreign_keys = ON');
      }
    });
  }

  /// Tüm veritabanı tablolarını temizler.
  Future<void> clearDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      try {
        final tables = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");
        for (var table in tables) {
          final tableName = table['name'] as String;
          await txn.delete(tableName);
        }
      } finally {
        await txn.execute('PRAGMA foreign_keys = ON');
      }
    });
    debugPrint("SQLite veritabanı başarıyla temizlendi.");
  }

  Future<double> getTodayRevenue() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.query(
      tableDailyRevenues,
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final revenueValue = result.first['revenue'];
      if (revenueValue is num) {
        return revenueValue.toDouble();
      }
    }
    return 0.0;
  }

  Future<List<DailyRevenue>> getDailyRevenuesLast30Days() async {
    Database db = await instance.database;
    DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    String formattedDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyRevenues,
      where: 'date >= ?',
      whereArgs: [formattedDate],
      orderBy: 'date ASC',
    );
    return _enrichDailyRevenuesWithSoldProducts(maps, thirtyDaysAgo, DateTime.now());
  }

  Future<Map<int, double>> getHourlyRevenueForToday() async {
    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        CAST(strftime('%H', createdAt) AS INTEGER) AS hour,
        SUM(total) AS hourly_revenue
      FROM $tableClosedOrders
      WHERE strftime('%Y-%m-%d', createdAt) = ?
      GROUP BY hour
      ORDER BY hour ASC
    ''', [today]); // today, 'createdAt' alanının tarih kısmıyla eşleşir.

    final Map<int, double> hourlyData = {};
    for (var map in maps) {
      final hour = map['hour'] as int;
      final revenue = map['hourly_revenue'];
      if (revenue is num) {
        hourlyData[hour] = revenue.toDouble();
      } else {
        hourlyData[hour] = 0.0; // Veya uygun bir varsayılan değer
      }
    }

    return hourlyData;
  }

  // ---- CLOSED ORDERS (History) İşlemleri ----
  Future<void> saveClosedTable({
    required String tableId,
    required String tableName,
    required double totalRevenue,
    required DateTime startTime,
    required DateTime endTime,
    required int elapsedTime,
    String? note,
    required String itemsJson,
  }) async {
    final db = await database;

    await db.insert(tableClosedOrders, {
      'tableId': tableId,
      'tableName': tableName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': elapsedTime,
      'total': totalRevenue,
      'itemsJson': itemsJson,
      'createdAt': DateTime.now().toIso8601String(),
      'note': note,
    });

    await deleteOldClosedOrders();
  }

  Future<List<Map<String, dynamic>>> getClosedOrdersLastSixMonths() async {
    final db = await database;
    DateTime sixMonthsAgo =
        DateTime.now().subtract(const Duration(days: 30 * 6));
    final cutoff = sixMonthsAgo.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      tableClosedOrders,
      where: 'createdAt >= ?',
      whereArgs: [cutoff],
      orderBy: 'createdAt DESC',
    );
    return maps;
  }

  Future<List<Map<String, dynamic>>> getClosedOrdersByTable(
      String tableId) async {
    final db = await database;
    DateTime sixMonthsAgo =
        DateTime.now().subtract(const Duration(days: 30 * 6));
    final cutoff = sixMonthsAgo.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      tableClosedOrders,
      where: 'tableId = ? AND createdAt >= ?',
      whereArgs: [tableId, cutoff],
      orderBy: 'createdAt DESC',
    );
    return maps;
  }

  Future<List<Map<String, dynamic>>> getClosedOrdersByDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final start = startDate.toIso8601String();
    final end = endDate.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      tableClosedOrders,
      where: 'createdAt BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'createdAt DESC',
    );
    return maps;
  }

  /// 📊 Masa bazlı satış özetini çeker (Süre bilgileri dahil)
  Future<List<Map<String, dynamic>>> getTableSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final start = startDate.toIso8601String();
    final end = endDate.toIso8601String();

    // createdAt'e göre filtrele, tableId ve tableName'e göre grupla
    return await db.rawQuery('''
      SELECT 
        tableId, 
        tableName, 
        SUM(total) as totalRevenue, 
        COUNT(*) as orderCount,
        SUM(durationSeconds) as totalDurationSeconds,
        AVG(durationSeconds) as avgDurationSeconds
      FROM $tableClosedOrders
      WHERE createdAt BETWEEN ? AND ?
      GROUP BY tableId, tableName
      ORDER BY totalRevenue DESC
    ''', [start, end]);
  }

  /// 📊 Belirli bir masanın detaylı kayıtlarını çeker
  Future<List<Map<String, dynamic>>> getTableDetailedRecords({
    required String tableId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final start = startDate.toIso8601String();
    final end = endDate.toIso8601String();

    return await db.query(
      tableClosedOrders,
      where: 'tableId = ? AND createdAt BETWEEN ? AND ?',
      whereArgs: [tableId, start, end],
      orderBy: 'createdAt DESC',
    );
  }

  Future<void> deleteOldClosedOrders() async {
    final db = await database;
    // Rapor filtrelerinde 300 gün kullanılabildiği için, cihazda kapanmış
    // sipariş detaylarını minimum 13 ay (yaklaşık 400 gün) saklıyoruz.
    DateTime cutoffDate =
        DateTime.now().subtract(const Duration(days: 400));
    final cutoff = cutoffDate.toIso8601String();
    await db.delete(
      tableClosedOrders,
      where: 'createdAt < ?',
      whereArgs: [cutoff],
    );
  }

  // YENİ METOT: AI Servisinin ürün ve kategorileri tek seferde çekmek için beklediği metot
  Future<Map<String, dynamic>> getProductsAndCategories() async {
    final db = await database;

    // Ürünleri çek
    final List<Map<String, dynamic>> productMaps =
        await db.query(tableProducts);
    final List<ProductModel> products = List.generate(productMaps.length, (i) {
      return ProductModel.fromMap(productMaps[i]);
    });

    // Kategorileri çek
    final List<Map<String, dynamic>> categoryMaps =
        await db.query(tableCategories);
    final List<CategoryModel> categories =
        List.generate(categoryMaps.length, (i) {
      return CategoryModel.fromJson(categoryMaps[i]);
    });

    return {
      'products': products,
      'categories': categories,
    };
  }

  // **** VERESİYE FONKSİYONLARI BURAYA ****

  Future<void> saveAsVeresiye({
    required String customerName,
    required double totalAmount,
    required String itemsJson,
    String? note,
  }) async {
    final db = await database;
    await db.insert(tableVeresiye, {
      'customerName': customerName,
      'totalAmount': totalAmount,
      'itemsJson': itemsJson,
      'note': note,
      'date': DateTime.now().toIso8601String(),
      'isPaid': 0, // Ödenmedi olarak kaydet
    });
  }

  Future<List<VeresiyeModel>> getVeresiyeRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(tableVeresiye, orderBy: 'date DESC');
    // VeresiyeModel'i import ettiğiniz için kullanıyoruz
    return List.generate(maps.length, (i) {
      // return VeresiyeModel.fromMap(maps[i]); // Hata varsa bu satırı kullanın
      return VeresiyeModel.fromMap(maps[i] as Map<String, dynamic>);
    });
  }

  Future<int> updateVeresiye(VeresiyeModel record) async {
    final db = await database;
    return await db.update(
      tableVeresiye,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteVeresiye(int id) async {
    final db = await database;
    return await db.delete(
      tableVeresiye,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // **** VERESİYE FONKSİYONLARI SONU ****

  Future<void> addNotification(String title, String message) async {
    // Implement if needed
  }

  Future<List<Map<String, dynamic>>> getOrdersForDate(DateTime date) async {
    final db = await database;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    return await db.query(
      tableClosedOrders,
      where: "strftime('%Y-%m-%d', createdAt) = ?",
      whereArgs: [formattedDate],
    );
  }

  Future<void> deleteClosedOrder(String id) async {
    final db = await database;
    await db.delete(
      tableClosedOrders,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---- İşlem Günlüğü (Log) Metotları ----

  Future<int> insertLog({
    required String userName,
    required String actionType,
    required String details,
  }) async {
    final db = await instance.database;
    return await db.insert(tableAppLogs, {
      'userName': userName,
      'actionType': actionType,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getLogs({int days = 14}) async {
    final db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    
    return await db.query(
      tableAppLogs,
      where: 'timestamp >= ?',
      whereArgs: [cutoffDate],
      orderBy: 'timestamp DESC',
    );
  }
}
