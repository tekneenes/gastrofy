import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/daily_revenue_model.dart';
import 'product_detail_analytics_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'subscription_plans_screen.dart';

import '../models/top_product.dart';
import '../providers/daily_revenue_provider.dart';
import '../providers/product_provider.dart' as ProductProviderAlias;
import 'DetailedProductScreen.dart';
import 'DetailedRevenueScreen.dart';
import 'report_list_screen.dart';
import '../services/pdf_report_service.dart';
import '../providers/table_report_provider.dart';
import 'DetailedTableScreen.dart';
import 'TableDetailReportScreen.dart';
import '../services/table_ai_service.dart';
import '../services/database_helper.dart'; // EKLENDİ
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // EKLENDİ
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

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

class _ReportScreenState extends State<ReportScreen> with TickerProviderStateMixin {
  bool _isPremium = true; // Set to true for testing phase as requested

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  String _currentFilter = 'Son 30 Gün';
  bool _isGeneratingPdf = false;
  int _touchedPieIndex = -1;

  final TableAIService _aiService = TableAIService();
  String _aiAdvice = '';
  bool _aiAdviceIsFromCache = false;
  bool _isAiLoading = false;
  bool _isAiPlanRequired = false;
  String _currentPlan = 'Aylık Plan';
  late AnimationController _lottieController;
  int _visibleInsightCount = 0;
  Timer? _insightAnimTimer;
  late AnimationController _glowController;

  // Ürün trend verilerini tutmak için map
  Map<String, ProductTrendData> _productTrendData = {};
  
  // Gün bazlı ürün satış adetleri (Stack chart için)
  Map<String, Map<String, int>> _dailyProductSalesMap = {};

  // Dönem içinde kapatılan siparişlerin önbelleği
  List<Map<String, dynamic>> _closedOrders = [];

  // Satış yapıldığında verilerin otomatik güncellenmesini tetiklemek için ciro takibi
  double _lastKnownTotalRevenue = -1.0;

  final List<Color> _pieChartColors = [
    const Color(0xFF3498DB),
    const Color(0xFF1ABC9C),
    const Color(0xFFE74C3C),
    const Color(0xFFF39C12),
    const Color(0xFF16A085),
    const Color(0xFF2ECC71),
    Colors.grey.shade500,
  ];

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    initializeDateFormatting('tr_TR', null);
    _setInitialDates();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAiApiKey();
      _loadData();
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _glowController.dispose();
    _insightAnimTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('groq_api_key') ?? prefs.getString('gemini_api_key');

    if (apiKey == null || apiKey.isEmpty) {
      try {
        if (dotenv.isInitialized) {
          apiKey = dotenv.env['GROQ_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];
        }
      } catch (e) {
        debugPrint("ReportScreen Dotenv erişim hatası: $e");
      }
    }

    apiKey ??= "";

    if (apiKey.isNotEmpty) {
      _aiService.setApiKey(apiKey);
    }
  }

