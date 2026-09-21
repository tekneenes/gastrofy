import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/product_provider.dart';
import '../providers/daily_revenue_provider.dart';
import '../models/daily_revenue_model.dart';
import 'product_detail_analytics_screen.dart';

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

class DetailedProductScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DetailedProductScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<DetailedProductScreen> createState() => _DetailedProductScreenState();
}

class _DetailedProductScreenState extends State<DetailedProductScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  int _touchedIndex = -1;

  Map<DateTime, int> _dailyTrend = {};
  Map<String, ProductTrendData> _productTrendData = {};

  final List<Color> _pieChartColors = [
    const Color(0xFF3498DB),
    const Color(0xFF1ABC9C),
    const Color(0xFFE74C3C),
    const Color(0xFFF39C12),
    const Color(0xFF16A085),
    Colors.grey.shade500,
  ];

  // Hızlı tarih seçim butonları için
  String _selectedQuickFilter = 'Özel';

  // 🔍 Arama ve Sıralama
  String _searchQuery = '';
  String _sortOption = 'quantity_desc'; // quantity_desc, quantity_asc, name_asc, name_desc
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final dailyRevenueProvider = Provider.of<DailyRevenueProvider>(context, listen: false);

    await Future.wait([
      productProvider.loadProductSalesSummary(
        startDate: _startDate,
        endDate: _endDate,
      ),
      dailyRevenueProvider.loadDailyRevenues(
        startDate: _startDate,
        endDate: _endDate,
      ),
    ]);

    _generateDailyTrendData();
    _generateProductTrendData();
  }

  void _generateDailyTrendData() {
    final dailyRevenueProvider = Provider.of<DailyRevenueProvider>(context, listen: false);
    final revenues = dailyRevenueProvider.dailyRevenues;

    // Hızlı erişim için Map oluştur
    final Map<String, DailyRevenue> revenueMap = {
      for (var rev in revenues) rev.date: rev
    };


    setState(() {
      _dailyTrend.clear();
      final totalDays = _endDate.difference(_startDate).inDays;

      for (int i = 0; i <= totalDays; i++) {
        final currentDate = _startDate.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(currentDate);

        final dailyData = revenueMap[dateString];

        int totalSalesCount = 0;
        if (dailyData != null) {
          dailyData.soldProducts.forEach((_, count) => totalSalesCount += count.toInt());
        }

        _dailyTrend[currentDate] = totalSalesCount;
      }
    });
  }

  void _generateProductTrendData() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final dailyRevenueProvider = Provider.of<DailyRevenueProvider>(context, listen: false);

    final salesSummary = productProvider.filteredSalesSummary;
    final allDailyRevenues = dailyRevenueProvider.dailyRevenues;

    final Map<String, DailyRevenue> dailyRevenueMap = {
      for (var rev in allDailyRevenues) rev.date: rev
    };

    final totalDays = _endDate.difference(_startDate).inDays;
    final midPointDays = totalDays / 2.0;

    setState(() {
      _productTrendData.clear();

      for (var summary in salesSummary) {
        final spots = <FlSpot>[];
        double prevHalfSales = 0;
        double currHalfSales = 0;

        for (int d = 0; d <= totalDays; d++) {
          final currentDate = _startDate.add(Duration(days: d));
          final dateString = DateFormat('yyyy-MM-dd').format(currentDate);

          final dailyRevenue = dailyRevenueMap[dateString];
          final sales = dailyRevenue?.soldProducts[summary.name]?.toDouble() ?? 0.0;

          spots.add(FlSpot(d.toDouble(), sales));

          if (d < midPointDays) {
            prevHalfSales += sales;
          } else {
            currHalfSales += sales;
          }
        }

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

        _productTrendData[summary.id] = ProductTrendData(
          spots: spots,
          trend: trend,
          changePercentage: changePercentage,
        );
      }
    });
  }

  void _updateDateRange(DateTime newStartDate, DateTime newEndDate) {
    if (_startDate != newStartDate || _endDate != newEndDate) {
      setState(() {
        _startDate = newStartDate;
        _endDate = newEndDate;
        _selectedQuickFilter = 'Özel';
      });
      _loadData();
    }
  }

  // YENİ: Özel tarih aralığı seçiciyi açan fonksiyon
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
      _updateDateRange(picked.start, picked.end);
    }
  }

  void _selectQuickFilter(String filter) {
    final now = DateTime.now();
    DateTime newStartDate;
    DateTime newEndDate = now;

    switch (filter) {
      case 'Bugün':
        newStartDate = DateTime(now.year, now.month, now.day);
        break;
      case '3 Gün':
        newStartDate =
            now.subtract(const Duration(days: 2)); // 3 gün önceyi kapsar
        break;
      case '7 Gün':
        newStartDate =
            now.subtract(const Duration(days: 6)); // 7 gün önceyi kapsar
        break;
      case '30 Gün':
        newStartDate =
            now.subtract(const Duration(days: 29)); // 30 gün önceyi kapsar
        break;
      case '60 Gün':
        newStartDate =
            now.subtract(const Duration(days: 59)); // 60 gün önceyi kapsar
        break;
      default:
        return;
    }

    setState(() {
      _selectedQuickFilter = filter;
      _startDate = newStartDate;
      _endDate = newEndDate;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final salesSummary = productProvider.filteredSalesSummary;
    final dailyTrend = _dailyTrend;

    // 🔍 Filtreleme ve Sıralama Mantığı
    List<ProductSaleSummary> filteredList = salesSummary.where((s) {
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (_sortOption == 'quantity_desc') {
      filteredList.sort((a, b) => b.salesQuantity.compareTo(a.salesQuantity));
    } else if (_sortOption == 'quantity_asc') {
      filteredList.sort((a, b) => a.salesQuantity.compareTo(b.salesQuantity));
    } else if (_sortOption == 'name_asc') {
      filteredList.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortOption == 'name_desc') {
      filteredList.sort((a, b) => b.name.compareTo(a.name));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Ürün Satış Analizi',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildFilterBar(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 24),

          if (dailyTrend.isNotEmpty && _searchQuery.isEmpty) ...[
            const Text('Genel Satış Trendi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildSalesLineChart(dailyTrend),
            const SizedBox(height: 24),
          ],

          const Text('Ürün Dağılımı ve Performansı',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          if (salesSummary.isNotEmpty) 
            _buildDistributionAndList(filteredList, salesSummary),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Ürün Ara...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1ABC9C)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildSortDropdown(),
      ],
    );
  }

  Widget _buildFilterBar() {
    final filters = ['Bugün', '3 Gün', '7 Gün', '30 Gün', '60 Gün'];
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length + 1,
        itemBuilder: (context, index) {
          if (index == filters.length) return _buildDateRangeChip();
          final filter = filters[index];
          final isSelected = _selectedQuickFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) => _selectQuickFilter(filter),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1ABC9C),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: isSelected ? const Color(0xFF1ABC9C) : Colors.grey.shade200),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final isSelected = _selectedQuickFilter == 'Özel';
    String label = isSelected 
        ? '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)}'
        : 'Tarih Seç';

    return ActionChip(
      avatar: Icon(Icons.calendar_month, size: 18, color: isSelected ? Colors.white : Colors.grey.shade700),
      label: Text(label),
      onPressed: _selectDateRange,
      backgroundColor: isSelected ? const Color(0xFF1ABC9C) : Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: isSelected ? const Color(0xFF1ABC9C) : Colors.grey.shade200),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortOption,
          icon: const Icon(Icons.sort, size: 20, color: Color(0xFF1ABC9C)),
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13, fontWeight: FontWeight.bold),
          onChanged: (String? newValue) {
            if (newValue != null) setState(() => _sortOption = newValue);
          },
          items: const [
            DropdownMenuItem(value: 'quantity_desc', child: Text('En Çok')),
            DropdownMenuItem(value: 'quantity_asc', child: Text('En Az')),
            DropdownMenuItem(value: 'name_asc', child: Text('A-Z')),
            DropdownMenuItem(value: 'name_desc', child: Text('Z-A')),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesLineChart(Map<DateTime, int> dailyTrend) {
    if (dailyTrend.isEmpty) return const SizedBox.shrink();

    final entries = dailyTrend.entries.toList();
    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
    }).toList();
    
    final maxValue = dailyTrend.values.fold(0, (max, v) => v > max ? v : max);
    double minY = 0;
    double maxY = (maxValue == 0 ? 10 : maxValue * 1.2).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          minX: 0,
          maxX: spots.isEmpty ? 1.0 : (spots.length == 1 ? 1.0 : (spots.length - 1).toDouble()),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = entries[spot.x.toInt()].key;
                  return LineTooltipItem(
                    '${DateFormat('dd MMM', 'tr_TR').format(date)}\n',
                    const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '${spot.y.toInt()} Adet',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: spots.isEmpty ? 1 : (spots.length / 5).ceil().toDouble().clamp(1.0, 1000.0),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < entries.length) {
                    final date = entries[index].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('dd MMM', 'tr_TR').format(date), style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF1ABC9C),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(colors: [const Color(0xFF1ABC9C).withOpacity(0.2), const Color(0xFF1ABC9C).withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionAndList(List<ProductSaleSummary> filteredList, List<ProductSaleSummary> allSummary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 60,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: _buildPieChart(allSummary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 40,
          child: AspectRatio(
            aspectRatio: 40 / 100,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final summary = filteredList[index];
                final color = _pieChartColors[index % _pieChartColors.length];
                return _buildProductListItem(summary, color);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductListItem(ProductSaleSummary summary, Color color) {
    final trendData = _productTrendData[summary.id];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProductDetailAnalyticsScreen(
                productId: summary.id, 
                productName: summary.name,
                startDate: _startDate,
                endDate: _endDate))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2_outlined, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${summary.salesQuantity} ADET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                  if (trendData != null) _buildTrendBadge(trendData),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTrendColor(Trend trend) {
    switch (trend) {
      case Trend.up: return Colors.green.shade600;
      case Trend.down: return Colors.red.shade600;
      case Trend.same: return Colors.grey.shade600;
    }
  }

  Widget _buildTrendBadge(ProductTrendData trendData) {
    final color = _getTrendColor(trendData.trend);
    final icon = trendData.trend == Trend.up ? Icons.trending_up : (trendData.trend == Trend.down ? Icons.trending_down : Icons.trending_flat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 2),
          Text('${trendData.changePercentage.abs().toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<ProductSaleSummary> salesSummary) {
    final totalQuantity = salesSummary.fold(0.0, (sum, item) => sum + item.salesQuantity);
    final topItems = salesSummary.take(8).toList();
    if (salesSummary.length > 8) {
      final otherQty = salesSummary.skip(8).fold(0.0, (sum, item) => sum + item.salesQuantity).toInt();
      topItems.add(ProductSaleSummary(id: 'other', name: 'Diğer', salesQuantity: otherQty));
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 45,
              sections: List.generate(
                topItems.length,
                (i) {
                  final data = topItems[i];
                  final isTouched = i == _touchedIndex;
                  final percentage = totalQuantity > 0 ? (data.salesQuantity / totalQuantity * 100) : 0.0;
                  return PieChartSectionData(
                    color: _pieChartColors[i % _pieChartColors.length],
                    value: data.salesQuantity.toDouble(),
                    title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
                    radius: isTouched ? 65 : 55,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                },
              ),
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
          if (_touchedIndex != -1 && _touchedIndex < topItems.length)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(topItems[_touchedIndex].name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600), textAlign: TextAlign.center),
                Text('${topItems[_touchedIndex].salesQuantity}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TOPLAM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1)),
                Text('${totalQuantity.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              ],
            ),
        ],
      ),
    );
  }
}
