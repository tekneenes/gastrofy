import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/daily_revenue_model.dart';
import 'product_detail_analytics_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import '../models/top_product.dart';
import '../providers/daily_revenue_provider.dart';
import '../providers/product_provider.dart' as ProductProviderAlias;
import 'DetailedProductScreen.dart';
import 'DetailedRevenueScreen.dart';
import 'report_list_screen.dart';
import '../services/pdf_report_service.dart';

// DETAILEDPRODUCTSCREEN'DEN KOPYALANAN ENUM VE CLASS
enum Trend { up, down, same }

class ProductTrendData {
  final List<FlSpot> spots;
  final Trend trend;
  final double changePercentage;

  ProductTrendData({
    required this.spots,
    required this.trend,
    required this.changePercentage,
  });
}
// KOPYALAMA BİTTİ

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  String _currentFilter = 'Son 30 Gün';
  bool _isGeneratingPdf = false;

  // Ürün trend verilerini tutmak için map
  Map<String, ProductTrendData> _productTrendData = {};

  final List<Color> _pieChartColors = [
    const Color(0xFF3498DB),
    const Color(0xFF1ABC9C),
    const Color(0xFFE74C3C),
    const Color(0xFFF39C12),
    const Color(0xFF9B59B6),
    const Color(0xFF2ECC71),
    Colors.grey.shade500,
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    _setInitialDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _setInitialDates() {
    _startDate = DateTime.now().subtract(const Duration(days: 29)).copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = DateTime.now().copyWith(
        hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  }

  // Provider'ları yükledikten sonra trend verisini hesaplar
  Future<void> _loadData() async {
    if (mounted) {
      final dailyRevenueProvider =
          Provider.of<DailyRevenueProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProviderAlias.ProductProvider>(
          context,
          listen: false);

      // Provider'ları paralel olarak yükle ve tamamlanmalarını bekle
      await Future.wait([
        dailyRevenueProvider.loadDailyRevenues(),
        productProvider.loadProductSalesSummary(
            startDate: _startDate, endDate: _endDate)
      ]);

      // Veriler yüklendikten sonra trendleri hesapla
      _generateProductTrendData();
    }
  }

  // Ürün trend verilerini (sparkline ve yüzde) oluşturan fonksiyon
  void _generateProductTrendData() {
    final productProvider = Provider.of<ProductProviderAlias.ProductProvider>(
        context,
        listen: false);
    final dailyRevenueProvider =
        Provider.of<DailyRevenueProvider>(context, listen: false);

    // Ürün özetleri (ID, Ad, Toplam Satış)
    final productSummaries = productProvider.filteredSalesSummary;
    // Günlük gelir verisi (Tarih -> {ürün: adet})
    final allDailyRevenues = dailyRevenueProvider.dailyRevenues;

    // Hızlı erişim için günlük gelir verisini bir Map'e dönüştür
    final Map<String, DailyRevenue> dailyRevenueMap = {
      for (var rev in allDailyRevenues) rev.date: rev
    };

    final newTrendData = <String, ProductTrendData>{};
    final totalDays = _endDate.difference(_startDate).inDays;
    final midPointDays = totalDays / 2.0;

    for (var summary in productSummaries) {
      final spots = <FlSpot>[];
      double prevHalfSales = 0;
      double currHalfSales = 0;
      int dayIndex = 0;

      // Seçilen tarih aralığındaki her gün için dön
      for (int d = 0; d <= totalDays; d++) {
        final currentDate = _startDate.add(Duration(days: d));
        final dateString = DateFormat('yyyy-MM-dd').format(currentDate);

        // O günkü satış verisini bul
        final dailyRevenue = dailyRevenueMap[dateString];
        final sales =
            dailyRevenue?.soldProducts[summary.name]?.toDouble() ?? 0.0;

        spots.add(FlSpot(dayIndex.toDouble(), sales));

        // Periyodun ilk yarısı / ikinci yarısı olarak ayır
        if (d < midPointDays) {
          prevHalfSales += sales;
        } else {
          currHalfSales += sales;
        }
        dayIndex++;
      }

      // Trendi hesapla
      final changePercentage = prevHalfSales > 0
          ? ((currHalfSales - prevHalfSales) / prevHalfSales) * 100
          : (currHalfSales > 0 ? 100.0 : 0.0);

      Trend trend;
      if (changePercentage > 5) {
        trend = Trend.up;
      } else if (changePercentage < -5) {
        trend = Trend.down;
      } else {
        trend = Trend.same;
      }

      // Ürün ID'si ile veriyi map'e kaydet
      newTrendData[summary.id] = ProductTrendData(
        spots: spots,
        trend: trend,
        changePercentage: changePercentage,
      );
    }

    // State'i tek seferde güncelle
    if (mounted) {
      setState(() {
        _productTrendData = newTrendData;
      });
    }
  }

  // _loadData'yı çağırır, o da trend verisini yeniler
  void _setFilter(String filter, DateTime start, DateTime end) {
    setState(() {
      _currentFilter = filter;
      _startDate = start.copyWith(
          hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      _endDate = end.copyWith(
          hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
    });
    // _loadData artık trend verisini de güncelleyecek
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Tarih Aralığı Seç',
      saveText: 'Uygula',
    );
    if (picked != null) {
      _setFilter('Özel Aralık', picked.start, picked.end);
    }
  }

  Future<void> _generateAndShowPdf(Map<String, double> filteredRevenueMap,
      List<TopProduct> topSellingProducts, double totalRevenue) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfService = PdfReportService();
      final reportData = ReportData(
        startDate: _startDate,
        endDate: _endDate,
        totalRevenue: totalRevenue,
        dailyRevenues: filteredRevenueMap,
        topProducts: topSellingProducts,
      );

      final reportResult = await pdfService.generateReport(reportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF Raporu başarıyla oluşturuldu!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'AÇ',
              onPressed: () {
                pdfService.openPdfFile(context, reportResult.pdfFile);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata oluştu: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Map<String, double> _getFilteredRevenueMap(DailyRevenueProvider provider) {
    Map<String, double> revenueMap = {};
    for (var date = _startDate;
        date.isBefore(_endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      revenueMap[formattedDate] = 0.0;
    }

    for (var dailyRevenue in provider.dailyRevenues) {
      try {
        DateTime revenueDate = DateTime.parse(dailyRevenue.date);
        if (revenueDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            revenueDate.isBefore(_endDate.add(const Duration(days: 1)))) {
          revenueMap[dailyRevenue.date] =
              (revenueMap[dailyRevenue.date] ?? 0.0) + dailyRevenue.revenue;
        }
      } catch (e) {
        debugPrint('Geçersiz tarih formatı: ${dailyRevenue.date}');
      }
    }
    return Map.fromEntries(revenueMap.entries.toList()
      ..sort((e1, e2) => e1.key.compareTo(e2.key)));
  }

  // PDF oluşturma için bu fonksiyona hala ihtiyaç var.
  List<TopProduct> _getFilteredTopProducts(DailyRevenueProvider provider) {
    final Map<String, double> productSales = {};

    final filteredRevenues = provider.dailyRevenues.where((rev) {
      try {
        final revDate = DateTime.parse(rev.date);
        return revDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            revDate.isBefore(_endDate.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    });

    for (final dailyData in filteredRevenues) {
      for (final entry in dailyData.soldProducts.entries) {
        final productName = entry.key;
        final count = entry.value;
        productSales[productName] = (productSales[productName] ?? 0.0) + count;
      }
    }

    final List<TopProduct> topProducts = productSales.entries
        .map((entry) =>
            TopProduct(name: entry.key, salesCount: entry.value.toInt()))
        .toList();

    topProducts.sort((a, b) => b.salesCount.compareTo(a.salesCount));

    return topProducts;
  }

  @override
  Widget build(BuildContext context) {
    // PDF ve Ciro Trendi için DailyRevenueProvider'a hala ihtiyaç var
    final dailyRevenueProvider = Provider.of<DailyRevenueProvider>(context);
    // Ürün listesi ve pasta grafik için ProductProvider'ı dinle
    final productProvider =
        Provider.of<ProductProviderAlias.ProductProvider>(context);

    // Ciro trendi için
    final filteredRevenueMap = _getFilteredRevenueMap(dailyRevenueProvider);
    final totalRevenue =
        filteredRevenueMap.values.fold(0.0, (sum, revenue) => sum + revenue);

    // PDF için (hala _getFilteredTopProducts kullanıyor)
    final List<TopProduct> topSellingProductsForPdf =
        _getFilteredTopProducts(dailyRevenueProvider);

    // UI için productProvider'dan gelen özet listesi
    final productSummaries = productProvider.filteredSalesSummary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Gelişmiş Rapor Panosu',
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
          // OTOMATİK RAPOR BUTONU KALDIRILDI
          _buildAppBarAction(
              MdiIcons.folderOpen, 'Rapor Geçmişi', Colors.blue.shade600, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportListScreen()),
            );
          }),
          _buildAppBarAction(
            _isGeneratingPdf ? null : Icons.picture_as_pdf_outlined,
            'PDF Olarak Dışa Aktar',
            Colors.red.shade600,
            _isGeneratingPdf
                ? null
                : () => _generateAndShowPdf(filteredRevenueMap,
                    topSellingProductsForPdf, totalRevenue), // PDF verisi
            isLoading: _isGeneratingPdf,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterBar(),
            const SizedBox(height: 16),
            _buildSummaryText(totalRevenue),
            const SizedBox(height: 20),
            _buildSimpleAIAdvice(totalRevenue),
            _buildSectionHeader(
                'Günlük Ciro Trendi',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailedRevenueScreen(
                            startDate: _startDate, endDate: _endDate)))),
            const SizedBox(height: 12),
            _buildRevenueChartCard(filteredRevenueMap),
            const SizedBox(height: 24),
            _buildSectionHeader(
                'Ürün Satış Dağılımı',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailedProductScreen(
                            startDate: _startDate, endDate: _endDate)))),
            const SizedBox(height: 12),
            _buildTopProductsSection(productSummaries),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarAction(
      IconData? icon, String tooltip, Color color, VoidCallback? onPressed,
      {bool isLoading = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: isLoading
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: color,
              ),
            )
          : IconButton(
              icon: Icon(icon, size: 26, color: color),
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
              tooltip: tooltip,
              onPressed: onPressed == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed();
                    },
            ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Bugün', const Duration(days: 0)),
          _buildFilterChip('Son 3 Gün', const Duration(days: 2)),
          _buildFilterChip('Son 7 Gün', const Duration(days: 6)),
          _buildFilterChip('Son 30 Gün', const Duration(days: 29)),
          _buildFilterChip('Son 60 Gün', const Duration(days: 59)),
          _buildDateRangeChip(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Duration duration) {
    final bool isSelected = _currentFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? Colors.deepPurple.shade400 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 4 : 0,
        shadowColor: isSelected
            ? Colors.deepPurple.withOpacity(0.4)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            final end = DateTime.now();
            final start = end.subtract(duration);
            _setFilter(label, start, end);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                  width: 1.5),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.deepPurple.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final isSelected = _currentFilter.startsWith('Özel');
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? Colors.deepPurple.shade400 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 4 : 0,
        shadowColor: isSelected
            ? Colors.deepPurple.withOpacity(0.4)
            : Colors.transparent,
        child: InkWell(
          onTap: _selectDateRange,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                  width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    size: 18,
                    color:
                        isSelected ? Colors.white : Colors.deepPurple.shade600),
                const SizedBox(width: 8),
                Text(
                  'Tarih Seç',
                  style: TextStyle(
                    color:
                        isSelected ? Colors.white : Colors.deepPurple.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryText(double totalRevenue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RAPOR ARALIĞI',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM yyyy', 'tr_TR').format(_startDate)} - ${DateFormat('dd MMM yyyy', 'tr_TR').format(_endDate)}',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1.5,
            height: 40,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOPLAM CİRO',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(totalRevenue),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAIAdvice(double totalRevenue) {
    String adviceText;
    String title;
    IconData icon;
    Color color;

    if (totalRevenue == 0) {
      title = 'Satış Verisi Yok';
      adviceText =
          'Seçilen aralıkta satış yapılmamış. Envanter ve fiyatlandırmayı kontrol edin.';
      icon = Icons.error_outline_rounded;
      color = Colors.red.shade400;
    } else if (totalRevenue > 10000) {
      title = 'Mükemmel Ciro!';
      adviceText =
          'En çok satan ürünlerin trendlerini analiz ederek pazarlama stratejinizi güçlendirin.';
      icon = Icons.rocket_launch_rounded;
      color = Colors.green.shade500;
    } else if (totalRevenue > 5000) {
      title = 'İyi Performans!';
      adviceText =
          'Hafta sonu cirolarına odaklanarak ortalamayı yükseltebilirsiniz.';
      icon = Icons.lightbulb_outline_rounded;
      color = Colors.orange.shade500;
    } else {
      title = 'Geliştirilebilir Alan';
      adviceText =
          'Düşük performanslı ürünleri indirimle veya set halinde sunmayı deneyin.';
      icon = Icons.trending_down_rounded;
      color = Colors.blue.shade400;
    }

    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(adviceText,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Row(
            children: [
              Text('Tümünü Gör', style: TextStyle(color: Colors.teal.shade600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.teal.shade600),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildRevenueChartCard(Map<String, double> filteredRevenueMap) {
    final sortedDates = filteredRevenueMap.keys.toList();
    final maxRevenue =
        filteredRevenueMap.values.fold(0.0, (max, v) => v > max ? v : max);

    List<BarChartGroupData> barGroups = List.generate(sortedDates.length, (i) {
      final revenue = filteredRevenueMap[sortedDates[i]]!;
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: revenue,
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.teal.shade400],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6), topRight: Radius.circular(6)),
        ),
      ]);
    });

    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 280,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: barGroups.isEmpty
            ? const Center(child: Text('Seçilen aralıkta veri yok.'))
            : BarChart(
                BarChartData(
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxRevenue == 0 ? 100 : maxRevenue * 1.2,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int daysToShow = (sortedDates.length ~/ 6)
                              .clamp(1, sortedDates.length);
                          if (value.toInt() % daysToShow == 0) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(
                                DateFormat('dd/MM').format(
                                    DateTime.parse(sortedDates[value.toInt()])),
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact(locale: 'tr_TR').format(value),
                          style: const TextStyle(fontSize: 11),
                        ),
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${DateFormat('dd MMM yyyy').format(DateTime.parse(sortedDates[group.x]))}\n',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: NumberFormat.currency(
                                    locale: 'tr_TR', symbol: '₺')
                                .format(rod.toY),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTopProductsSection(
      List<ProductProviderAlias.ProductSaleSummary> productSummaries) {
    if (productSummaries.isEmpty) {
      return Card(
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const SizedBox(
          height: 150,
          child: Center(child: Text('Satış verisi bulunan ürün yok.')),
        ),
      );
    }

    double totalSales =
        productSummaries.fold(0.0, (sum, p) => sum + p.salesQuantity);
    List<PieChartSectionData> pieSections = [];
    int limit = 5;
    double otherSales = 0;

    for (int i = 0; i < productSummaries.length; i++) {
      final product = productSummaries[i];
      if (i < limit) {
        pieSections.add(PieChartSectionData(
          color: _pieChartColors[i],
          value: product.salesQuantity.toDouble(),
          title:
              '${(product.salesQuantity / totalSales * 100).toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      } else {
        otherSales += product.salesQuantity;
      }
    }

    if (otherSales > 0) {
      pieSections.add(PieChartSectionData(
        color: _pieChartColors[limit],
        value: otherSales,
        title: '${(otherSales / totalSales * 100).toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Column(
      children: [
        Card(
          elevation: 4,
          shadowColor: Colors.blue.withOpacity(0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: productSummaries.length > limit
                      ? limit + 1
                      : productSummaries.length,
                  itemBuilder: (context, index) {
                    if (index < limit && index < productSummaries.length) {
                      return _buildLegendItem(
                          productSummaries[index].name, _pieChartColors[index]);
                    } else if (index == limit &&
                        productSummaries.length > limit) {
                      return _buildLegendItem('Diğer', _pieChartColors[index]);
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: productSummaries.length > 5 ? 6 : productSummaries.length,
          itemBuilder: (context, index) {
            if (index == 5) {
              // "Diğer" kartı için özel bir özet oluştur
              final otherSummary = ProductProviderAlias.ProductSaleSummary(
                  id: 'other',
                  name: 'Diğer Ürünler',
                  salesQuantity: otherSales.toInt());
              return _buildProductTrendCard(otherSummary, _pieChartColors[5]);
            }
            final product = productSummaries[index];
            return _buildProductTrendCard(product, _pieChartColors[index]);
          },
        )
      ],
    );
  }

  Widget _buildProductTrendCard(
      ProductProviderAlias.ProductSaleSummary summary, Color color) {
    // Trend verisini state'ten al
    final trendData = _productTrendData[summary.id];

    // Veri henüz yüklenmediyse boş bir kart göster
    if (trendData == null) {
      return Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${summary.salesQuantity} Adet Satıldı',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
    }

    IconData trendIcon;
    Color trendColor;
    String trendText;

    switch (trendData.trend) {
      case Trend.up:
        trendIcon = Icons.trending_up_rounded;
        trendColor = Colors.green.shade600;
        trendText = '+${trendData.changePercentage.abs().toStringAsFixed(1)}%';
        break;
      case Trend.down:
        trendIcon = Icons.trending_down_rounded;
        trendColor = Colors.red.shade600;
        trendText = '-${trendData.changePercentage.abs().toStringAsFixed(1)}%';
        break;
      case Trend.same:
        trendIcon = Icons.trending_flat_rounded;
        trendColor = Colors.grey.shade600;
        trendText = '${trendData.changePercentage.toStringAsFixed(1)}%';
        break;
    }

    // "Diğer" kartı için tıklamayı ve trendi devre dışı bırak
    final bool isOtherCard = summary.id == 'other';

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // "Diğer" ise tıklanabilir olmasın
        onTap: isOtherCard
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ProductDetailAnalyticsScreen(
                    productId: summary.id, productName: summary.name))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child:
                      Icon(Icons.inventory_2_outlined, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${summary.salesQuantity} Adet Satıldı',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // "Diğer" kartıysa trendi gösterme
              if (!isOtherCard)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(trendIcon, color: trendColor, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        trendText,
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        height: 30,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: trendData.spots,
                                isCurved: true,
                                color: trendColor,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: trendColor.withOpacity(0.15),
                                ),
                              )
                            ],
                            // Grafiğin Y eksenini ayarla
                            minY: trendData.spots
                                    .map((e) => e.y)
                                    .reduce((a, b) => a < b ? a : b) *
                                0.9, // Min değerin biraz altı
                            maxY: trendData.spots
                                    .map((e) => e.y)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.1, // Max değerin biraz üstü
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              if (!isOtherCard)
                Icon(Icons.chevron_right, color: Colors.grey.shade400)
              else
                const SizedBox(width: 24), // Yer tutucu
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