  void _setInitialDates() {
    _startDate = DateTime.now().subtract(const Duration(days: 29)).copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    _endDate = DateTime.now().copyWith(
        hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
  }

  void _startStaggeredReveal() {
    _insightAnimTimer?.cancel();
    final sections = _parseAdvice(_aiAdvice);
    int total = sections.length;
    
    _insightAnimTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_visibleInsightCount < total) {
          _visibleInsightCount++;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // Provider'ları yükledikten sonra trend verisini hesaplar
  Future<void> _loadData() async {
    if (mounted) {
      final dailyRevenueProvider =
          Provider.of<DailyRevenueProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProviderAlias.ProductProvider>(
          context,
          listen: false);

      final tableReportProvider =
          Provider.of<TableReportProvider>(context, listen: false);

      // Provider'ları paralel olarak yükle ve tamamlanmalarını bekle
      await Future.wait([
        dailyRevenueProvider.loadDailyRevenues(),
        productProvider.loadProductSalesSummary(
            startDate: _startDate, endDate: _endDate),
        tableReportProvider.loadTableSalesSummary(
            startDate: _startDate, endDate: _endDate)
      ]);

      // Daily Product Sales Verisini Çek (Stack Adjust için)
      final closedOrders = await DatabaseHelper.instance.getClosedOrdersByDateRange(_startDate, _endDate);
      final Map<String, Map<String, int>> dailySales = {};
      
      for (var order in closedOrders) {
        final dateStr = (order['createdAt'] as String).substring(0, 10);
        if (!dailySales.containsKey(dateStr)) dailySales[dateStr] = {};
        
        final String itemsJson = order['itemsJson'] ?? '[]';
        if (itemsJson.isNotEmpty) {
          try {
            final List<dynamic> itemsList = jsonDecode(itemsJson);
            for (var itemMap in itemsList) {
              final String productId = itemMap['productId']?.toString() ?? '';
              final int qty = (itemMap['quantity'] as num?)?.toInt() ?? 0;
              if (productId.isNotEmpty) {
                dailySales[dateStr]![productId] = (dailySales[dateStr]![productId] ?? 0) + qty;
              }
            }
          } catch (_) {}
        }
      }
      
      setState(() {
        _closedOrders = closedOrders;
        _dailyProductSalesMap = dailySales;
      });

      // Veriler yüklendikten sonra trendleri hesapla
      _generateProductTrendData();
      
      // Yapay zeka tavsiyesini getir (Cache öncelikli)
      _fetchAIAdvice(forceRefresh: false);
    }
  }

  double _totalFrames = 180.0; // Varsayılan, onLoaded ile güncellenecek

  Future<void> _fetchAIAdvice({bool forceRefresh = false}) async {
    if (!mounted) return;

    final String cacheKey = "ai_report_${_startDate.millisecondsSinceEpoch}_${_endDate.millisecondsSinceEpoch}";
    final prefs = await SharedPreferences.getInstance();

    // 1. Plan kontrolü: Yıllık Plan ve Deneme Sürümü açık, Aylık Planda kilitli
    try {
      final licenseInfo = await DatabaseService().getLicenseRemainingInfo();
      final String plan = licenseInfo['planName'] ?? 'Aylık Plan';
      _currentPlan = plan;
      final bool isAnnualOrTrial = plan.contains('Yıllık') || plan.contains('Deneme') || plan.contains('Trial');
      if (!isAnnualOrTrial) {
        if (mounted) {
          setState(() {
            _isAiLoading = false;
            _isAiPlanRequired = true;
            _aiAdvice = 'PLAN_REQUIRED';
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Plan check error in reports: $e");
    }

    if (!forceRefresh) {
      final cachedAdvice = prefs.getString(cacheKey);
      if (cachedAdvice != null && cachedAdvice.isNotEmpty) {
        if (cachedAdvice == 'PLAN_REQUIRED' ||
            cachedAdvice.contains('Analiz şu an yapılamıyor') ||
            cachedAdvice.contains('Sistem servisi')) {
          setState(() {
            _isAiPlanRequired = true;
            _aiAdvice = 'PLAN_REQUIRED';
            _isAiLoading = false;
          });
          return;
        }
        setState(() {
          _isAiPlanRequired = false;
          _aiAdvice = cachedAdvice;
          _aiAdviceIsFromCache = true;
          _isAiLoading = false;
          _visibleInsightCount = 0;
        });
        // Cache'den yüklendiğinde de animasyonu sona götür
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _lottieController.animateTo(84 / _totalFrames, duration: const Duration(milliseconds: 500));
          _startStaggeredReveal();
        });
        return;
      }
    }

    final productProvider = Provider.of<ProductProviderAlias.ProductProvider>(
        context,
        listen: false);
    final tableReportProvider =
        Provider.of<TableReportProvider>(context, listen: false);

    final dailyRevenueProvider =
        Provider.of<DailyRevenueProvider>(context, listen: false);
    final filteredRevenueMap = _getFilteredRevenueMap(dailyRevenueProvider);
    final totalRevenue =
        filteredRevenueMap.values.fold(0.0, (sum, revenue) => sum + revenue);

    setState(() {
      _isAiLoading = true;
      _aiAdvice = '';
      _isAiPlanRequired = false;
      _aiAdviceIsFromCache = false;
    });

    try {
      final topProducts = productProvider.filteredSalesSummary.take(5).map((p) {
        return "${p.name}: ${p.salesQuantity} adet";
      }).join(", ");

      final tablePerformance = tableReportProvider.tableSummaries.take(3).map((t) {
        return "${t.name}: ${t.totalRevenue.toStringAsFixed(2)} TL";
      }).join(", ");

      String reportContext = """
Tarih Aralığı: ${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}
Toplam Ciro: ${totalRevenue.toStringAsFixed(2)} TL
Filtre: $_currentFilter
En Çok Satanlar: $topProducts
Masa Performansları: $tablePerformance
""";

      final advice = await _aiService.getReportAnalysis(reportContext);

      if (advice == "PLAN_REQUIRED" ||
          advice.contains("PLAN_REQUIRED") ||
          advice.contains("Analiz şu an yapılamıyor") ||
          advice.contains("Sistem servisi")) {
        if (mounted) {
          setState(() {
            _isAiLoading = false;
            _isAiPlanRequired = true;
            _aiAdvice = "PLAN_REQUIRED";
          });
          await prefs.setString(cacheKey, "PLAN_REQUIRED");
        }
        return;
      }

      if (mounted) {
        setState(() {
          _aiAdvice = advice;
          _isAiPlanRequired = false;
          _isAiLoading = false;
          _visibleInsightCount = 0;
        });
        
        // Yanıtı cache'le
        await prefs.setString(cacheKey, advice);

        // Analiz bittiğinde 84. frame'e git ve dur (180 frame üzerinden ~0.466)
        _lottieController.animateTo(84 / _totalFrames, duration: const Duration(milliseconds: 500)); 

        // Kademeli açılış animasyonunu başlat
        _startStaggeredReveal();
      }
    } catch (e) {
      debugPrint("AI Advice Error: $e");
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _isAiPlanRequired = true;
          _aiAdvice = "PLAN_REQUIRED";
        });
      }
    }
  }

  // Ürün trend verilerini (sparkline ve yüzde) oluşturan fonksiyon
  void _generateProductTrendData() {
    final productProvider = Provider.of<ProductProviderAlias.ProductProvider>(context, listen: false);
    final productSummaries = productProvider.filteredSalesSummary;

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

        // O günkü satış verisini _dailyProductSalesMap içinden bul
        final sales = (_dailyProductSalesMap[dateString]?[summary.id] ?? 0).toDouble();

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
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade600,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF1A1A2E),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
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

  // PDF ve metrikler için filtrelenmiş en çok satan ürünleri hesapla
  List<TopProduct> _getFilteredTopProducts(
      DailyRevenueProvider provider,
      List<ProductProviderAlias.ProductSaleSummary> productSummaries) {
    final Map<String, int> productSales = {};

    // 1. Kapalı sipariş kayıtlarından ürün satış adetlerini topla (özel ürünler dahil)
    for (var order in _closedOrders) {
      final String itemsJson = order['itemsJson'] ?? '[]';
      if (itemsJson.isNotEmpty) {
        try {
          final List<dynamic> itemsList = jsonDecode(itemsJson);
          for (var itemMap in itemsList) {
            final String name = (itemMap['productName'] ?? itemMap['name'] ?? '').toString().trim();
            final int qty = (itemMap['quantity'] as num?)?.toInt() ?? 0;
            if (name.isNotEmpty && qty > 0) {
              productSales[name] = (productSales[name] ?? 0) + qty;
            }
          }
        } catch (_) {}
      }
    }

    // 2. ProductProvider özetindeki ürünleri kontrol et
    for (var p in productSummaries) {
      if (p.salesQuantity > 0 && !productSales.containsKey(p.name)) {
        productSales[p.name] = p.salesQuantity;
      }
    }

    // 3. DailyRevenueProvider içindeki soldProducts haritasını da dahil et
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
        if (!productSales.containsKey(entry.key) && entry.value > 0) {
          productSales[entry.key] = entry.value;
        }
      }
    }

