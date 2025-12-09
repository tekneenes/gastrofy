import 'dart:convert';
import 'package:path/path.dart';
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
  // Veritabanı sürümünü 9'a yükseltiyoruz (Veresiye tablosu için)
  static const _databaseVersion = 10;

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
        note TEXT
      )
    ''');

    // Ürünler tablosu
    await db.execute('''
      CREATE TABLE $tableProducts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        salesCount INTEGER NOT NULL DEFAULT 0,
        categoryId TEXT NOT NULL DEFAULT ''
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

    // YENİ: Veresiye tablosu
    await db.execute('''
      CREATE TABLE $tableVeresiye (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        itemsJson TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        isPaid INTEGER NOT NULL DEFAULT 0
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
          {'position': i},
          where: 'id = ?',
          whereArgs: [table.id],
        );
      }
    });
  }

  Future<int> deleteTable(String id) async {
    Database db = await instance.database;
    return await db.delete(
      tableTables,
      where: 'id = ?',
      whereArgs: [id],
    );
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
    // CategoryModel'de toMap() metodu olduğu varsayılıyor
    return await db.insert(tableCategories, (category as dynamic).toMap());
  }

  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCategories);
    return List.generate(maps.length, (i) {
      // CategoryModel'de fromMap() metodu olduğu varsayılıyor
      return (CategoryModel as dynamic).fromMap(maps[i]);
    });
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    // CategoryModel'de toMap() metodu olduğu varsayılıyor
    return await db.update(
      tableCategories,
      (category as dynamic).toMap(),
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

  // ---- Ana Sipariş (OrderModel) İşlemleri ----
  Future<OrderModel> insertMainOrder(OrderModel order) async {
    final db = await database;
    final int newId = await db.insert(
      tableMainOrders,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // OrderModel'de copyWith metodu tanımlı OLMALIDIR
    // return order.copyWith(id: newId);
    return order; // OrderModel'in ID'si set edilsin diye varsayıyoruz
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

    return List.generate(maps.length, (i) => DailyRevenue.fromMap(maps[i]));
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
    return List.generate(maps.length, (i) {
      return DailyRevenue.fromMap(maps[i]);
    });
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

    final activeOrderResult = await db.query(
      tableMainOrders,
      where: 'tableId = ?',
      whereArgs: [tableId],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    List<Map<String, dynamic>> itemsForJson = [];
    int durationSeconds = elapsedTime;

    if (activeOrderResult.isNotEmpty) {
      final orderId = activeOrderResult.first['id'] as int;

      final itemsMaps = await db.query(
        tableOrderItems,
        where: 'orderId = ?',
        whereArgs: [orderId],
      );

      for (var itemMap in itemsMaps) {
        final double price = (itemMap['productPrice'] is num)
            ? (itemMap['productPrice'] as num).toDouble()
            : 0.0; // Varsayılan değer
        final int qty =
            (itemMap['quantity'] is int) ? itemMap['quantity'] as int : 0;
        final int isSpecial = (itemMap['isSpecialProduct'] is int)
            ? itemMap['isSpecialProduct'] as int
            : 0;

        itemsForJson.add({
          'productId': itemMap['productId'],
          'productName': itemMap['productName'],
          'productPrice': price,
          'quantity': qty,
          'isSpecialProduct': isSpecial,
        });
      }
    }

    await db.transaction((txn) async {
      await txn.insert(tableClosedOrders, {
        'tableId': tableId,
        'tableName': tableName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'total': totalRevenue,
        'itemsJson':
            itemsJson, // <-- GÜNCELLENDİ: Parametreden gelen JSON kullanılıyor
        'createdAt': DateTime.now().toIso8601String(),
        'note': note,
      });
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

  Future<void> deleteOldClosedOrders() async {
    final db = await database;
    DateTime sixMonthsAgo =
        DateTime.now().subtract(const Duration(days: 30 * 6));
    final cutoff = sixMonthsAgo.toIso8601String();
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
      // CategoryModel'de fromMap() metodu olduğu varsayılıyor
      return (CategoryModel as dynamic).fromMap(categoryMaps[i]);
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
    // ...
  }

  Future getOrdersForDate(DateTime date) async {
    // ...
  }

  Future<void> deleteClosedOrder(String id) async {
    // ...
  }
}
