import 'dart:async';
import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../models/table_record_model.dart';
import '../screens/veresiye_screen.dart'; // VeresiyeModel here
import '../services/database_helper.dart';
import '../services/local_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';

enum TableViewMode {
  list,
  grid2,
  grid3,
  grid4,
  grid5
}

enum SyncRole {
  none,
  server, // Cashier/Manager
  client, // Waiter
}

class TableProvider with ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final _syncService = LocalSyncService.instance;
  
  bool _isSyncMode = false;
  String? _syncServerIp;
  SyncRole _syncRole = SyncRole.none;

  String _currentFilter = 'Tüm Masalar';
  List<TableModel> _tables = [];
  List<Map<String, dynamic>> _sections = [];
  String? _selectedSectionId;
  List<TableRecordModel> _tableRecords = [];
  List<VeresiyeModel> _veresiyeRecords = [];
  
  TableViewMode _viewMode = TableViewMode.grid2;
  bool _showActiveTablesInfo = true;
  bool _showDailyRevenueInfo = true;
  Map<String, dynamic>? _lastLog = {
    'userName': 'Sistem',
    'actionType': 'Hazır',
    'details': 'Sistem Hazır ve Bağlı',
    'timestamp': DateTime.now().toIso8601String(),
  }; // VAROLAN: Son işlem logu (Varsayılan eklendi)

  double _todayTotalRevenue = 0.0;
  bool _isLoading = false;
// ... (varolan değişkenler) ...
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get sections => _sections;
  String? get selectedSectionId => _selectedSectionId;
  bool get isSyncMode => _isSyncMode;
  SyncRole get syncRole => _syncRole;
  String? get syncServerIp => _syncServerIp;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _loadSyncSettings();
    await _loadSettings();
    await _loadViewMode();
    
    if (_isSyncMode && _syncRole == SyncRole.client) {
      await refreshTables(); // Client ise sunucudan çek
      _startSyncTimer(); // Tıkır tıkır yenilemeyi başlat
    } else {
      // SERVER veya NORMAL mod
      if (_isSyncMode && _syncRole == SyncRole.server) {
        // Otomatik sunucu başlatma
        final serverIp = await _syncService.startServer();
        if (serverIp != null) {
          _syncServerIp = serverIp;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('syncServerIp', serverIp);
        }
      }
      
      await _loadSections();
      await _loadTables();
      await _loadTodayRevenue();
      await loadTableRecords();
      await loadVeresiyeRecords();
    }

    _isLoading = false;
    notifyListeners();
  }

  List<TableModel> get tables => _tables;
// ... (varolan getter'lar) ...
  String get currentFilter => _currentFilter;
  TableViewMode get viewMode => _viewMode;
// ... (varolan getter'lar) ...
  bool get showActiveTablesInfo => _showActiveTablesInfo;
  bool get showDailyRevenueInfo => _showDailyRevenueInfo;
