import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/daily_revenue_provider.dart';
import '../models/daily_revenue_model.dart';
import '../widgets/date_range_picker_button.dart';

class DetailedRevenueScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DetailedRevenueScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<DetailedRevenueScreen> createState() => _DetailedRevenueScreenState();
}

class _DetailedRevenueScreenState extends State<DetailedRevenueScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    _startDate = widget.startDate;
    _endDate = widget.endDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Provider.of<DailyRevenueProvider>(context, listen: false)
        .loadDailyRevenues(startDate: _startDate, endDate: _endDate);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateDateRange(DateTime newStartDate, DateTime newEndDate) {
    if (_startDate != newStartDate || _endDate != newEndDate) {
      setState(() {
        _startDate = newStartDate;
        _endDate = newEndDate;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyRevenueProvider = Provider.of<DailyRevenueProvider>(context);
    final revenues = dailyRevenueProvider.dailyRevenues;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Detaylı Ciro Analizi',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 4,
                  shadowColor: Colors.deepPurple.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: DateRangePickerButton(
                      startDate: _startDate,
                      endDate: _endDate,
                      onDateRangeSelected: _updateDateRange,
                      title: 'Rapor Tarih Aralığı',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSummaryCards(revenues),
                const SizedBox(height: 24),
                _buildSectionHeader('Günlük Ciro Dağılımı'),
                const SizedBox(height: 12),
                _buildLineChartCard(revenues),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
    );
  }

  Widget _buildSummaryCards(List<DailyRevenue> revenues) {
    if (revenues.isEmpty) return const SizedBox.shrink();

    final totalRevenue = revenues.fold(0.0, (sum, item) => sum + item.revenue);
    final averageRevenue = totalRevenue / revenues.length;
    final maxRevenue = revenues.fold(
        0.0, (max, item) => item.revenue > max ? item.revenue : max);
    final minRevenue = revenues.fold(double.infinity,
        (min, item) => item.revenue < min ? item.revenue : min);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard('Toplam Ciro', totalRevenue,
            Icons.account_balance_wallet_outlined, Colors.deepPurple),
        _buildSummaryCard('Ortalama Ciro', averageRevenue,
            Icons.multiline_chart_outlined, Colors.teal),
        _buildSummaryCard('En Yüksek Gün', maxRevenue,
            Icons.arrow_upward_rounded, Colors.green),
        _buildSummaryCard('En Düşük Gün', minRevenue,
            Icons.arrow_downward_rounded, Colors.red),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, double value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(value),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartCard(List<DailyRevenue> revenues) {
    return Card(
      elevation: 4,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: revenues.isEmpty
            ? const SizedBox(
                height: 250,
                child: Center(child: Text('Seçilen aralıkta veri yok.')),
              )
            : SizedBox(
                height: 250,
                child: _buildLineChart(revenues),
              ),
      ),
    );
  }

  Widget _buildLineChart(List<DailyRevenue> revenues) {
    final spots = List<FlSpot>.generate(
      revenues.length,
      (i) => FlSpot(i.toDouble(), revenues[i].revenue),
    );
    final maxY =
        revenues.map((e) => e.revenue).fold(0.0, (max, v) => v > max ? v : max);

    return LineChart(
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                  NumberFormat.compact(locale: 'tr_TR').format(value),
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: revenues.length > 7
                  ? (revenues.length / 7).ceilToDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= revenues.length)
                  return const SizedBox();
                final date = DateTime.parse(revenues[index].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('dd\nMMM').format(date),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.teal.shade400]),
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
}
