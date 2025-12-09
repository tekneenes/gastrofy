import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

enum TableViewMode {
// ... (varolan enum) ...
  two,
  three,
  four,
  five,
  list,
  grid2,
  grid3,
  gridSmall,
  smallGrid,
  gridFive,
  gridFour,
  gridThree,
  gridTwo
}

class TableProvider with ChangeNotifier {
  List<TableModel> _tables = [];
// ... (varolan değişkenler) ...
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _currentFilter = 'Tüm Masalar';
// ... (varolan değişkenler) ...
  TableViewMode _viewMode = TableViewMode.two;
  bool _showActiveTablesInfo = true;
// ... (varolan değişkenler) ...
  bool _showDailyRevenueInfo = true;

  double _todayTotalRevenue = 0.0;
// ... (varolan değişkenler) ...
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = false;
// ... (varolan değişkenler) ...
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
// ... (varolan initialize) ...
    _isLoading = true;
    notifyListeners();

    await _loadSettings();
    await _loadTables();
    await _loadTodayRevenue();

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

  TableProvider() {
// ... (varolan constructor) ...
    initialize();
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
// ... (varolan _loadTodayRevenue) ...
    _todayTotalRevenue = await _dbHelper.getTodayRevenue();
    notifyListeners();
  }

  Future<void> loadTables() async {
// ... (varolan loadTables) ...
    _tables = await _dbHelper.getTables();
    notifyListeners();
  }

  Future<void> init() async {
// ... (varolan init) ...
    await loadTables();
    await _loadTodayRevenue();
  }

  Future<void> refreshTables() async {
// ... (varolan refreshTables) ...
    await _loadTables();
    await loadTodayRevenue();
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
// ... (varolan cycleViewMode) ...
    final currentModeIndex = _viewMode.index;
    final nextModeIndex = (currentModeIndex + 1) % TableViewMode.values.length;
    _viewMode = TableViewMode.values[nextModeIndex];
    await _saveViewMode(); // Yeni seçimi kaydet
    notifyListeners();
  }

  Future<void> _saveViewMode() async {
// ... (varolan _saveViewMode) ...
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tableViewMode', _viewMode.index);
  }

  Future<void> _loadViewMode() async {
// ... (varolan _loadViewMode) ...
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('tableViewMode');
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
// ... (varolan kod) ...
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

  Future<void> deleteTable(String id) async {
// ... (varolan kod) ...
    TableModel tableToDelete = _tables.firstWhere((t) => t.id == id);
    await clearTable(tableToDelete.id, addToRevenue: true);
    await _databaseHelper.deleteTable(id);
    await _loadTables();
  }

  Future<void> reorderTables(int oldIndex, int newIndex) async {
// ... (varolan kod) ...
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final TableModel movedTable = _tables.removeAt(oldIndex);
    _tables.insert(newIndex, movedTable);

    for (int i = 0; i < _tables.length; i++) {
      _tables[i].position = i;
    }
    await _databaseHelper.updateTablePositions(_tables);
    notifyListeners();
  }

  Future<void> addOrUpdateOrder(
// ... (varolan kod) ...
      String tableId,
      OrderItem newItemWithoutOrderId) async {
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
        break;
      }
    }

    if (!itemExists) {
      final newOrderItemId =
          await _databaseHelper.insertOrderItem(newItemWithoutOrderId);
      newItemWithoutOrderId.id = newOrderItemId;
      table.orders.add(newItemWithoutOrderId);
    }