// ... (varolan getter'lar) ...
  double get todayTotalRevenue => _todayTotalRevenue;
  double get dailyTotalRevenue => _todayTotalRevenue;
  Map<String, dynamic>? get lastLog => _lastLog;
  List<TableRecordModel> get tableRecords => _tableRecords;
  List<VeresiyeModel> get veresiyeRecords => _veresiyeRecords;

  TableProvider() {
    // initialize() artık dışarıdan (HomeScreen'den) kontrollü çağrılıyor
  }

  Future<void> _loadSettings() async {
// ... (varolan _loadSettings) ...
    final prefs = await SharedPreferences.getInstance();
    _showActiveTablesInfo = prefs.getBool('showActiveTablesInfo') ?? true;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
// ... (varolan _saveSettings) ...
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showActiveTablesInfo', _showActiveTablesInfo);
  }

  List<FlSpot> get dailyRevenueSpots {
// ... (varolan dailyRevenueSpots) ...
    final now = DateTime.now();
    final currentHour = now.hour.toDouble();
    final totalActiveRevenue = currentTotalRevenue;

    if (currentHour == 0) return [FlSpot(0, 0)];

    List<FlSpot> spots = [];
    double cumulativeRevenue = 0;

    double revenuePerActiveHour = totalActiveRevenue / (currentHour + 1);

    for (double hour = 0; hour <= currentHour; hour++) {
      cumulativeRevenue += revenuePerActiveHour;
      spots.add(FlSpot(hour, cumulativeRevenue.toDouble()));
    }

    if (spots.isEmpty || spots.length == 1) {
      return [FlSpot(0, 0), FlSpot(currentHour, totalActiveRevenue)];
    }

    return spots;
  }

  Map<int, double> get hourlyRevenueMap {
// ... (varolan hourlyRevenueMap) ...
    final Map<int, double> map = {};

    if (_tables.isEmpty) return {};

    final now = DateTime.now();
    final currentHour = now.hour;
    final totalActiveRevenue = currentTotalRevenue;

    double revenuePerActiveHour = totalActiveRevenue / (currentHour + 1);

    double cumulativeRevenue = 0;
    for (int hour = 0; hour <= currentHour; hour++) {
      cumulativeRevenue += revenuePerActiveHour;
      map[hour] = cumulativeRevenue;
    }
    return map;
  }

  Future<void> _loadTodayRevenue() async {
    _todayTotalRevenue = await _databaseHelper.getTodayRevenue();
    notifyListeners();
  }

  Future<void> loadTables() async {
    _tables = await _databaseHelper.getTables();
    notifyListeners();
  }

  Future<void> init() async {
    await initialize();
  }

  Timer? _syncTimer;

  Future<void> refreshTables() async {
    if (_isSyncMode && _syncRole == SyncRole.client && _syncServerIp != null) {
      final data = await _syncService.fetchFromServer(_syncServerIp!);
      if (data != null) {
        _tables = (data['tables'] as List).map((t) => TableModel.fromMap(t)).toList();
        _sections = List<Map<String, dynamic>>.from(data['sections']);
        notifyListeners();
      }
    } else {
      await _loadSections();
      await _loadTables();
      await loadTodayRevenue();
    }
  }

  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isSyncMode = prefs.getBool('isSyncMode') ?? false;
    _syncServerIp = prefs.getString('syncServerIp');
    final roleIndex = prefs.getInt('syncRole') ?? 0;
    _syncRole = SyncRole.values[roleIndex];
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    if (_isSyncMode && _syncRole == SyncRole.client) {
      _syncTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        refreshTables();
      });
    }
  }

  Future<void> setSyncMode({required bool enabled, String? ip, SyncRole role = SyncRole.none}) async {
    // Eğer mod değişmiyorsa ve IP zaten varsa gereksiz işlemden kaçın
    if (_isSyncMode == enabled && _syncRole == role && (ip == null || _syncServerIp == ip)) {
      if (enabled && role == SyncRole.server && _syncServerIp == null) {
        // IP eksikse sadece IP'yi almaya çalış
        final localIp = await _syncService.startServer();
        if (localIp != null) {
          _syncServerIp = localIp;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('syncServerIp', localIp);
          notifyListeners();
        }
      }
      return;
    }

    _isSyncMode = enabled;
    _syncServerIp = ip;
    _syncRole = role;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSyncMode', enabled);
    await prefs.setInt('syncRole', role.index);

    if (enabled && role == SyncRole.server) {
      final localIp = await _syncService.startServer();
      if (localIp != null) {
        _syncServerIp = localIp;
        await prefs.setString('syncServerIp', localIp);
      }
    } else if (!enabled) {
      await _syncService.stopServer();
      _syncTimer?.cancel();
    } else if (enabled && role == SyncRole.client) {
      if (ip != null) await prefs.setString('syncServerIp', ip);
    }
    
    _startSyncTimer();
    
    // Sadece gerekli olduğunda tam initialize yap (örn. mod değiştiğinde)
    await initialize();
  }

  Future<void> _loadSections() async {
    _sections = await _databaseHelper.getSections();
    
    // Eğer "Genel" (default_section) yoksa, listeye en başa ekleyelim veya veritabanına ekleyelim
    bool hasDefault = _sections.any((s) => s['id'] == 'default_section');
    if (!hasDefault) {
      // Veritabanına tekrar eklemeyi dene (eğer silindiyse)
      final db = await _databaseHelper.database;
      await db.insert('table_sections', {
        'id': 'default_section',
        'name': 'Genel',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      _sections = await _databaseHelper.getSections();
    }

    if (_sections.isNotEmpty && _selectedSectionId == null) {
      _selectedSectionId = 'default_section';
    }
    notifyListeners();
  }

  Future<void> _loadTables() async {
// ... (varolan _loadTables) ...
    _tables = await _databaseHelper.getTables();
    for (var table in _tables) {
      await _loadActiveOrderAndItemsForTable(table);
    }
    _ensureTablePositions();
    notifyListeners();
  }

  void _ensureTablePositions() {
// ... (varolan _ensureTablePositions) ...
    _tables.sort((a, b) => a.position.compareTo(b.position));
    for (int i = 0; i < _tables.length; i++) {
      if (_tables[i].position != i) {
        _tables[i].position = i;
        _databaseHelper.updateTable(_tables[i]);
      }
    }
  }

  Future<void> cycleViewMode() async {
    const modes = TableViewMode.values;
    final currentIndex = modes.indexOf(_viewMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    _viewMode = modes[nextIndex];
    notifyListeners();
    _saveViewMode();
  }

  Future<void> _saveViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_view_mode', _viewMode.index);
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('saved_view_mode');
    if (savedIndex != null && savedIndex < TableViewMode.values.length) {
      _viewMode = TableViewMode.values[savedIndex];
    }
  }

// ... (Diğer tüm metodlar olduğu gibi kalıyor: _loadActiveOrderAndItemsForTable, loadTodayRevenue, addTable, vb.) ...

  Future<void> _loadActiveOrderAndItemsForTable(TableModel table) async {
// ... (varolan kod) ...
    final activeOrder = await _databaseHelper.getActiveOrderByTableId(table.id);
    if (activeOrder != null && activeOrder.id != null) {
      table.currentOrder = activeOrder;
      table.orders =
          await _databaseHelper.getOrderItemsForOrder(activeOrder.id!);
      table.totalRevenue = table.orders
          .fold(0.0, (sum, item) => sum + (item.productPrice * item.quantity));
      table.isOccupied = true;
      table.startTime ??= activeOrder.createdAt;
    } else {
      table.currentOrder = null;
      table.orders = [];
      table.totalRevenue = 0.0;
      table.isOccupied = false;
      table.startTime = null;
    }
  }

  Future<void> loadTodayRevenue() async {
// ... (varolan kod) ...
    _todayTotalRevenue = await _databaseHelper.getTodayRevenue();
    notifyListeners();
  }

  Future<void> addTable(TableModel newTable) async {
    int maxPosition = -1;
    for (var table in _tables) {
      if (table.position > maxPosition) {
        maxPosition = table.position;
      }
    }
    newTable.position = maxPosition + 1;
    await _databaseHelper.insertTable(newTable);
    await _loadTables();
  }

  Future<void> updateTableNote(String tableId, String? note) async {
// ... (varolan kod) ...
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);

    if (tableIndex != -1) {
      final updatedTable = _tables[tableIndex].copyWith(note: note);
      _tables[tableIndex] = updatedTable;
      await _databaseHelper.updateTable(updatedTable);
      notifyListeners();
    }
  }

  Future<void> updateTable(TableModel table) async {
// ... (varolan kod) ...
    await _databaseHelper.updateTable(table);
    await _loadTables();
  }

  Future<void> deleteTable(String id, {required Map<String, dynamic> user}) async {
    TableModel tableToDelete = _tables.firstWhere((t) => t.id == id);
    await clearTable(tableToDelete.id, addToRevenue: true, user: user);
    await _databaseHelper.deleteTable(id);
    await _loadTables();
  }

  Future<void> reorderTables(int oldIndex, int newIndex) async {
    // GÜNCELLENDİ: Sadece ekranda görünen listeyi (filteredTables) baz almalıyız
    List<TableModel> currentList = filteredTables;

    // MEVCUT POZİSYONLARI SAKLA
    // Bu masaların mevcut pozisyonlarını alıp sıralıyoruz.
    // Böylece sadece bu masaların kendi aralarındaki sırasını değiştirmiş olacağız.
    // Diğer (görünmeyen) masaların pozisyonlarıyla çakışma yaşanmaz.
    List<int> existingPositions = currentList.map((t) => t.position).toList();
    existingPositions.sort(); // Küçükten büyüğe sırala (örn: 0, 1, 5, 8...)

    final TableModel movedTable = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, movedTable);

    // Yeni sıraya göre POZİSYONLARI TEKRAR DAĞIT
    for (int i = 0; i < currentList.length; i++) {
        currentList[i].position = existingPositions[i];
    }

    // Global _tables listesini de pozisyona göre tekrar sırala
    _tables.sort((a, b) => a.position.compareTo(b.position));
    
    // UI'ı gecikmesiz güncelle (Optimistic UI Update)
    notifyListeners();

    // Veritabanını arka planda güncelle
    try {
      await _databaseHelper.updateTablePositions(currentList);
    } catch (e) {
      debugPrint("Hata: Masa sıralaması güncellenemedi: $e");
    }
  }

  Future<void> addOrUpdateOrder(
      String tableId, OrderItem newItemWithoutOrderId,
      {required Map<String, dynamic> user}) async {
    if (_isSyncMode && _syncRole == SyncRole.client && _syncServerIp != null) {
      await _syncService.sendUpdateOrder(_syncServerIp!, tableId, [newItemWithoutOrderId.toMap()], user);
      await refreshTables();
      return;
    }
    
    TableModel table = _tables.firstWhere((t) => t.id == tableId);
    OrderModel? activeOrder = table.currentOrder;

    if (activeOrder == null) {
      final now = DateTime.now();
      final newOrderId = now.millisecondsSinceEpoch;
      activeOrder = OrderModel(
          id: newOrderId, tableId: tableId, createdAt: now, orders: []);
      activeOrder = await _databaseHelper.insertMainOrder(activeOrder);
      table.currentOrder = activeOrder;
      table.isOccupied = true;
      table.startTime = now;

      // LOG: Masa Açıldı
      await addLog(
        user: user,
        actionType: 'Masa Aç',
        details: '${table.name} masası açıldı.',
      );
    }

    newItemWithoutOrderId.orderId = activeOrder.id!;
    bool itemExists = false;
    for (var item in table.orders) {
      if (item.productId == newItemWithoutOrderId.productId &&
          item.isSpecialProduct == newItemWithoutOrderId.isSpecialProduct) {
        if (newItemWithoutOrderId.isSpecialProduct &&
            (item.productPrice != newItemWithoutOrderId.productPrice ||
                item.productName != newItemWithoutOrderId.productName)) {
          continue;
        }
        item.quantity += newItemWithoutOrderId.quantity;
        await _databaseHelper.updateOrderItem(item);
        itemExists = true;

        // LOG: Ürün Geri Eklendi/Arttırıldı
        await addLog(
          user: user,
          actionType: 'Ürün Ekle',
          details: '${table.name}: ${item.productName} (+${newItemWithoutOrderId.quantity})',
        );
        break;
      }
    }

    if (!itemExists) {
      final newOrderItemId =
          await _databaseHelper.insertOrderItem(newItemWithoutOrderId);
      newItemWithoutOrderId.id = newOrderItemId;
      table.orders.add(newItemWithoutOrderId);

      // LOG: Yeni Ürün Eklendi
      await addLog(
        user: user,
        actionType: 'Ürün Ekle',
        details: '${table.name}: ${newItemWithoutOrderId.productName} (${newItemWithoutOrderId.quantity} adet)',
      );
    }

    table.totalRevenue = table.orders
        .fold(0.0, (sum, item) => sum + (item.productPrice * item.quantity));
    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> incrementOrderItem(String tableId, OrderItem item,
      {required Map<String, dynamic> user}) async {
    item.quantity++;
    await _databaseHelper.updateOrderItem(item);
    TableModel table = _tables.firstWhere((t) => t.id == tableId);
    table.totalRevenue = table.orders.fold(
        0.0,
        (sum, orderItem) =>
            sum + (orderItem.productPrice * orderItem.quantity));
    await _databaseHelper.updateTable(table);

    // LOG: Ürün Artış
    await addLog(
      user: user,
      actionType: 'Ürün Ekle',
      details: '${table.name}: ${item.productName} (+1)',
    );

    notifyListeners();
  }

  Future<void> decrementOrderItem(String tableId, OrderItem item,
      {required Map<String, dynamic> user}) async {
    TableModel table = _tables.firstWhere((t) => t.id == tableId);

    if (item.quantity > 1) {
      item.quantity--;
      await _databaseHelper.updateOrderItem(item);
      // LOG: Ürün Azalış
      await addLog(
        user: user,
        actionType: 'Ürün Çıkar',
        details: '${table.name}: ${item.productName} (-1)',
      );
    } else {
      await _databaseHelper.deleteOrderItem(item.id!);
      table.orders.removeWhere((element) => element.id == item.id);
      // LOG: Ürün Tamamen Silindi
      await addLog(
        user: user,
        actionType: 'Ürün Çıkar',
        details: '${table.name}: ${item.productName} silindi.',
      );
    }

    table.totalRevenue = table.orders.fold(
        0.0,
        (sum, orderItem) =>
            sum + (orderItem.productPrice * orderItem.quantity));

    if (table.orders.isEmpty) {
      if (table.currentOrder != null && table.currentOrder!.id != null) {
        await _databaseHelper.deleteMainOrder(table.currentOrder!.id!);
      }
      table.isOccupied = false;
      table.startTime = null;
      table.currentOrder = null;
      table.totalRevenue = 0.0;
      
      // LOG: Masa Boşaldı (Ürün kalmadığı için)
      await addLog(
        user: user,
        actionType: 'Masa Kapat',
        details: '${table.name} masası ürün kalmadığı için kapandı.',
      );
    }

    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> clearTable(String tableId,
      {bool addToRevenue = true, required Map<String, dynamic> user}) async {
    final table = _tables.firstWhere((t) => t.id == tableId);
    final double revenue = table.totalRevenue;

    if (addToRevenue && table.totalRevenue > 0) {
      await _databaseHelper.addRevenueToToday(table.totalRevenue);
    }

    if (table.currentOrder != null && table.currentOrder!.id != null) {
      await _databaseHelper.deleteOrderItemsByOrderId(table.currentOrder!.id!);
      await _databaseHelper.deleteMainOrder(table.currentOrder!.id!);
    }

    table.isOccupied = false;
    table.startTime = null;
    table.totalRevenue = 0.0;
    table.orders = [];
    table.currentOrder = null;
    table.note = null;

    await _databaseHelper.updateTable(table);

    // LOG: Ödeme Alındı ve Masa Kapatıldı
    await addLog(
      user: user,
      actionType: addToRevenue ? 'Ödeme' : 'Masa Kapat',
      details: addToRevenue 
          ? '${table.name} ödemesi alındı: ${revenue.toStringAsFixed(2)} TL'
          : '${table.name} masası sıfırlandı.',
    );

    notifyListeners();

    // REFRESH RECORDS after table is cleared
    await loadTableRecords();
    if (!addToRevenue) {
      await loadVeresiyeRecords();
    }

    if (addToRevenue) {
      await _loadTodayRevenue();
    }
  }

  List<TableModel> get filteredTables {
    // Önce seçili bölgeye göre filtrele
    List<TableModel> sectionTables = _tables;
    if (_selectedSectionId != null) {
      sectionTables = _tables.where((t) => t.sectionId == _selectedSectionId).toList();
    }

    List<TableModel> sortedTables = List.from(sectionTables);
    sortedTables.sort((a, b) => a.position.compareTo(b.position));
    switch (_currentFilter) {
      case 'Dolu Masalar':
        return sortedTables.where((table) => table.isOccupied).toList();
      case 'Boş Masalar':
        return sortedTables.where((table) => !table.isOccupied).toList();
      case 'Tüm Masalar':
      default:
        return sortedTables;
    }
  }

  void setSelectedSection(String? id) {
    _selectedSectionId = id;
    notifyListeners();
  }

  Future<void> addSection(String name) async {
    await _databaseHelper.insertSection(name);
    await _loadSections();
  }

  Future<void> deleteSection(String id) async {
    if (id == 'default_section') return; // Varsayılan bölge silinemez
    await _databaseHelper.deleteSection(id);
    if (_selectedSectionId == id) {
      _selectedSectionId = 'default_section';
    }
    await refreshTables();
  }

  void setFilter(String filter) {
// ... (varolan setFilter) ...
    _currentFilter = filter;
    notifyListeners();
  }

  void toggleViewMode() {
// ... (varolan toggleViewMode) ...
    final nextMode = TableViewMode
        .values[(_viewMode.index + 1) % TableViewMode.values.length];
    _viewMode = nextMode;
    notifyListeners();
  }

  int get activeTableCount => _tables.where((table) => table.isOccupied).length;
// ... (varolan getter'lar) ...
  double get currentTotalRevenue => _tables
      .where((table) => table.isOccupied)
      .fold(0.0, (sum, table) => sum + table.totalRevenue);

  void toggleShowActiveTablesInfo() {
// ... (varolan toggleShowActiveTablesInfo) ...
    _showActiveTablesInfo = !_showActiveTablesInfo;
    _saveSettings();
    notifyListeners();
  }

  void toggleShowDailyRevenueInfo() {
// ... (varolan toggleShowDailyRevenueInfo) ...
    _showDailyRevenueInfo = !_showDailyRevenueInfo;
    notifyListeners();
  }

  Future<void> moveTableData(TableModel sourceTable, TableModel destTable,
      {required Map<String, dynamic> user}) async {
    if (_isSyncMode && _syncRole == SyncRole.client && _syncServerIp != null) {
      // Not: LocalSyncService'e moveTable metodu eklenmişti.
      await _syncService.sendMoveTable(_syncServerIp!, sourceTable.id, destTable.id, user);
      await refreshTables();
      return;
    }

    if (sourceTable.currentOrder != null &&
        sourceTable.currentOrder!.id != null) {
      sourceTable.currentOrder =
          sourceTable.currentOrder!.copyWith(tableId: destTable.id);
      await _databaseHelper.updateMainOrder(sourceTable.currentOrder!);

      destTable.isOccupied = sourceTable.isOccupied;
      destTable.startTime = sourceTable.startTime;
      destTable.totalRevenue = sourceTable.totalRevenue;
      destTable.currentOrder = sourceTable.currentOrder;
      destTable.orders = List.from(sourceTable.orders);
      destTable.note = sourceTable.note;
      await _databaseHelper.updateTable(destTable);

      sourceTable.isOccupied = false;
      sourceTable.startTime = null;
      sourceTable.totalRevenue = 0.0;
      sourceTable.orders = [];
      sourceTable.currentOrder = null;
      sourceTable.note = null;
      await _databaseHelper.updateTable(sourceTable);

      // LOG: Masa Taşıma
      await addLog(
        user: user,
        actionType: 'Masa Taşı',
        details: '${sourceTable.name} -> ${destTable.name} taşıma yapıldı.',
      );
    }
    await _loadTables();
  }

  void setViewModeByIndex(int index) {
// ... (varolan setViewModeByIndex) ...
    if (index >= 0 && index < TableViewMode.values.length) {
      _viewMode = TableViewMode.values[index];
      notifyListeners();
    }
  }

  Future<void> markTableAsOccupied(String id) async {
// ... (varolan markTableAsOccupied) ...
    final tableIndex = _tables.indexWhere((t) => t.id == id);
    if (tableIndex != -1 && !_tables[tableIndex].isOccupied) {
      final updatedTable = _tables[tableIndex].copyWith(
        isOccupied: true,
        startTime: DateTime.now(),
      );
      _tables[tableIndex] = updatedTable;
      await _databaseHelper.updateTable(updatedTable);
      notifyListeners();
    }
  }

  Future<void> addRevenueFromVeresiye(double amount) async {
    if (amount <= 0) return;

    // 1. Cihaz hafızasındaki (in-memory) ciroya ekle
    _todayTotalRevenue += amount;

    // 2. Veritabanındaki kalıcı ciroya ekle
    await _databaseHelper.addRevenueToToday(amount);

    // 3. Dinleyicileri (UI) bilgilendir
    notifyListeners();
  }

  // ---- LOGLAMA YARDIMCISI ----
  Future<void> addLog({
    required Map<String, dynamic> user,
    required String actionType,
    required String details,
  }) async {
    final userName = user['userName'] ?? 'Bilinmeyen';
    try {
      await _databaseHelper.insertLog(
        userName: userName,
        actionType: actionType,
        details: details,
      );
      
      _lastLog = {
        'userName': userName,
        'actionType': actionType,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      };
      notifyListeners();
    } catch (e) {
      debugPrint("Log eklenirken hata: $e");
    }
  }

  // ---- RECORD LOADING METHODS ----
  Future<void> loadTableRecords() async {
    try {
      final data = await _databaseHelper.getClosedOrdersLastSixMonths();
      _tableRecords = data.map((map) => TableRecordModel.fromSqliteMap(map)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Masa kayıtları yüklenirken hata: $e");
    }
  }

  Future<void> loadVeresiyeRecords() async {
    try {
      final data = await _databaseHelper.getVeresiyeRecords();
      _veresiyeRecords = data;
      notifyListeners();
    } catch (e) {
      debugPrint("Veresiye kayıtları yüklenirken hata: $e");
    }
  }
}
