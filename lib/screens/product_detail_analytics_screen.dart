import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/product_report_provider.dart';

class ProductDetailAnalyticsScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final DateTime startDate;
  final DateTime endDate;

  const ProductDetailAnalyticsScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<ProductDetailAnalyticsScreen> createState() => _ProductDetailAnalyticsScreenState();
}

class _ProductDetailAnalyticsScreenState extends State<ProductDetailAnalyticsScreen> {
  int _touchedPieIndex = -1;

  final List<Color> _pieChartColors = [
    const Color(0xFF3498DB),
    const Color(0xFF1ABC9C),
    const Color(0xFF9B59B6),
    const Color(0xFFE67E22),
    const Color(0xFFE74C3C),
    const Color(0xFFF39C12),
    const Color(0xFF16A085),
    const Color(0xFF2ECC71),
    Colors.grey.shade500,
  ];

  Future<void>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = Provider.of<ProductReportProvider>(context, listen: false)
        .loadDetailedProductReport(
      productId: widget.productId,
      productName: widget.productName,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(widget.productName,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
                fontSize: 24)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                '${DateFormat('dd MMM').format(widget.startDate)} - ${DateFormat('dd MMM').format(widget.endDate)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
        toolbarHeight: 70,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _reportFuture ??= Provider.of<ProductReportProvider>(context, listen: false)
            .loadDetailedProductReport(
          productId: widget.productId,
          productName: widget.productName,
          startDate: widget.startDate,
          endDate: widget.endDate,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final provider = Provider.of<ProductReportProvider>(context);
          final analysis = provider.currentProductAnalysis;

          if (analysis == null) {
            return const Center(child: Text('Veri bulunamadı'));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              _buildMetricGrid(analysis),
              const SizedBox(height: 24),
              const Text('Saatlik Satış Yoğunluğu',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildHourlyChart(analysis.hourlyDistribution),
              const SizedBox(height: 24),
              const Text('Masa Bazlı Dağılım',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTableDistributionList(analysis.tableDistribution),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricGrid(ProductDetailAnalysis analysis) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.0,
      children: [
        _buildMiniStat('Toplam Adet', analysis.totalQuantity.toString(), Colors.blue),
        _buildMiniStat('Toplam Ciro',
            '${NumberFormat('#,##0.00', 'tr_TR').format(analysis.totalRevenue)} ₺',
            Colors.purple),
        _buildMiniStat('En Yoğun Saat Aralığı', 
            '${analysis.peakHour.toString().padLeft(2, '0')}:00 - ${(analysis.peakHour + 1 == 24 ? 0 : analysis.peakHour + 1).toString().padLeft(2, '0')}:00', 
            Colors.red),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label.toUpperCase(), 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(List<int> distribution) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 23,
          minY: 0,
          maxY: () {
            double m = 0;
            for (var val in distribution) {
              if (val > m) m = val.toDouble();
            }
            return m == 0 ? 10.0 : m * 1.2;
          }(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 4 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10)),
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
              spots: distribution.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.toDouble());
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.4,
              color: const Color(0xFF3498DB),
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3498DB).withOpacity(0.4),
                    const Color(0xFF3498DB).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableDistributionList(Map<String, int> distribution) {
    if (distribution.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Veri bulunamadı'),
        ),
      );
    }

    final totalQuantity = distribution.values.fold(0, (sum, q) => sum + q);
    final sortedItems = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                        sections: List.generate(
                          sortedItems.length,
                          (i) {
                            final entry = sortedItems[i];
                            final isTouched = i == _touchedPieIndex;
                            final fontSize = isTouched ? 24.0 : 18.0;
                            final radius = isTouched ? 60.0 : 50.0;
                            final percentage = (entry.value / (totalQuantity == 0 ? 1 : totalQuantity) * 100);

                            return PieChartSectionData(
                              color: _pieChartColors[i % _pieChartColors.length],
                              value: entry.value.toDouble(),
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
                                            entry.key,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${entry.value} Adet',
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
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
                          '$totalQuantity',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toplam',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Sağ: Liste
        Expanded(
          flex: 40,
          child: AspectRatio(
            aspectRatio: 40 / 60,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                final entry = sortedItems[index];
                final color = _pieChartColors[index % _pieChartColors.length];
                return _buildTableListItem(entry.key, entry.value, color);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableListItem(String name, int quantity, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(Icons.table_restaurant_outlined, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                'ADET',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
