import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/table_report_provider.dart';
import 'TableDetailReportScreen.dart';

class DetailedTableScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String? initialTableId;

  const DetailedTableScreen({
    super.key,
    required this.startDate,
    required this.endDate,
    this.initialTableId,
  });

  @override
  State<DetailedTableScreen> createState() => _DetailedTableScreenState();
}

class _DetailedTableScreenState extends State<DetailedTableScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedQuickFilter = 'Özel';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      
      // Eğer bir masa ID'si ile gelindiyse, otomatik olarak o masanın detaylarını aç
      if (widget.initialTableId != null) {
        final provider = Provider.of<TableReportProvider>(context, listen: false);
        final initialTable = provider.tableSummaries.firstWhere(
          (s) => s.id == widget.initialTableId,
          orElse: () => provider.tableSummaries.first,
        );
        _showTableDetails(initialTable);
      }
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<TableReportProvider>(context, listen: false);
    await provider.loadTableSalesSummary(
      startDate: _startDate,
      endDate: _endDate,
    );
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
        newStartDate = now.subtract(const Duration(days: 2));
        break;
      case '7 Gün':
        newStartDate = now.subtract(const Duration(days: 6));
        break;
      case '30 Gün':
        newStartDate = now.subtract(const Duration(days: 29));
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
    final provider = Provider.of<TableReportProvider>(context);
    final summaries = provider.tableSummaries.where((s) {
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Masa Satış Analizi',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFilterBar(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 24),
          _buildAggregateStats(provider.tableSummaries),
          const SizedBox(height: 24),
          const Text('Masalar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            const Center(child: Text('Masa bulunamadı.'))
          else
            ...summaries.map((s) => _buildTableCard(s)).toList(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['Bugün', '3 Gün', '7 Gün', '30 Gün'];
    return SingleChildScrollView(
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
                selectedColor: Colors.blueGrey.shade100,
              ),
            );
          }).toList(),
          _buildDateRangeChip(),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final isSelected = _selectedQuickFilter == 'Özel';
    final label = isSelected
        ? '${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)}'
        : 'Tarih Seç';

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _selectDateRange(),
      backgroundColor: Colors.white,
      selectedColor: Colors.blueGrey.shade100,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Masa Ara...',
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildAggregateStats(List<TableSaleSummary> summaries) {
    double totalRevenue = 0;
    int totalOrders = 0;
    int totalSeconds = 0;

    for (var s in summaries) {
      totalRevenue += s.totalRevenue;
      totalOrders += s.orderCount;
      totalSeconds += s.totalDurationSeconds;
    }

    final avgDuration = totalOrders > 0 ? (totalSeconds / totalOrders / 60) : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
              'Toplam Ciro',
              NumberFormat.simpleCurrency(locale: 'tr_TR').format(totalRevenue),
              Icons.payments,
              Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
              'Ort. Süre',
              '${avgDuration.toStringAsFixed(0)} dk',
              Icons.timer,
              Colors.orange),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTableCard(TableSaleSummary summary) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showTableDetails(summary),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blueGrey.shade50,
                child: Icon(Icons.table_restaurant, color: Colors.blueGrey.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${summary.orderCount} Sipariş',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      NumberFormat.simpleCurrency(locale: 'tr_TR')
                          .format(summary.totalRevenue),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'Ort: ${(summary.avgDurationSeconds / 60).toStringAsFixed(0)} dk',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableDetails(TableSaleSummary summary) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TableDetailReportScreen(
          summary: summary,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
  }
}