    final List<TopProduct> topProducts = productSales.entries
        .map((entry) => TopProduct(name: entry.key, salesCount: entry.value))
        .toList();

    topProducts.sort((a, b) => b.salesCount.compareTo(a.salesCount));

    return topProducts;
  }

  @override
  Widget build(BuildContext context) {
    // PDF ve Ciro Trendi için DailyRevenueProvider'a hala ihtiyaç var
    final dailyRevenueProvider = Provider.of<DailyRevenueProvider>(context);

    // OTOMATİK YENİLEME MANTIĞI: Veritabanına yeni bir satış eklendiğinde
    // provider içindeki toplam ciro değişecektir. Bunu tespit edip ekranı yeniliyoruz.
    double currentTotalRev = dailyRevenueProvider.dailyRevenues.fold(0.0, (sum, item) => sum + item.revenue);
    if (_lastKnownTotalRevenue == -1.0) {
      _lastKnownTotalRevenue = currentTotalRev;
    } else if (_lastKnownTotalRevenue != currentTotalRev) {
      _lastKnownTotalRevenue = currentTotalRev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Build bitiminde verileri yeniden çekip grafikleri tazelemek için:
        if (mounted) _loadData();
      });
    }

    // Ürün listesi ve pasta grafik için ProductProvider'ı dinle
    final productProvider =
        Provider.of<ProductProviderAlias.ProductProvider>(context);

    // Ciro trendi için
    final filteredRevenueMap = _getFilteredRevenueMap(dailyRevenueProvider);
    final totalRevenue =
        filteredRevenueMap.values.fold(0.0, (sum, revenue) => sum + revenue);

    // UI için productProvider'dan gelen özet listesi
    final productSummaries = productProvider.filteredSalesSummary;

    // PDF ve metrikler için filtrelenmiş en çok satan ürünler listesi
    final List<TopProduct> topSellingProductsForPdf =
        _getFilteredTopProducts(dailyRevenueProvider, productSummaries);

    // Masa bazlı raporlama için TableReportProvider
    final tableReportProvider = Provider.of<TableReportProvider>(context);
    final tableSummaries = tableReportProvider.tableSummaries;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('İşletme Raporları',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 0,
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
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: !_isPremium,
            child: SingleChildScrollView(
              physics: _isPremium ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _buildFilterBar(),
            const SizedBox(height: 24),
            
            // 1. Üst Metrik Kartları (Global) - Tek Sıra (Ölçeklenebilir, Kaydırma Yok)
            Row(
              children: [
                _buildDashboardMetricCard(
                  'Toplam Ciro',
                  NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺')
                      .format(totalRevenue),
                  MdiIcons.currencyTry,
                  Colors.teal.shade700,
                ),
                const SizedBox(width: 4),
                _buildDashboardMetricCard(
                  'Sipariş Sayısı',
                  _closedOrders.isNotEmpty
                      ? _closedOrders.length.toString()
                      : topSellingProductsForPdf
                          .fold(0, (sum, p) => sum + p.salesCount)
                          .toString(),
                  MdiIcons.chartDonut,
                  Colors.blue.shade600,
                ),
                const SizedBox(width: 4),
                _buildDashboardMetricCard(
                  'En Çok Satan',
                  topSellingProductsForPdf.isEmpty
                      ? '-'
                      : topSellingProductsForPdf.first.name,
                  Icons.star_rounded,
                  Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                _buildDashboardMetricCard(
                  'En Verimli Masa',
                  tableSummaries.isEmpty
                      ? '-'
                      : (tableSummaries.any((t) => t.totalRevenue > 0)
                          ? tableSummaries
                              .reduce((a, b) =>
                                  a.totalRevenue > b.totalRevenue ? a : b)
                              .name
                          : '-'),
                  MdiIcons.crownOutline,
                  Colors.amber.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSimpleAIAdvice(totalRevenue),
            
            const SizedBox(height: 12),
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
            _buildTopProductsSection(productSummaries, filteredRevenueMap),
            const SizedBox(height: 24),
            
            _buildTableSalesSection(tableSummaries),
            const SizedBox(height: 32),
          ],
              ),
            ),
          ),
          if (!_isPremium) _buildPremiumLockOverlay(),
        ],
      ),
    );
  }

  Widget _buildPremiumLockOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.white.withValues(alpha: 0.6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10),
                    ],
                  ),
                  child: const Icon(Icons.diamond_rounded, size: 72, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Sadece Premium Kullanıcılar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'İşletmenizin detaylı analizlerini görmek ve yapay zeka ile gelirinizi artırmak için Premium\'a geçin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionPlansScreen(email: 'demo_user@gastrofy.com'),
                      ),
                    );
                    if (result == true) {
                      setState(() => _isPremium = true); // Unlock!
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                    shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.3),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Premium\'u İncele', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip('Bugün', const Duration(days: 0)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 3 Gün', const Duration(days: 2)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 7 Gün', const Duration(days: 6)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 30 Gün', const Duration(days: 29)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 60 Gün', const Duration(days: 59)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 90 Gün', const Duration(days: 89)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 180 Gün', const Duration(days: 179)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 240 Gün', const Duration(days: 239)),
          const SizedBox(width: 8),
          _buildFilterChip('Son 300 Gün', const Duration(days: 299)),
          const SizedBox(width: 8),
          _buildDateRangeChip(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Duration duration) {
    final bool isSelected = _currentFilter == label;
    return Material(
      color: isSelected ? Colors.teal.shade500 : Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: isSelected ? 2 : 0,
      child: InkWell(
        onTap: () {
          final end = DateTime.now();
          final start = end.subtract(duration);
          _setFilter(label, start, end);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                width: 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.teal.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final isSelected = _currentFilter.startsWith('Özel');
    return Material(
      color: isSelected ? Colors.teal.shade500 : Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: isSelected ? 2 : 0,
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                'Tarih',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardMetricCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 28.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _parseAdvice(String text) {
    final Map<String, String> sections = {};
    final RegExp regExp = RegExp(r'\[(.*?)\]:\s*(.*?)(?=\s*\[|$)', dotAll: true);
    final matches = regExp.allMatches(text);

    for (final match in matches) {
      final title = match.group(1)?.trim() ?? "";
      final content = match.group(2)?.trim() ?? "";
      if (title.isNotEmpty && content.isNotEmpty) {
        sections[title] = content;
      }
    }

    if (sections.isEmpty && text.isNotEmpty) {
      sections['ANALİZ'] = text;
    }

    return sections;
  }

  Widget _buildSimpleAIAdvice(double totalRevenue) {
    String adviceText = _aiAdvice;
    final bool isPlanRequired = _isAiPlanRequired || adviceText == 'PLAN_REQUIRED';

    Widget headerCard = InkWell(
      onTap: _isAiLoading
          ? null
          : () {
              if (isPlanRequired) {
                _navigateToPlansScreen();
              } else {
                _fetchAIAdvice(forceRefresh: true);
              }
            },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: EdgeInsets.only(bottom: (adviceText.isNotEmpty || isPlanRequired) && !_isAiLoading ? 12 : 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF10B981), // Canlı zümrüt yeşili
                    Color(0xFF0D9488), // Koyu teal
                    Color(0xFF0284C7), // Okyanus mavisi
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TABLE INTELLIGENCE',
                    style: GoogleFonts.outfit(
                      color: Colors.green.shade400,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    _isAiLoading 
                        ? 'Analiz ediliyor...' 
                        : (isPlanRequired
                            ? 'Yapay Zeka Raporu'
                            : (adviceText.isEmpty ? 'Yapay Zeka ile Analiz Et' : 'Yapay Zeka Raporu')),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isAiLoading) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isAiLoading)
              IconButton(
                onPressed: () {
                  if (isPlanRequired) {
                    _navigateToPlansScreen();
                  } else {
                    _fetchAIAdvice(forceRefresh: true);
                  }
                },
                icon: Icon(
                  isPlanRequired
                      ? Icons.workspace_premium_rounded
                      : (adviceText.isEmpty ? Icons.arrow_forward_ios_rounded : Icons.refresh_rounded), 
                  color: isPlanRequired ? Colors.amber : Colors.white70,
                  size: isPlanRequired ? 26 : (adviceText.isEmpty ? 18 : 24),
                ),
                tooltip: isPlanRequired ? 'Planınızı Yükseltin' : (adviceText.isEmpty ? 'Analiz Et' : 'Yenile'),
              ),
          ],
        ),
      ),
    );

    if (isPlanRequired) {
      return AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return CustomPaint(
            painter: AppleIntelligenceGlowPainter(animationValue: _glowController.value),
            child: child,
          );
        },
        child: Column(
          children: [
            headerCard,
            _buildPlanUpgradeCard(),
          ],
        ),
      );
    }

    if (_isAiLoading || adviceText.isEmpty) {
      return AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return CustomPaint(
            painter: AppleIntelligenceGlowPainter(animationValue: _glowController.value),
            child: child,
          );
        },
        child: headerCard,
      );
    }

    final parsedSections = _parseAdvice(adviceText);

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return CustomPaint(
          painter: AppleIntelligenceGlowPainter(animationValue: _glowController.value),
          child: child,
        );
      },
      child: Column(
        children: [
          headerCard,
          ...parsedSections.entries.toList().asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
          final entry = mapEntry.value;
          
          if (index >= _visibleInsightCount) return const SizedBox.shrink();

          IconData icon;
          Color color;
          
          if (entry.key.contains('PERFORMANS')) {
            icon = Icons.insights_rounded;
            color = Colors.blue.shade600;
          } else if (entry.key.contains('STRATEJİ')) {
            icon = Icons.ads_click_rounded;
            color = Colors.purple.shade600;
          } else if (entry.key.contains('OPERASYON')) {
            icon = Icons.precision_manufacturing_rounded;
            color = Colors.orange.shade700;
          } else {
            icon = Icons.tips_and_updates_rounded;
            color = Colors.teal.shade600;
          }

          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border(left: BorderSide(
                        color: Color.lerp(Colors.green.shade300, color, value.clamp(0.0, 1.0)) ?? color, 
                        width: 6,
                      )),
                      boxShadow: [
                        // Yeşil dalga efekti: Giriş anında daha parlak, sonra sakinleşen ışık
                        BoxShadow(
                          color: Colors.green.withOpacity((0.2 * (1 - value)).clamp(0.0, 1.0)),
                          blurRadius: 20,
                          spreadRadius: 5 * (1 - value.clamp(0.0, 1.0)),
                        ),
                        BoxShadow(
                          color: color.withOpacity((0.1 * value).clamp(0.0, 1.0)),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: color, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              entry.key,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _TypewriterText(
                          entry.value,
                          animate: !_aiAdviceIsFromCache,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                            height: 1.6,
                          ),
                          speed: const Duration(milliseconds: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
        const SizedBox(height: 12),
      ],
    ),);
  }

  Future<void> _navigateToPlansScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPlansScreen(
          email: 'demo_user@gastrofy.com',
          currentPlan: _currentPlan,
        ),
      ),
    );
    if (result == true) {
      _fetchAIAdvice(forceRefresh: true);
    }
  }

  Widget _buildPlanUpgradeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF0284C7).withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF0284C7),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'YILLIK PLANA ÖZEL',
                        style: TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yapay Zeka Raporları İçin Planınızı Yükseltin',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'İşletmenizin ciro tahminleri, en verimli masa stratejileri ve yapay zeka menü optimizasyonu Yıllık Plan üyelerine özeldir. Bu analitiğe erişmek için lütfen planınızı yükseltin.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.blueGrey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _navigateToPlansScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  'Planınızı Yükseltin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
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

    List<FlSpot> spots = [];
    if (sortedDates.length == 1) {
      // Eğer sadece tek gün veri varsa, çizginin belirmesi için yapay bir nokta ekliyoruz.
      final revenue = filteredRevenueMap[sortedDates[0]]!;
      spots.add(FlSpot(0, revenue));
      spots.add(FlSpot(1, revenue));
    } else {
      spots = List.generate(sortedDates.length, (i) {
        final revenue = filteredRevenueMap[sortedDates[i]]!;
        return FlSpot(i.toDouble(), revenue);
      });
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 280,
        padding: const EdgeInsets.fromLTRB(16, 24, 24, 12),
        child: sortedDates.isEmpty
            ? const Center(child: Text('Seçilen aralıkta veri yok.'))
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxRevenue > 0 ? maxRevenue / 4 : 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          
                          if (sortedDates.length == 1) {
                            if (index == 0 || index == 1) {
                              return SideTitleWidget(
                                meta: meta,
                                space: 8,
                                child: Text(
                                  DateFormat('dd/MM').format(DateTime.parse(sortedDates[0])),
                                  style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return const SizedBox();
                          }

                          if (index < 0 || index >= sortedDates.length) return const SizedBox();
                          
                          int daysToShow = (sortedDates.length ~/ 6).clamp(1, sortedDates.length);
                          if (index % daysToShow == 0 || index == sortedDates.length - 1) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              child: Text(
                                DateFormat('dd/MM').format(DateTime.parse(sortedDates[index])),
                                style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) => Text(
                          NumberFormat.compact(locale: 'tr_TR').format(value),
                          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: sortedDates.length <= 1 ? 1.0 : (sortedDates.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxRevenue == 0 ? 100 : maxRevenue * 1.2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: Colors.teal.shade500,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: sortedDates.length <= 15,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.teal.shade600,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.teal.shade400.withOpacity(0.4),
                            Colors.teal.shade200.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF1E293B),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final dateStr = sortedDates[spot.x.toInt()];
                          final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
                          final value = NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(spot.y);
                          return LineTooltipItem(
                            '$formattedDate\n',
                            const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: value,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTopProductsSection(
      List<ProductProviderAlias.ProductSaleSummary> productSummaries,
      Map<String, double> filteredRevenueMap) {
    if (productSummaries.isEmpty) {
      return Card(
        elevation: 4,
        color: Colors.white,
        shadowColor: Colors.grey.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const SizedBox(
          height: 150,
          child: Center(child: Text('Satış verisi bulunan ürün yok.')),
        ),
      );
    }

    final sortedDates = filteredRevenueMap.keys.toList();
    int limit = 5;
    
    // Toplam günlük satış hesaplamaları
    double maxDailyProducts = 0;
    
    // Çubuk kalınlığını gün sayısına göre dinamik ayarla
    double barWidth = 16.0;
    if (sortedDates.length > 180) {
      barWidth = 5.0;
    } else if (sortedDates.length > 90) {
      barWidth = 8.0;
    } else if (sortedDates.length > 30) {
      barWidth = 12.0;
    }

    List<BarChartGroupData> barGroups = List.generate(sortedDates.length, (i) {
      final dateStr = sortedDates[i];
      final dailyData = _dailyProductSalesMap[dateStr] ?? {};

      List<BarChartRodStackItem> stackItems = [];
      double currentBottom = 0;
      double otherDailySales = 0;

      for (int j = 0; j < productSummaries.length; j++) {
        final pId = productSummaries[j].id;
        final sales = (dailyData[pId] ?? 0).toDouble();

        if (j < limit) {
          if (sales > 0) {
            stackItems.add(BarChartRodStackItem(currentBottom, currentBottom + sales, _pieChartColors[j]));
            currentBottom += sales;
          }
        } else {
          otherDailySales += sales;
        }
      }

      if (otherDailySales > 0) {
        stackItems.add(BarChartRodStackItem(currentBottom, currentBottom + otherDailySales, _pieChartColors[limit]));
        currentBottom += otherDailySales;
      }
      
      if (currentBottom > maxDailyProducts) {
        maxDailyProducts = currentBottom;
      }

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: currentBottom,
            width: barWidth,
            borderRadius: BorderRadius.circular(4),
            rodStackItems: stackItems.reversed.toList(),
            color: Colors.transparent, // Arka plan
          )
        ],
      );
    });

    double totalSales = productSummaries.fold(0.0, (sum, p) => sum + p.salesQuantity);
    double otherSales = 0;
    List<PieChartSectionData> legendData = [];

    for (int i = 0; i < productSummaries.length; i++) {
        if (i < limit) {
            legendData.add(PieChartSectionData(color: _pieChartColors[i], title: '${(productSummaries[i].salesQuantity / totalSales * 100).toStringAsFixed(0)}%'));
        } else {
            otherSales += productSummaries[i].salesQuantity;
        }
    }
    if (otherSales > 0) {
         legendData.add(PieChartSectionData(color: _pieChartColors[limit], title: '${(otherSales / totalSales * 100).toStringAsFixed(0)}%'));
    }

    return Column(
      children: [
        Card(
          elevation: 4,
          color: Colors.white,
          shadowColor: Colors.grey.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Günlük Ürün Dağılımı', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                // Günlük Stack Adjust Bar Chart
                SizedBox(
                  height: 240,
                  child: sortedDates.isEmpty ? const Center(child: Text('Veri yok')) : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: barGroups,
                      maxY: maxDailyProducts > 0 ? maxDailyProducts * 1.2 : 10,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              NumberFormat.compact(locale: 'tr_TR').format(value),
                              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index < 0 || index >= sortedDates.length) return const SizedBox();
                              
                              int daysToShow = (sortedDates.length ~/ 6).clamp(1, sortedDates.length);
                              if (index % daysToShow == 0 || index == sortedDates.length - 1) {
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 8,
                                  child: Text(
                                    DateFormat('dd/MM').format(DateTime.parse(sortedDates[index])),
                                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF1E293B),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final dateStr = sortedDates[group.x];
                            final total = rod.toY.toInt();
                            
                            List<TextSpan> breakdownSpans = [];
                            final dailyData = _dailyProductSalesMap[dateStr] ?? {};
                            
                            double otherDailySales = 0;
                            
                            for (int j = 0; j < productSummaries.length; j++) {
                               final pId = productSummaries[j].id;
                               final sales = (dailyData[pId] ?? 0).toInt();
                               
                               if (j < limit) {
                                 if (sales > 0) {
                                   final name = productSummaries[j].name;
                                   final color = _pieChartColors[j];
                                   breakdownSpans.add(TextSpan(
                                      text: '• $name: $sales\n',
                                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                                   ));
                                 }
                               } else {
                                 otherDailySales += sales;
                               }
                            }
                            
                            if (otherDailySales > 0) {
                              breakdownSpans.add(TextSpan(
                                  text: '• Diğer: ${otherDailySales.toInt()}\n',
                                  style: TextStyle(color: _pieChartColors[limit], fontSize: 12, fontWeight: FontWeight.bold),
                               ));
                            }
                            
                            return BarTooltipItem(
                              '${DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr))}\n',
                              const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: 'Toplam: $total Ürün\n\n',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                ...breakdownSpans
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Legends
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(legendData.length, (index) {
                    String name = index < limit ? productSummaries[index].name : 'Diğer';
                    String percentage = legendData[index].title;
                    Color color = legendData[index].color;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$name ($percentage)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    );
                  }),
                ),
              ],
            ),
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
        color: Colors.white,
        shadowColor: Colors.grey.withOpacity(0.1),
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
      color: Colors.white,
      shadowColor: Colors.grey.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // "Diğer" ise tıklanabilir olmasın
        onTap: isOtherCard
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ProductDetailAnalyticsScreen(
                    productId: summary.id, 
                    productName: summary.name,
                    startDate: _startDate,
                    endDate: _endDate))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
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
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
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

  Widget _buildTableMetricCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSalesSection(List<TableSaleSummary> summaries) {
    if (summaries.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text('Seçilen aralıkta masa verisi bulunamadı.',
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    // Calculate metrics
    double totalRevenue = summaries.fold(0.0, (sum, s) => sum + s.totalRevenue);
    int totalOrders = summaries.fold(0, (sum, s) => sum + s.orderCount);
    
    var topRevenueMasa = summaries.isEmpty ? null : summaries.reduce((a, b) => a.totalRevenue > b.totalRevenue ? a : b);
    var topOrderMasa = summaries.isEmpty ? null : summaries.reduce((a, b) => a.orderCount > b.orderCount ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlıklar: Sol %60 "Masa Bazlı Satış Dağılımı", Sağ %40 "Masa Bazlı Detaylar" ve "Tümünü Gör"
        Row(
          children: [
            Expanded(
              flex: 60,
              child: Text(
                'Masa Bazlı Satış Dağılımı',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 40,
              child: const Text(
                'Masa Bazlı Detaylar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // İçerik: Sol %60 Grafik, Sağ %40 Liste
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol: Grafik
            Expanded(
              flex: 60,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Card(
                  elevation: 4,
                  color: Colors.white,
                  shadowColor: Colors.grey.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 4, // Biraz arttırıldı
                                  centerSpaceRadius: 120, // Ortası çok daha geniş
                                  sections: List.generate(
                                    summaries.length,
                                    (i) {
                                      final summary = summaries[i];
                                      final isTouched = i == _touchedPieIndex;
                                      final fontSize = isTouched ? 32.0 : 24.0; // Yazı tipleri büyütüldü
                                      final radius = isTouched ? 160.0 : 140.0; // Dilim kalınlıkları 2.5 kat arttırıldı
                                      final percentage = (summary.totalRevenue / (totalRevenue == 0 ? 1 : totalRevenue) * 100);

                                      return PieChartSectionData(
                                        color: _pieChartColors[i % _pieChartColors.length],
                                        value: summary.totalRevenue,
                                        title: '${percentage.toStringAsFixed(1)}%',
                                        radius: radius,
                                        titleStyle: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        badgeWidget: isTouched
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E293B),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    )
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      summary.name,
                                                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                                    ),
                                                    Text(
                                                      NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(summary.totalRevenue),
                                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : null,
                                        badgePositionPercentageOffset: 1.3,
                                      );
                                    },
                                  ),
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedPieIndex = -1;
                                          return;
                                        }
                                        _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺').format(totalRevenue),
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Toplam Ciro',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Sağ: Detay Listesi
            Expanded(
              flex: 40,
              child: AspectRatio(
                aspectRatio: 40 / 60,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    final color = _pieChartColors[index % _pieChartColors.length];
                    return _buildTableSaleCard(summary, color);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableSaleCard(TableSaleSummary summary, [Color? iconColor]) {
    final themeColor = iconColor ?? Colors.blueGrey.shade700;
    
    return Card(
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.grey.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TableDetailReportScreen(
                    summary: summary,
                    startDate: _startDate,
                    endDate: _endDate,
                  )));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.table_restaurant_rounded,
                  color: themeColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${summary.orderCount} Sipariş Kapatıldı',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(summary.totalRevenue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'Toplam Ciro',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class AppleIntelligenceGlowPainter extends CustomPainter {
  final double animationValue;

  AppleIntelligenceGlowPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    // Outer Glow layer
    final glowPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Colors.green.shade200.withOpacity(0.0),
          Colors.green.shade400.withOpacity(0.5),
          Colors.green.shade700.withOpacity(0.8),
          Colors.green.shade400.withOpacity(0.5),
          Colors.green.shade200.withOpacity(0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: GradientRotation(animationValue * math.pi * 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    canvas.drawRRect(rrect, glowPaint);

    // Inner bright flow line
    final accentPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          Colors.transparent,
          Colors.green.shade300.withOpacity(0.2),
          Colors.white.withOpacity(0.9),
          Colors.green.shade300.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
        transform: GradientRotation(animationValue * math.pi * 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(rrect, accentPaint);
    
    // Subtle Pulse
    final pulseValue = (math.sin(animationValue * math.pi * 4) + 1) / 2;
    final pulsePaint = Paint()
      ..color = Colors.green.withOpacity(0.15 * pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0 + (10.0 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      
    canvas.drawRRect(rrect, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant AppleIntelligenceGlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  final bool animate;

  const _TypewriterText(
    this.text, {
    Key? key,
    this.style,
    this.speed = const Duration(milliseconds: 15),
    this.animate = true,
  }) : super(key: key);

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  int _displayedLength = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _startTyping();
    } else {
      _displayedLength = widget.text.length;
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_displayedLength < widget.text.length) {
        setState(() {
          _displayedLength++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      setState(() {
        if (widget.animate) {
          _displayedLength = 0;
          _startTyping();
        } else {
          _displayedLength = widget.text.length;
        }
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Text(
      widget.text.substring(0, _displayedLength),
      style: widget.style,
    );
  }
}