    table.totalRevenue = table.orders
        .fold(0.0, (sum, item) => sum + (item.productPrice * item.quantity));
    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> incrementOrderItem(String tableId, OrderItem item) async {
// ... (varolan kod) ...
    item.quantity++;
    await _databaseHelper.updateOrderItem(item);
    TableModel table = _tables.firstWhere((t) => t.id == tableId);
    table.totalRevenue = table.orders.fold(
        0.0,
        (sum, orderItem) =>
            sum + (orderItem.productPrice * orderItem.quantity));
    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> decrementOrderItem(String tableId, OrderItem item) async {
// ... (varolan kod) ...
    TableModel table = _tables.firstWhere((t) => t.id == tableId);

    if (item.quantity > 1) {
      item.quantity--;
      await _databaseHelper.updateOrderItem(item);
    } else {
      await _databaseHelper.deleteOrderItem(item.id!);
      table.orders.removeWhere((element) => element.id == item.id);
    }

    table.totalRevenue = table.orders.fold(
        0.0,
        (sum, orderItem) =>
            sum + (orderItem.productPrice * orderItem.quantity));

    if (table.orders.isEmpty) {
// ... (varolan kod) ...
      if (table.currentOrder != null && table.currentOrder!.id != null) {
        await _databaseHelper.deleteMainOrder(table.currentOrder!.id!);
      }
      table.isOccupied = false;
      table.startTime = null;
      table.currentOrder = null;
      table.totalRevenue = 0.0;
    }

    await _databaseHelper.updateTable(table);
    notifyListeners();
  }

  Future<void> clearTable(String tableId, {bool addToRevenue = true}) async {
// ... (varolan clearTable) ...
    final table = _tables.firstWhere((t) => t.id == tableId);

    if (addToRevenue && table.totalRevenue > 0) {
      await _dbHelper.addRevenueToToday(table.totalRevenue);
    }

    if (table.currentOrder != null && table.currentOrder!.id != null) {
// ... (varolan kod) ...
      await _dbHelper.deleteOrderItemsByOrderId(table.currentOrder!.id!);
      await _dbHelper.deleteMainOrder(table.currentOrder!.id!);
    }

    table.isOccupied = false;
// ... (varolan kod) ...
    table.startTime = null;
    table.totalRevenue = 0.0;
    table.orders = [];
    table.currentOrder = null;
    table.note = null;

    await _dbHelper.updateTable(table);

    notifyListeners();

    if (addToRevenue) {
// ... (varolan kod) ...
      await _loadTodayRevenue();
    }
  }

  List<TableModel> get filteredTables {
// ... (varolan filteredTables) ...
    List<TableModel> sortedTables = List.from(_tables);
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

  Future<void> moveTableData(
// ... (varolan moveTableData) ...
      TableModel sourceTable,
      TableModel destTable) async {
    if (sourceTable.currentOrder != null &&
        sourceTable.currentOrder!.id != null) {
      sourceTable.currentOrder =
          sourceTable.currentOrder!.copyWith(tableId: destTable.id);
// ... (varolan kod) ...
      await _databaseHelper.updateMainOrder(sourceTable.currentOrder!);

      destTable.isOccupied = sourceTable.isOccupied;
// ... (varolan kod) ...
      destTable.startTime = sourceTable.startTime;
      destTable.totalRevenue = sourceTable.totalRevenue;
      destTable.currentOrder = sourceTable.currentOrder;
      destTable.orders = List.from(sourceTable.orders);
      destTable.note = sourceTable.note;
      await _databaseHelper.updateTable(destTable);

      sourceTable.isOccupied = false;
// ... (varolan kod) ...
      sourceTable.startTime = null;
      sourceTable.totalRevenue = 0.0;
      sourceTable.orders = [];
      sourceTable.currentOrder = null;
      sourceTable.note = null;
      await _databaseHelper.updateTable(sourceTable);
    } else {
// ... (varolan kod) ...
      destTable.isOccupied = false;
      destTable.startTime = null;
      destTable.totalRevenue = 0.0;
      destTable.orders = [];
      destTable.currentOrder = null;
      destTable.note = null;
      await _databaseHelper.updateTable(destTable);

      sourceTable.isOccupied = false;
// ... (varolan kod) ...
      sourceTable.startTime = null;
      sourceTable.totalRevenue = 0.0;
      sourceTable.orders = [];
      sourceTable.currentOrder = null;
      sourceTable.note = null;
      await _databaseHelper.updateTable(sourceTable);
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

  // YENİ FONKSİYON: Veresiyeden gelen ödemeyi ciroya ekler
  Future<void> addRevenueFromVeresiye(double amount) async {
    if (amount <= 0) return;

    // 1. Cihaz hafızasındaki (in-memory) ciroya ekle
    _todayTotalRevenue += amount;

    // 2. Veritabanındaki kalıcı ciroya ekle
    await _dbHelper.addRevenueToToday(amount);

    // 3. Dinleyicileri (UI) bilgilendir
    notifyListeners();
  }
}
