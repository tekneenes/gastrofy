import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../services/database_helper.dart';
import '../models/table_record_model.dart';
import '../providers/table_provider.dart';
import 'package:provider/provider.dart';

class TableRecordsScreen extends StatefulWidget {
  const TableRecordsScreen({super.key});

  @override
  State<TableRecordsScreen> createState() => _TableRecordsScreenState();
}

class _TableRecordsScreenState extends State<TableRecordsScreen> {
  bool _isFilterPanelVisible = false;

  String? _selectedTableFilter;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  TimeOfDay? _filterStartTime;
  TimeOfDay? _filterEndTime;
  int _noteFilterIndex = 0;
  String _currentSort = 'Date (Newest)';

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _minDurationController = TextEditingController();
  final TextEditingController _maxDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) {
      // Data is now handled by TableProvider, but we still trigger initial load if empty
      final provider = Provider.of<TableProvider>(context, listen: false);
      if (provider.tableRecords.isEmpty) {
        provider.loadTableRecords();
      }
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


  // Filtreleme ve gruplama mantığını build içinde kullanmak için saf fonksiyon haline getirdik
  Map<String, dynamic> _getFilteredData(List<TableRecordModel> allRecords) {
    final minPriceFilter = double.tryParse(_minPriceController.text);
    final maxPriceFilter = double.tryParse(_maxPriceController.text);
    final minDurationFilter = int.tryParse(_minDurationController.text);
    final maxDurationFilter = int.tryParse(_maxDurationController.text);

    final results = allRecords.where((record) {
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

    // Sorting results
    if (_currentSort == 'Date (Newest)') {
      results.sort((a, b) => b.startTime.compareTo(a.startTime));
    } else if (_currentSort == 'Date (Oldest)') {
      results.sort((a, b) => a.startTime.compareTo(b.startTime));
    } else if (_currentSort == 'Price (High to Low)') {
      results.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
    } else if (_currentSort == 'Price (Low to High)') {
      results.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    } else if (_currentSort == 'Duration (Longest)') {
      results.sort((a, b) => b.duration.compareTo(a.duration));
    } else if (_currentSort == 'Duration (Shortest)') {
      results.sort((a, b) => a.duration.compareTo(b.duration));
    }

    final double totalRevenue = results.fold(0, (sum, item) => sum + item.totalPrice);

    final Map<String, List<TableRecordModel>> grouped = {};
    if (_currentSort.contains('Date')) {
      for (var record in results) {
        final monthKey = DateFormat('MMMM yyyy', 'tr_TR').format(record.startTime);
        if (grouped[monthKey] == null) {
          grouped[monthKey] = [];
        }
        grouped[monthKey]!.add(record);
      }
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

    return {
      'filtered': results,
      'grouped': grouped,
      'isApplied': isAnyFilterApplied,
      'totalRevenue': totalRevenue,
    };
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
  }

  // Kaydı silmek için metod
  Future<void> _deleteRecord(TableRecordModel record) async {
    try {
      await DatabaseHelper.instance.deleteClosedOrder(record.id);
      
      // Provider'ı güncelle
      if (mounted) {
        Provider.of<TableProvider>(context, listen: false).loadTableRecords();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${record.tableName} kaydı başarıyla silindi.'),
            backgroundColor: Colors.teal.shade600,
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
                backgroundColor: Colors.teal.shade800,
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
    return Consumer<TableProvider>(
      builder: (context, tableProvider, child) {
        final data = _getFilteredData(tableProvider.tableRecords);
        final filteredRecords = data['filtered'] as List<TableRecordModel>;
        final groupedRecords = data['grouped'] as Map<String, List<TableRecordModel>>;
        final isFilterApplied = data['isApplied'] as bool;

        final List<dynamic> listItems = [];
        if (_currentSort.contains('Date')) {
          groupedRecords.forEach((month, records) {
            listItems.add(month);
            listItems.addAll(records);
          });
        } else {
          listItems.addAll(filteredRecords);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: const Text('Masa Kayıt Geçmişi',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00796B),
                    fontSize: 24)),
            toolbarHeight: 70,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF00796B),
            elevation: 0,
            shadowColor: Colors.black.withOpacity(0.05),
            surfaceTintColor: Colors.white,
            actions: [
              _buildAppBarAction(
                _isFilterPanelVisible
                    ? Icons.filter_alt_off_outlined
                    : Icons.filter_alt_outlined,
                'Filtrele',
                isFilterApplied
                    ? Colors.teal.shade700
                    : Colors.teal.shade500,
                () => setState(
                    () => _isFilterPanelVisible = !_isFilterPanelVisible),
              ),
              _buildAppBarAction(
                Icons.refresh_rounded,
                'Yenile',
                Colors.teal.shade600,
                () => tableProvider.loadTableRecords(),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: tableProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isFilterPanelVisible
                          ? _buildFilterPanel(tableProvider.tableRecords)
                          : _buildQuickFilterChips(isFilterApplied),
                    ),
                    if (filteredRecords.isNotEmpty)
                      _buildSummaryStats(filteredRecords.length, data['totalRevenue'] as double),
                    Expanded(
                      child: filteredRecords.isEmpty
                          ? _buildEmptyState(isFilterApplied)
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
      },
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

  Widget _buildFilterPanel(List<TableRecordModel> allRecords) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 4,
      shadowColor: Colors.teal.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterSectionTitle('Hızlı Tarih Seçenekleri'),
            _buildDateShortcuts(),
            const SizedBox(height: 20),
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
                    _buildTableDropdown(allRecords),
                    const SizedBox(height: 16),
                    _buildFilterSectionTitle('Sıralama'),
                    _buildSortDropdown(),
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
                  setState(() => _isFilterPanelVisible = false);
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Filtrele'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
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
        side: BorderSide(color: Colors.grey.shade400),
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
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTableDropdown(List<TableRecordModel> allRecords) {
    final List<String> availableTables =
        allRecords.map((e) => e.tableName).toSet().toList()..sort();
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      fillColor: Colors.teal.shade500,
      color: Colors.teal.shade500,
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 60.0),
      children: const [
        Text('Tümü'),
        Icon(Icons.note_alt_outlined),
        Icon(Icons.speaker_notes_off_outlined)
      ],
    );
  }

  Widget _buildEmptyState(bool isFilterApplied) {
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
            isFilterApplied
                ? 'Filtreye Uyan Kayıt Yok'
                : 'Kayıt Bulunmamaktadır',
            style: TextStyle(
                fontSize: 24,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            isFilterApplied
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
    final bool isQuickSale = record.tableName.toLowerCase().contains('hızlı') ||
        record.tableName.toLowerCase().contains('satış') ||
        record.tableName == 'QUICK_SALE';
    final MaterialColor color = isQuickSale ? Colors.blue : Colors.teal;

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
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.25), width: 2),
                  ),
                  child: Center(
                    child: isQuickSale
                        ? Icon(
                            Icons.bolt_rounded,
                            size: 32,
                            color: color.shade700,
                          )
                        : (int.tryParse(record.tableName.split(" ").last) != null
                            ? Text(
                                record.tableName.split(" ").last,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: color.shade700,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    record.tableName.split(" ").last,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: color.shade700,
                                    ),
                                  ),
                                ),
                              )),
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
                          color: Colors.teal.shade700),
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
                                  color: Color(0xFF00796B))),
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
                                  color: Color(0xFF1B5E20))),
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
                                              color: Colors.green.shade700)),
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
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Masa Notu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
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
    final color = isTotal ? Colors.teal.shade800 : const Color(0xFF00695C);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00796B), size: 22),
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

  Widget _buildDateShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildShortcutChip('Bugün', () {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            setState(() {
              _filterStartDate = today;
              _filterEndDate = today;
            });
          }),
          _buildShortcutChip('Dün', () {
            final yesterday = DateTime.now().subtract(const Duration(days: 1));
            final date = DateTime(yesterday.year, yesterday.month, yesterday.day);
            setState(() {
              _filterStartDate = date;
              _filterEndDate = date;
            });
          }),
          _buildShortcutChip('Bu Hafta', () {
            final now = DateTime.now();
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            setState(() {
              _filterStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
              _filterEndDate = DateTime(now.year, now.month, now.day);
            });
          }),
          _buildShortcutChip('Bu Ay', () {
            final now = DateTime.now();
            setState(() {
              _filterStartDate = DateTime(now.year, now.month, 1);
              _filterEndDate = DateTime(now.year, now.month, now.day);
            });
          }),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label),
        backgroundColor: Colors.teal.shade50,
        labelStyle: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSortDropdown() {
    final List<Map<String, String>> sortOptions = [
      {'label': 'Tarih (Yeniden Eskiye)', 'value': 'Date (Newest)'},
      {'label': 'Tarih (Eskiden Yeniye)', 'value': 'Date (Oldest)'},
      {'label': 'Fiyat (Yüksekten Düşüğe)', 'value': 'Price (High to Low)'},
      {'label': 'Fiyat (Düşükten Yükseğe)', 'value': 'Price (Low to High)'},
      {'label': 'Süre (Uzundan Kısaya)', 'value': 'Duration (Longest)'},
      {'label': 'Süre (Kısadan Uzuna)', 'value': 'Duration (Shortest)'},
    ];
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _currentSort,
      items: sortOptions
          .map((opt) => DropdownMenuItem(value: opt['value'], child: Text(opt['label'] ?? '')))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _currentSort = value);
      },
    );
  }

  Widget _buildQuickFilterChips(bool isApplied) {
    if (!isApplied) return const SizedBox.shrink();
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_filterStartDate != null)
            _buildActiveChip('Başlangıç: ${DateFormat('dd.MM').format(_filterStartDate!)}', () => setState(() => _filterStartDate = null)),
          if (_filterEndDate != null)
            _buildActiveChip('Bitiş: ${DateFormat('dd.MM').format(_filterEndDate!)}', () => setState(() => _filterEndDate = null)),
          if (_selectedTableFilter != null)
            _buildActiveChip('Masa: $_selectedTableFilter', () => setState(() => _selectedTableFilter = null)),
          if (_minPriceController.text.isNotEmpty)
            _buildActiveChip('Min: ${_minPriceController.text}₺', () => {setState(() => _minPriceController.clear())}),
          if (_maxPriceController.text.isNotEmpty)
            _buildActiveChip('Max: ${_maxPriceController.text}₺', () => {setState(() => _maxPriceController.clear())}),
          if (_noteFilterIndex != 0)
            _buildActiveChip(_noteFilterIndex == 1 ? 'Notlu' : 'Notsuz', () => setState(() => _noteFilterIndex = 0)),
        ],
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDelete,
        backgroundColor: Colors.teal.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
      ),
    );
  }

  Widget _buildSummaryStats(int count, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('$count Kayıt', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          Row(
            children: [
              Text(
                NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(total),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
