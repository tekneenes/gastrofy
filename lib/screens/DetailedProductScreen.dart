import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/product_provider.dart';
// import '../widgets/date_range_picker_button.dart'; // Artık bu butona ihtiyaç yok
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
    const Color(0xFF9B59B6),
    Colors.grey.shade500,
  ];

  // Hızlı tarih seçim butonları için
  String _selectedQuickFilter = 'Özel';

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    await provider.loadProductSalesSummary(
      startDate: _startDate,
      endDate: _endDate,
    );

    _generateDailyTrendData();
    _generateProductTrendData();
  }

  void _generateDailyTrendData() {
    setState(() {
      _dailyTrend.clear();
      final days = _endDate.difference(_startDate).inDays;
      if (days >= 0) {
        for (int i = 0; i <= days; i++) {
          final date = _startDate.add(Duration(days: i));
          // Mock veri oluşturma (Gerçek verinizle değiştirin)
          _dailyTrend[date] = 20 + (i % 5) * 8 + ((i * 3) % 9);
        }
      }
    });
  }

  void _generateProductTrendData() {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final salesSummary = provider.filteredSalesSummary;

    setState(() {
      _productTrendData.clear();

      for (var summary in salesSummary) {
        // Her ürün için son 14 günlük veri oluştur
        final spots = <FlSpot>[];
        final baseValue = summary.salesQuantity / 14;

        // Geçen hafta (ilk 7 gün) ve bu hafta (son 7 gün) verilerini oluştur
        double lastWeekAvg = 0;
        double thisWeekAvg = 0;

        for (int i = 0; i < 14; i++) {
          // Rastgele ama gerçekçi veri oluştur
          final variance = (summary.id.hashCode % 10) / 10;
          final trend = (summary.id.hashCode % 3) - 1; // -1, 0, 1
          final noise = ((i * summary.id.hashCode) % 5) / 5;

          double value = baseValue + (baseValue * variance * noise);

          // Trend uygula
          if (trend > 0) {
            value += (i / 14) * baseValue * 0.5; // Artış trendi
          } else if (trend < 0) {
            value -= (i / 14) * baseValue * 0.3; // Azalış trendi
          }

          value = value.clamp(1, double.infinity);
          spots.add(FlSpot(i.toDouble(), value));

          // Haftalık ortalamaları hesapla
          if (i < 7) {
            lastWeekAvg += value;
          } else {
            thisWeekAvg += value;
          }
        }

        lastWeekAvg /= 7;
        thisWeekAvg /= 7;

        // Trend belirleme
        final changePercentage = lastWeekAvg > 0
            ? ((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100
            : 0.0;

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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Ürün Satış Analizi',
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // GÜNCELLENDİ: Hızlı tarih filtreleri ve özel tarih seçici birleşti
          _buildFilterBar(),
          const SizedBox(height: 24),

          // GÜNCELLENDİ: Gereksiz Card ve SizedBox kaldırıldı

          if (dailyTrend.isNotEmpty) ...[
            _buildSectionHeader('Genel Satış Trendi'),
            const SizedBox(height: 12),
            _buildSalesLineChart(dailyTrend),
            const SizedBox(height: 24),
          ],

          if (salesSummary.isNotEmpty) ...[
            _buildSectionHeader('Satış Adetlerine Göre Dağılım'),
            const SizedBox(height: 12),
            _buildPieChart(salesSummary),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader('Ürün Performansları'),
          const SizedBox(height: 12),

          if (salesSummary.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Veri Bulunamadı',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seçilen tarih aralığı için satış verisi bulunamadı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...salesSummary
                .map((summary) => _buildProductCard(summary, productProvider))
                .toList(),
        ],
      ),
    );
  }

  // GÜNCELLENDİ: Artık hızlı filtreleri ve özel tarih seçici çipi bir arada tutuyor
  Widget _buildFilterBar() {
    final filters = ['Bugün', '3 Gün', '7 Gün', '30 Gün', '60 Gün'];

    return SizedBox(
      height: 45,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...filters.map((filter) {
              final isSelected = _selectedQuickFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => _selectQuickFilter(filter),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.deepPurple.shade100,
                  checkmarkColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.deepPurple.shade700
                        : Colors.grey.shade700,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  elevation: isSelected ? 4 : 2,
                  shadowColor: Colors.deepPurple.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }).toList(),
            // YENİ: Özel tarih seçici çip
            _buildDateRangeChip(),
          ],
        ),
      ),
    );
  }

  // YENİ: ReportScreen'deki stile uygun özel tarih seçici çip
  Widget _buildDateRangeChip() {
    final isSelected = _selectedQuickFilter == 'Özel';
    String label;
    if (isSelected) {
      label =
          '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)}';
    } else {
      label = 'Tarih Seç';
    }

    return FilterChip(
      label: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 18,
            color:
                isSelected ? Colors.deepPurple.shade700 : Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _selectDateRange(),
      backgroundColor: Colors.white,
      selectedColor: Colors.deepPurple.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.deepPurple.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      elevation: isSelected ? 4 : 2,
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
    );
  }

  Widget _buildSalesLineChart(Map<DateTime, int> dailyTrend) {
    final spots = dailyTrend.entries
        .map((e) =>
            FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value.toDouble()))
        .toList();
    final maxValue = dailyTrend.values.fold(0, (max, v) => v > max ? v : max);

    return Card(
      elevation: 4,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: (maxValue / 4).ceilToDouble())),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: Duration(
                            days: ((_endDate.difference(_startDate).inDays / 5)
                                    .clamp(1, 1000)) // 5 etikete böl
                                .round())
                        .inMilliseconds
                        .toDouble(),
                    getTitlesWidget: (value, meta) => Text(
                        DateFormat('dd\nMMM').format(
                            DateTime.fromMillisecondsSinceEpoch(value.toInt())),
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: LinearGradient(colors: [
                    Colors.deepPurple.shade400,
                    Colors.teal.shade400
                  ]),
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
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(List<ProductSaleSummary> salesSummary) {
    final totalQuantity =
        salesSummary.fold(0.0, (sum, item) => sum + item.salesQuantity);
    final topItems = salesSummary.take(5).toList();
    if (salesSummary.length > 5) {
      final otherItemsQuantity = salesSummary
          .skip(5)
          .fold(0.0, (sum, item) => sum + item.salesQuantity)
          .toInt();
      topItems.add(ProductSaleSummary(
          id: 'other', name: 'Diğer', salesQuantity: otherItemsQuantity));
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.teal.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, pieTouchResponse) {
                        setState(() {
                          _touchedIndex = pieTouchResponse
                                  ?.touchedSection?.touchedSectionIndex ??
                              -1;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: topItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final isTouched = index == _touchedIndex;
                      final percentage = totalQuantity > 0
                          ? (data.salesQuantity / totalQuantity * 100)
                          : 0.0;
                      return PieChartSectionData(
                        color: _pieChartColors[index % _pieChartColors.length],
                        value: data.salesQuantity.toDouble(),
                        title: '${percentage.toStringAsFixed(0)}%',
                        radius: isTouched ? 65 : 55,
                        titleStyle: TextStyle(
                            fontSize: isTouched ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: topItems.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _pieChartColors[
                                  entry.key % _pieChartColors.length],
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${entry.value.name} (${entry.value.salesQuantity})',
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
      ProductSaleSummary summary, ProductProvider provider) {
    final trendData = _productTrendData[summary.id];

    if (trendData == null) {
      return const SizedBox.shrink();
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

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ProductDetailAnalyticsScreen(
                productId: summary.id, productName: summary.name))),
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
                          minY: trendData.spots
                                  .map((e) => e.y)
                                  .reduce((a, b) => a < b ? a : b) *
                              0.9,
                          maxY: trendData.spots
                                  .map((e) => e.y)
                                  .reduce((a, b) => a > b ? a : b) *
                              1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
