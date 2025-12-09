import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'table_detail_screen.dart';
import 'login_screen.dart'; // <-- EKLENDİ: Yönlendirme için
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import '../services/database_helper.dart';
import '../services/database_service.dart'; // <-- EKLENDİ: Kullanıcı kontrolü için

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required Map<String, dynamic> loggedInUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _tableController = TextEditingController();

  // <-- YENİ: Kullanıcı işlemleri için servis
  final _dbService = DatabaseService();

  Timer? _globalTimer;
  Timer? _tickerTimer;

  List<FlSpot> _dailyRevenueSpots = [];
  bool _isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() async {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      await tableProvider.initialize();
      _fetchChartData();
      _startTickerTimer();
      _loadSavedViewMode(tableProvider);
    });
    _startGlobalTimer();
  }

  Future<void> _loadSavedViewMode(TableProvider provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('saved_view_mode');

      if (savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex < TableViewMode.values.length) {
        final targetMode = TableViewMode.values[savedIndex];
        int safetyCounter = 0;
        while (provider.viewMode != targetMode && safetyCounter < 10) {
          provider.cycleViewMode();
          safetyCounter++;
        }
      }
    } catch (e) {
      print("Görünüm modu yüklenirken hata: $e");
    }
  }

  // --- YENİ: GÜVENLİ ÇIKIŞ MANTIĞI ---
  Future<void> _secureLogout() async {
    try {
      final List<Map<String, dynamic>> allUsers =
          await _dbService.getAllUsers();
      final bool adminExists =
          allUsers.any((user) => user['userRole'] == 'Yönetici');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            allUsers: allUsers,
            adminExists: adminExists,
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) _showSnackBar('Hata: $e', isSuccess: false);
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout_rounded,
                    color: Colors.red.shade700, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Çıkış Yap',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ],
          ),
          content: const Text(
            'Uygulamadan güvenli çıkış yapmak üzeresiniz. Onaylıyor musunuz?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                elevation: 4,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dialogu kapat
                _secureLogout(); // Çıkış yap
              },
              child: const Text('Çıkış Yap'),
            ),
          ],
        );
      },
    );
  }
  // --- GÜVENLİ ÇIKIŞ BİTİŞ ---

  void _startGlobalTimer() {
    _globalTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _fetchChartData(refresh: true);
    });
  }

  void _startTickerTimer() {
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final provider = Provider.of<TableProvider>(context, listen: false);
      if (provider.activeTableCount > 0) {
        setState(() {
          // Arayüzü güncelle
        });
      }
    });
  }

  Future<void> _fetchChartData({bool refresh = false}) async {
    if (!refresh) setState(() => _isLoadingChart = true);
    try {
      final hourlyData =
          await DatabaseHelper.instance.getHourlyRevenueForToday();
      List<FlSpot> newSpots = [];
      double cumulativeRevenue = 0;
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      final currentSecond = now.second;

      for (int h = 0; h <= currentHour; h++) {
        cumulativeRevenue += hourlyData[h] ?? 0;
        newSpots.add(FlSpot(h.toDouble(), cumulativeRevenue));
      }

      final currentDecimalHour =
          now.hour + currentMinute / 60.0 + currentSecond / 3600.0;

      if (newSpots.isEmpty ||
          (newSpots.isNotEmpty && currentDecimalHour > newSpots.last.x)) {
        newSpots.add(FlSpot(currentDecimalHour, cumulativeRevenue));
      } else if (newSpots.isNotEmpty && currentDecimalHour == newSpots.last.x) {
        newSpots.last = FlSpot(newSpots.last.x, cumulativeRevenue);
      }

      if (mounted) {
        setState(() {
          _dailyRevenueSpots = newSpots;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      print('Grafik verisi çekilirken hata oluştu: $e');
      if (mounted && !refresh) setState(() => _isLoadingChart = false);
    }
  }

  String _getElapsedTime(TableModel table) {
    if (!table.isOccupied || table.startTime == null) return '';
    final elapsed = DateTime.now().difference(table.startTime!);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tableController.dispose();
    _globalTimer?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  IconData _getViewModeIcon(TableViewMode mode) {
    switch (mode) {
      case TableViewMode.list:
        return Icons.grid_view;
      case TableViewMode.gridTwo:
        return Icons.view_comfy;
      case TableViewMode.gridThree:
        return Icons.apps;
      case TableViewMode.gridFour:
        return Icons.grid_on;
      case TableViewMode.gridFive:
        return Icons.view_list;
      default:
        return Icons.grid_view;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,

        // --- YENİ: SOL TARAFA ÇIKIŞ BUTONU EKLENDİ ---
        leadingWidth: 70,
        leading: Center(
          child: _buildAppBarAction(
            Icons.logout_rounded,
            'Güvenli Çıkış',
            Colors.red.shade700,
            () {
              _showLogoutConfirmationDialog();
            },
          ),
        ),

        // ---------------------------------------------

        title: const Text('Masa Takip Sistemi',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,
        actions: [
          Consumer<TableProvider>(
            builder: (context, tableProvider, child) {
              return Row(
                children: [
                  _buildAppBarAction(Icons.add_circle_outline_rounded,
                      'Masa Ekle', Colors.green.shade600, () {
                    _showAddEditTableDialog();
                  }),
                  const SizedBox(width: 8),
                  _buildAppBarAction(MdiIcons.calculator, 'Hesap Makinesi',
                      Colors.blue.shade600, () {
                    _showSnackBar('Bu özellik geliştirilmeye devam ediyor.',
                        isSuccess: false);
                  }),
                  const SizedBox(width: 8),
                  _buildAppBarAction(Icons.filter_list_rounded, 'Filtrele',
                      Colors.orange.shade600, () {
                    _showFilterDialog();
                  }),
                  const SizedBox(width: 8),
                  _buildAppBarAction(_getViewModeIcon(tableProvider.viewMode),
                      'Görünümü Değiştir', Colors.purple.shade600, () async {
                    tableProvider.cycleViewMode();

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(
                        'saved_view_mode', tableProvider.viewMode.index);
                  }),
                  const SizedBox(width: 8),
                  _buildAppBarAction(
                    tableProvider.showActiveTablesInfo
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    'Özet Bilgileri',
                    Colors.indigo.shade600,
                    tableProvider.toggleShowActiveTablesInfo,
                  ),
                  const SizedBox(width: 8),
                  _buildAppBarAction(
                      Icons.refresh_rounded, 'Yenile', Colors.teal.shade600,
                      () {
                    Provider.of<TableProvider>(context, listen: false)
                        .refreshTables();
                    _showSnackBar('Masalar başarıyla yenilendi.',
                        isSuccess: true);
                  }),
                  const SizedBox(width: 16),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<TableProvider>(
        builder: (context, tableProvider, child) {
          final viewMode = tableProvider.viewMode;
          int crossAxisCount;
          double childAspectRatio;

          switch (viewMode) {
            case TableViewMode.list:
              crossAxisCount = 1;
              childAspectRatio = 3.5;
              break;
            case TableViewMode.gridTwo:
              crossAxisCount = 2;
              childAspectRatio = 1.05;
              break;
            case TableViewMode.gridThree:
              crossAxisCount = 3;
              childAspectRatio = 1.0;
              break;
            case TableViewMode.gridFour:
              crossAxisCount = 4;
              childAspectRatio = 0.95;
              break;
            case TableViewMode.gridFive:
              crossAxisCount = 5;
              childAspectRatio = 0.9;
              break;
            default:
              crossAxisCount = 2;
              childAspectRatio = 1.05;
          }

          return Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: tableProvider.showActiveTablesInfo
                    ? _buildSummaryCard(tableProvider)
                    : const SizedBox(height: 8),
              ),
              Expanded(
                child: tableProvider.isLoading
                    ? _buildShimmerEffect(
                        crossAxisCount, childAspectRatio, viewMode)
                    : tableProvider.filteredTables.isEmpty
                        ? _buildEmptyState(tableProvider.currentFilter)
                        : ReorderableGridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 16.0,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: tableProvider.filteredTables.length,
                            onReorder: (oldIndex, newIndex) {
                              HapticFeedback.lightImpact();
                              tableProvider.reorderTables(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final table = tableProvider.filteredTables[index];
                              return _buildProfessionalTableCard(
                                  table, viewMode);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfessionalTableCard(TableModel table, TableViewMode viewMode) {
    final isOccupied = table.isOccupied;
    final elapsedTime = _getElapsedTime(table);

    const Color redPrimary = Color(0xFFE74C3C);
    const Color redLight = Color(0xFFFCEBE9);
    const Color redDark = Color(0xFFC0392B);

    const Color greenPrimary = Color(0xFF2ECC71);
    const Color greenLight = Color(0xFFD4EDDA);
    const Color greenDark = Color(0xFF27AE60);

    final Color primaryColor = isOccupied ? redPrimary : greenPrimary;
    final Color lightColor = isOccupied ? redLight : greenLight;
    final Color darkColor = isOccupied ? redDark : greenDark;

    if (viewMode == TableViewMode.list) {
      return Card(
        key: ValueKey(table.id),
        elevation: 4,
        shadowColor: primaryColor.withOpacity(0.2),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TableDetailScreen(tableId: table.id)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.white, lightColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(color: darkColor, width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: primaryColor.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(
                    isOccupied
                        ? Icons.restaurant_rounded
                        : Icons.table_bar_rounded,
                    color: darkColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        table.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkColor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              isOccupied ? 'DOLU' : 'BOŞ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (isOccupied) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: primaryColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_rounded,
                                      size: 18, color: darkColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    elapsedTime,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: darkColor,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: primaryColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_empty_rounded,
                                      size: 18, color: darkColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Bekliyor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: darkColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (isOccupied && (table.totalRevenue) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                              .format(table.totalRevenue),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: darkColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ciro',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  color: darkColor,
                  iconSize: 28,
                  onPressed: () => _showTableActionBottomSheet(context, table),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      key: ValueKey(table.id),
      elevation: 4,
      shadowColor: primaryColor.withOpacity(0.2),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TableDetailScreen(tableId: table.id)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [lightColor, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: darkColor, width: 2),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      isOccupied ? 'DOLU' : 'BOŞ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showTableActionBottomSheet(context, table),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.more_vert_rounded,
                          color: darkColor, size: 24),
                    ),
                  )
                ],
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOccupied
                            ? Icons.restaurant_rounded
                            : Icons.table_bar_rounded,
                        color: darkColor,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        table.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: darkColor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (isOccupied)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_rounded, size: 18, color: darkColor),
                          const SizedBox(width: 6),
                          Text(
                            elapsedTime,
                            style: TextStyle(
                              fontSize: 18,
                              color: darkColor,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                      if ((table.totalRevenue) > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                                .format(table.totalRevenue),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty_rounded,
                          size: 18, color: darkColor),
                      const SizedBox(width: 6),
                      Text(
                        'Bekliyor',
                        style: TextStyle(
                          fontSize: 18,
                          color: darkColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect(
      int crossAxisCount, double childAspectRatio, TableViewMode viewMode) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          if (viewMode == TableViewMode.list) {
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        )),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: double.infinity,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              )),
                          const SizedBox(height: 10),
                          Container(
                              width: 120,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              )),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          }
          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      )),
                  const Spacer(),
                  Container(
                      width: double.infinity,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      )),
                  const Spacer(),
                  Container(
                      width: 120,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(TableProvider tableProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade400,
                              Colors.deepPurple.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.table_chart_rounded,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aktif Masa Sayısı',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 6),
                          Text('${tableProvider.activeTableCount}',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.teal.shade400,
                              Colors.teal.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toplam Ciro',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 6),
                          Text(
                            NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                                .format(tableProvider.todayTotalRevenue),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: tableProvider.showDailyRevenueInfo
                      ? Container(
                          height: 180,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.blue.shade100, width: 2),
                          ),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildRevenueChart(tableProvider)),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(TableProvider provider) {
    if (_isLoadingChart) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
        ),
      );
    }

    final now = DateTime.now();
    final double currentDecimalHour =
        now.hour + now.minute / 60.0 + now.second / 3600.0;

    final double maxX = currentDecimalHour;
    final double minX = max(0, maxX - 5.0);

    List<FlSpot> spots = [];

    FlSpot? preStartSpot;
    try {
      preStartSpot = _dailyRevenueSpots.lastWhere((s) => s.x <= minX,
          orElse: () => FlSpot(minX, 0));
    } catch (e) {
      preStartSpot = FlSpot(minX, 0);
    }

    if (preStartSpot.x < minX) {
      spots.add(FlSpot(minX, preStartSpot.y));
    }

    spots.addAll(
        _dailyRevenueSpots.where((s) => s.x > minX && s.x <= maxX).toList());

    double minY = spots.isNotEmpty ? spots.map((s) => s.y).reduce(min) : 0;
    double maxY = spots.isNotEmpty ? spots.map((s) => s.y).reduce(max) : 100;

    if (maxY > 0) {
      final padding = (maxY - minY) * 0.1;
      minY = max(0, minY - padding);
      maxY = maxY + padding;
    } else {
      maxY = 10;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value != value.toInt()) return const SizedBox.shrink();
                if (value < minX || value > maxX)
                  return const SizedBox.shrink();

                final hour = value.toInt() % 24;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final hour = spot.x.toInt();
                final minute = ((spot.x - hour) * 60).toInt();
                final time =
                    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                final amount =
                    NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                        .format(spot.y);
                return LineTooltipItem(
                  'Saat: $time\nCiro: $amount',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient:
                const LinearGradient(colors: [Colors.deepPurple, Colors.teal]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.3),
                  Colors.teal.withOpacity(0.05)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final tableProvider =
            Provider.of<TableProvider>(context, listen: false);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.filter_list_rounded,
                      size: 56, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Masa Filtresi',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 28),
                _buildFilterOption(
                    'Tüm Masalar', Icons.restaurant_rounded, tableProvider),
                const SizedBox(height: 14),
                _buildFilterOption(
                    'Dolu Masalar', Icons.event_seat_rounded, tableProvider),
                const SizedBox(height: 14),
                _buildFilterOption('Boş Masalar', Icons.event_available_rounded,
                    tableProvider),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
      String filterText, IconData icon, TableProvider tableProvider) {
    final isSelected = tableProvider.currentFilter == filterText;
    final primaryColor = Colors.blue.shade600;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            tableProvider.setFilter(filterText);
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey[300]!,
                  width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withOpacity(0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: isSelected ? primaryColor : Colors.grey[700],
                      size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    filterText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? primaryColor : Colors.grey[800],
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: primaryColor, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEditTableDialog({TableModel? table}) {
    _tableController.text = table?.name ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: table == null
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (table == null ? Colors.green : Colors.blue)
                            .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                      table == null
                          ? Icons.add_business_rounded
                          : Icons.edit_rounded,
                      size: 58,
                      color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  table == null ? 'Yeni Masa Ekle' : 'Masa Düzenle',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _tableController,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Masa Adı',
                    labelStyle: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                    hintText: 'Örn: Bahçe 1',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.table_restaurant_rounded,
                        size: 26, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _tableController.clear();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_tableController.text.isNotEmpty) {
                            if (table == null) {
                              Provider.of<TableProvider>(context, listen: false)
                                  .addTable(
                                TableModel(
                                    id: const Uuid().v4(),
                                    name: _tableController.text,
                                    position: 0),
                              );
                            } else {
                              table.name = _tableController.text;
                              Provider.of<TableProvider>(context, listen: false)
                                  .updateTable(table);
                            }
                            Navigator.of(context).pop();
                            _tableController.clear();
                            _showSnackBar(
                                table == null
                                    ? 'Masa başarıyla eklendi'
                                    : 'Masa güncellendi',
                                isSuccess: true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: table == null
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          elevation: 4,
                        ),
                        child: Text(table == null ? 'Ekle' : 'Güncelle'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoveTableDialog(TableModel sourceTable) {
    showDialog(
      context: context,
      builder: (context) {
        final tableProvider =
            Provider.of<TableProvider>(context, listen: false);
        final availableTables = tableProvider.tables
            .where((t) => !t.isOccupied && t.id != sourceTable.id)
            .toList();

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      size: 56, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  '${sourceTable.name} Masasını Taşı',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0xFF1A1A2E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: availableTables.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 72, color: Colors.grey[400]),
                            const SizedBox(height: 18),
                            Text('Taşınacak boş masa\nbulunmamaktadır.',
                                style: TextStyle(
                                    fontSize: 17,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center),
                          ],
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableTables.length,
                          itemBuilder: (context, index) {
                            final destTable = availableTables[index];
                            const Color destPrimary = Color(0xFF2ECC71);
                            const Color destDark = Color(0xFF27AE60);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [destPrimary, destDark],
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(14),
                                    ),
                                  ),
                                  child: const Icon(
                                      Icons.table_restaurant_rounded,
                                      color: Colors.white,
                                      size: 26),
                                ),
                                title: Text(destTable.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                subtitle: const Text('Boş masa',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                trailing: Icon(Icons.arrow_forward_ios_rounded,
                                    size: 20, color: destPrimary),
                                onTap: () {
                                  tableProvider.moveTableData(
                                      sourceTable, destTable);
                                  Navigator.of(context).pop();
                                  _showSnackBar(
                                      '${sourceTable.name} masası ${destTable.name} masasına taşındı.',
                                      isSuccess: true);
                                },
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('İptal'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor:
            isSuccess ? Colors.teal.shade600 : Colors.redAccent.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildEmptyState(String currentFilter) {
    final bool isAll = currentFilter == 'Tüm Masalar';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAll ? Icons.restaurant_menu_rounded : Icons.search_off_rounded,
              size: 96,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isAll
                ? 'Henüz masa eklenmedi'
                : 'Gösterilecek masa bulunmamaktadır',
            style: TextStyle(
                fontSize: 24,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isAll
                ? 'Yeni masa eklemek için + ikonuna tıklayın'
                : 'Farklı bir filtre seçmeyi deneyin',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTableActionBottomSheet(BuildContext context, TableModel table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.42,
          minChildSize: 0.2,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 5,
                        margin: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(table.name,
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 28),
                            _buildActionTile(
                              icon: Icons.edit_rounded,
                              title: 'Düzenle',
                              subtitle: 'Masa adını değiştir',
                              color: Colors.blue.shade600,
                              onTap: () {
                                Navigator.pop(context);
                                _showAddEditTableDialog(table: table);
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.swap_horiz_rounded,
                              title: 'Masayı Taşı',
                              subtitle: 'Veriyi başka masaya aktar',
                              color: Colors.orange.shade600,
                              onTap: () {
                                Navigator.pop(context);
                                _showMoveTableDialog(table);
                              },
                            ),
                            _buildActionTile(
                              icon: Icons.delete_rounded,
                              title: 'Sil',
                              subtitle: 'Masayı kalıcı olarak sil',
                              color: Colors.red.shade600,
                              onTap: () {
                                Navigator.pop(context);
                                _showDeleteConfirmationDialog(context, table);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warning_rounded,
                    color: Colors.red.shade600, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Masa Silme Onayı',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ],
          ),
          content: Text(
            '${table.name} masasını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                elevation: 4,
              ),
              onPressed: () {
                Provider.of<TableProvider>(context, listen: false)
                    .deleteTable(table.id);
                Navigator.of(context).pop();
                _showSnackBar('${table.name} masası kalıcı olarak silindi.');
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppBarAction(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 26, color: color),
        style: IconButton.styleFrom(backgroundColor: Colors.transparent),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
      ),
    );
  }
}
