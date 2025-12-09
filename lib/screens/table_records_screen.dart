import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../services/database_helper.dart';
import '../models/table_record_model.dart';

class TableRecordsScreen extends StatefulWidget {
  const TableRecordsScreen({super.key});

  @override
  State<TableRecordsScreen> createState() => _TableRecordsScreenState();
}

class _TableRecordsScreenState extends State<TableRecordsScreen> {
  List<TableRecordModel> _allRecords = [];
  List<TableRecordModel> _filteredRecords = [];
  Map<String, List<TableRecordModel>> _groupedRecords = {};

  bool _isLoading = true;
  bool _isFilterApplied = false;
  bool _isFilterPanelVisible = false;

  String? _selectedTableFilter;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  TimeOfDay? _filterStartTime;
  TimeOfDay? _filterEndTime;
  int _noteFilterIndex = 0;

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _minDurationController = TextEditingController();
  final TextEditingController _maxDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) {
      _fetchRecords();
    });
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final rawMaps =
          await DatabaseHelper.instance.getClosedOrdersLastSixMonths();
      _allRecords =
          rawMaps.map((map) => TableRecordModel.fromSqliteMap(map)).toList();
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıtlar yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    final minPriceFilter = double.tryParse(_minPriceController.text);
    final maxPriceFilter = double.tryParse(_maxPriceController.text);
    final minDurationFilter = int.tryParse(_minDurationController.text);
    final maxDurationFilter = int.tryParse(_maxDurationController.text);

    List<TableRecordModel> results = _allRecords.where((record) {
      final dateMatch = (_filterStartDate == null ||
              !record.startTime.isBefore(_filterStartDate!)) &&
          (_filterEndDate == null ||
              !record.startTime
                  .isAfter(_filterEndDate!.add(const Duration(days: 1))));
      final tableMatch = _selectedTableFilter == null ||
          record.tableName == _selectedTableFilter;
      final priceMatch =
          (minPriceFilter == null || record.totalPrice >= minPriceFilter) &&
              (maxPriceFilter == null || record.totalPrice <= maxPriceFilter);
      bool noteMatch = true;
      if (_noteFilterIndex == 1) {
        noteMatch = record.note != null && record.note!.isNotEmpty;
      } else if (_noteFilterIndex == 2) {
        noteMatch = record.note == null || record.note!.isEmpty;
      }
      bool timeMatch = true;
      if (_filterStartTime != null || _filterEndTime != null) {
        final recordTimeInMinutes =
            record.startTime.hour * 60 + record.startTime.minute;
        final startMinutes = _filterStartTime != null
            ? _filterStartTime!.hour * 60 + _filterStartTime!.minute
            : 0;
        final endMinutes = _filterEndTime != null
            ? _filterEndTime!.hour * 60 + _filterEndTime!.minute
            : 1439;
        timeMatch = recordTimeInMinutes >= startMinutes &&
            recordTimeInMinutes <= endMinutes;
      }
      final durationMatch = (minDurationFilter == null ||
              record.duration.inMinutes >= minDurationFilter) &&
          (maxDurationFilter == null ||
              record.duration.inMinutes <= maxDurationFilter);
      return dateMatch &&
          tableMatch &&
          priceMatch &&
          noteMatch &&
          timeMatch &&
          durationMatch;
    }).toList();

    results.sort((a, b) => b.startTime.compareTo(a.startTime));

    final Map<String, List<TableRecordModel>> grouped = {};
    for (var record in results) {
      final monthKey =
          DateFormat('MMMM yyyy', 'tr_TR').format(record.startTime);
      if (grouped[monthKey] == null) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(record);
    }

    final isAnyFilterApplied = _filterStartDate != null ||
        _filterEndDate != null ||
        _selectedTableFilter != null ||
        minPriceFilter != null ||
        maxPriceFilter != null ||
        _noteFilterIndex != 0 ||
        _filterStartTime != null ||
        _filterEndTime != null ||
        minDurationFilter != null ||
        maxDurationFilter != null;

    setState(() {
      _filteredRecords = results;
      _groupedRecords = grouped;
      _isFilterApplied = isAnyFilterApplied;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedTableFilter = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _filterStartTime = null;
      _filterEndTime = null;
      _noteFilterIndex = 0;
      _minPriceController.clear();
      _maxPriceController.clear();
      _minDurationController.clear();
      _maxDurationController.clear();
    });
    _applyFilters();
  }

  // Kaydı silmek için metod
  Future<void> _deleteRecord(TableRecordModel record) async {
    try {
      await DatabaseHelper.instance.deleteClosedOrder(record.id);

      setState(() {
        _allRecords.removeWhere((r) => r.id == record.id);
      });
      _applyFilters(); // Listeyi ve grupları yeniden oluştur

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${record.tableName} kaydı başarıyla silindi.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt silinirken bir hata oluştu: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        // Hata durumunda listeyi sunucuyla tekrar eşitle
        _fetchRecords();
      }
    }
  }

  // Silme onayı dialog'u
  Future<bool?> _showDeleteConfirmationDialog(TableRecordModel record) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Kaydı Silmeyi Onayla'),
          content: Text(
              '\'${record.tableName}\' masasının ${_formatDateTime(record.startTime)} tarihli kaydını kalıcı olarak silmek istiyor musunuz?\n\nBu işlem geri alınamaz.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> listItems = [];
    _groupedRecords.forEach((month, records) {
      listItems.add(month);
      listItems.addAll(records);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Masa Kayıt Geçmişi',
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
          _buildAppBarAction(
            _isFilterPanelVisible
                ? Icons.filter_alt_off_outlined
                : Icons.filter_alt_outlined,
            'Filtrele',
            _isFilterApplied
                ? Colors.teal.shade600
                : Colors.deepPurple.shade600,
            () =>
                setState(() => _isFilterPanelVisible = !_isFilterPanelVisible),
          ),
          // OTOMATİK RAPOR AYARLARI BUTONU KALDIRILDI
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _isFilterPanelVisible
                      ? _buildFilterPanel()
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: listItems.length,
                          itemBuilder: (context, index) {
                            final item = listItems[index];
                            if (item is String) {
                              return _buildMonthHeader(item);
                            } else if (item is TableRecordModel) {
                              return _buildRecordCard(item);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthHeader(String monthTitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              monthTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
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
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 4,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSectionTitle('Tarih & Saat Aralığı'),
            Row(children: [
              Expanded(
                  child: _buildDateTimePicker(isDate: true, isStart: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildDateTimePicker(isDate: true, isStart: false)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _buildDateTimePicker(isDate: false, isStart: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildDateTimePicker(isDate: false, isStart: false)),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSectionTitle('Fiyat Aralığı (₺)'),
                    _buildMinMaxTextFields(
                        _minPriceController, _maxPriceController, "Min", "Max"),
                    const SizedBox(height: 16),
                    _buildFilterSectionTitle('Oturum Süresi (dk)'),
                    _buildMinMaxTextFields(_minDurationController,
                        _maxDurationController, "Min", "Max"),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSectionTitle('Masa'),
                    _buildTableDropdown(),
                    const SizedBox(height: 16),
                    _buildFilterSectionTitle('Not Durumu'),
                    _buildNoteToggleButtons(),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 20),
                label: const Text('Temizle'),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  _applyFilters();
                  setState(() => _isFilterPanelVisible = false);
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Filtrele'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
    );
  }

  Widget _buildDateTimePicker({required bool isDate, required bool isStart}) {
    final String text = isDate
        ? (isStart ? _filterStartDate : _filterEndDate)
                ?.toIso8601String()
                .substring(0, 10) ??
            (isStart ? 'Başlangıç Tarihi' : 'Bitiş Tarihi')
        : (isStart ? _filterStartTime : _filterEndTime)?.format(context) ??
            (isStart ? 'Başlangıç Saati' : 'Bitiş Saati');

    return OutlinedButton.icon(
      onPressed: () => isDate
          ? _selectDate(context, isStart: isStart)
          : _selectTime(context, isStart: isStart),
      icon: Icon(isDate ? Icons.calendar_today_outlined : Icons.access_time,
          size: 18),
      label: Text(text, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade800,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      ),
    );
  }

  Widget _buildMinMaxTextFields(TextEditingController min,
      TextEditingController max, String minHint, String maxHint) {
    return Row(
      children: [
        Expanded(child: _buildTextField(min, minHint)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextField(max, maxHint)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTableDropdown() {
    final List<String> availableTables =
        _allRecords.map((e) => e.tableName).toSet().toList()..sort();
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      value: _selectedTableFilter,
      hint: const Text('Tüm Masalar'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Tüm Masalar')),
        ...availableTables
            .map((table) => DropdownMenuItem(value: table, child: Text(table))),
      ],
      onChanged: (value) => setState(() => _selectedTableFilter = value),
    );
  }

  Widget _buildNoteToggleButtons() {
    return ToggleButtons(
      isSelected: [
        _noteFilterIndex == 0,
        _noteFilterIndex == 1,
        _noteFilterIndex == 2
      ],
      onPressed: (index) => setState(() => _noteFilterIndex = index),
      borderRadius: BorderRadius.circular(12),
      selectedColor: Colors.white,
      fillColor: Colors.deepPurple.shade400,
      color: Colors.deepPurple.shade400,
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 60.0),
      children: const [
        Text('Tümü'),
        Icon(Icons.note_alt_outlined),
        Icon(Icons.speaker_notes_off_outlined)
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 96,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isFilterApplied
                ? 'Filtreye Uyan Kayıt Yok'
                : 'Kayıt Bulunmamaktadır',
            style: TextStyle(
                fontSize: 24,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _isFilterApplied
                ? 'Farklı bir filtreleme yapmayı deneyin.'
                : 'Kapatılmış masa kayıtları burada listelenir.',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(TableRecordModel record) {
    const color = Colors.deepPurple;
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmationDialog(record);
      },
      onDismissed: (direction) {
        _deleteRecord(record);
      },
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SİL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 12),
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
      child: Card(
        elevation: 4,
        shadowColor: color.withOpacity(0.2),
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showRecordDetails(record),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, color.withOpacity(0.05)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(left: BorderSide(color: color.shade300, width: 6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      record.tableName.split(" ").last,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.tableName,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color.shade900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(record.startTime),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (record.note != null && record.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.notes_rounded,
                                size: 14, color: Colors.orange.shade800),
                            const SizedBox(width: 4),
                            Text(
                              'Not Mevcut',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                          .format(record.totalPrice),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.duration.inMinutes} dk',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          (isStart ? _filterStartDate : _filterEndDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _filterStartDate = picked;
        } else {
          _filterEndDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context,
      {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _filterStartTime : _filterEndTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _filterStartTime = picked;
        } else {
          _filterEndTime = picked;
        }
      });
    }
  }

  void _showRecordDetails(TableRecordModel record) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28)),
                    ),
                    child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        children: [
                          Center(
                            child: Container(
                                width: 50,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(3))),
                          ),
                          Text(record.tableName,
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 8),
                          Text(_formatDateTime(record.startTime),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                          const Divider(height: 30),
                          _buildDetailRow(
                              icon: Icons.access_time_filled,
                              title: 'Oturum Süresi',
                              value:
                                  '${record.duration.inHours}s ${record.duration.inMinutes.remainder(60)}dk'),
                          _buildDetailRow(
                              icon: Icons.check_circle_outline,
                              title: 'Durum',
                              value: 'Kapalı (Ödeme Alındı)'),
                          if (record.note != null &&
                              record.note!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildNoteSection(record.note!),
                          ],
                          const Divider(height: 30),
                          _buildDetailRow(
                              icon: Icons.payment_rounded,
                              title: 'TOPLAM HESAP',
                              value:
                                  '${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(record.totalPrice)}',
                              isTotal: true),
                          const SizedBox(height: 24),
                          Text(
                              'Sipariş Edilen Ürünler (${record.items.length})',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 15),
                          ...record.items
                              .map((item) => Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    color: Colors.grey.shade100,
                                    child: ListTile(
                                      leading: Text('${item.quantity}x',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal.shade700)),
                                      title: Text(item.productName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      trailing: Text(
                                          NumberFormat.currency(
                                                  locale: 'tr_TR', symbol: '₺')
                                              .format(item.totalPrice),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ))
                              .toList(),
                        ]));
              });
        });
  }

  Widget _buildNoteSection(String note) {
    return Card(
      elevation: 0,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    color: Colors.amber.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Masa Notu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      {required IconData icon,
      required String title,
      required String value,
      bool isTotal = false}) {
    final color = isTotal ? Colors.green.shade700 : const Color(0xFF1A1A2E);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 17, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(dt);
  }
}
