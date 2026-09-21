import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_item_model.dart';
import '../providers/table_provider.dart';
import '../services/database_helper.dart';

// -----------------------------------------------------------------
// Veresiye Model Sınıfı
// -----------------------------------------------------------------
// Bu sınıfın, DatabaseHelper'ınızdan dönen verilerle eşleşmesi gerekir.
// table_detail_screen'deki saveAsVeresiye fonksiyonuna dayanarak oluşturulmuştur.

class VeresiyeModel {
  final int? id;
  final String customerName;
  final double totalAmount;
  final String itemsJson;
  final String? note;
  final DateTime date;
  final bool isPaid;

  VeresiyeModel({
    this.id,
    required this.customerName,
    required this.totalAmount,
    required this.itemsJson,
    this.note,
    required this.date,
    this.isPaid = false,
  });

  // DatabaseHelper'dan veri okumak için fromMap
  factory VeresiyeModel.fromMap(Map<String, dynamic> map) {
    return VeresiyeModel(
      id: map['id'],
      customerName: map['customerName'],
      totalAmount: map['totalAmount'],
      itemsJson: map['itemsJson'],
      note: map['note'],
      // Tarihin veritabanında ISO 8601 string olarak saklandığını varsayıyoruz
      date: DateTime.parse(map['date']),
      // isPaid durumunun 0 (false) veya 1 (true) olarak saklandığını varsayıyoruz
      isPaid: map['isPaid'] == 1,
    );
  }

  // DatabaseHelper'a veri yazmak için toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'totalAmount': totalAmount,
      'itemsJson': itemsJson,
      'note': note,
      'date': date.toIso8601String(),
      'isPaid': isPaid ? 1 : 0,
    };
  }

  // Kopyalama için (bir alanı güncellerken kullanışlı)
  VeresiyeModel copyWith({
    int? id,
    String? customerName,
    double? totalAmount,
    String? itemsJson,
    String? note,
    DateTime? date,
    bool? isPaid,
  }) {
    return VeresiyeModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      itemsJson: itemsJson ?? this.itemsJson,
      note: note ?? this.note,
      date: date ?? this.date,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

// -----------------------------------------------------------------
// Veresiye Ekranı Widget'ı
// -----------------------------------------------------------------

class VeresiyeScreen extends StatefulWidget {
  const VeresiyeScreen({super.key});

  @override
  State<VeresiyeScreen> createState() => _VeresiyeScreenState();
}

class _VeresiyeScreenState extends State<VeresiyeScreen> {
  List<VeresiyeModel> _veresiyeList = [];
  bool _isLoading = true;
  bool _showPaid = false; // Ödenenleri göstermek için filtre
  bool _isFilterPanelVisible = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    // Data is now handled by TableProvider
    final provider = Provider.of<TableProvider>(context, listen: false);
    if (provider.veresiyeRecords.isEmpty) {
      provider.loadVeresiyeRecords();
    }
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }


  // Para formatlayıcı
  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(amount);
  }

  // Tarih formatlayıcı
  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TableProvider>(
      builder: (context, tableProvider, child) {
        _veresiyeList = tableProvider.veresiyeRecords;
        _isLoading = tableProvider.isLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('Veresiye Defteri',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => tableProvider.loadVeresiyeRecords(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildSearchBar(),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isFilterPanelVisible ? _buildFilterPanel() : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: _buildVeresiyeList(tableProvider.veresiyeRecords),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Müşteri adı veya not ara...',
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.teal),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () => _searchController.clear(),
                ),
              IconButton(
                icon: Icon(
                  _isFilterPanelVisible ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined,
                  color: _isFilterPanelVisible ? Colors.teal : Colors.grey,
                ),
                onPressed: () => setState(() => _isFilterPanelVisible = !_isFilterPanelVisible),
              ),
              const SizedBox(width: 4),
            ],
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.teal.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.teal.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.teal, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.teal.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.teal.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Ödenenleri Göster'),
                    selected: _showPaid,
                    onSelected: (val) => setState(() => _showPaid = val),
                    selectedColor: Colors.teal.shade50,
                    checkmarkColor: Colors.teal.shade700,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.teal.withOpacity(0.2)),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPaid = false;
                      _filterStartDate = null;
                      _filterEndDate = null;
                      _minAmountController.clear();
                      _maxAmountController.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.teal),
                  label: const Text('Temizle', style: TextStyle(color: Colors.teal)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.teal),
                    label: Text(
                      _filterStartDate == null ? 'Başlangıç' : DateFormat('dd.MM.yy').format(_filterStartDate!),
                      style: const TextStyle(color: Colors.teal),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _filterStartDate = picked);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.teal),
                    label: Text(
                      _filterEndDate == null ? 'Bitiş' : DateFormat('dd.MM.yy').format(_filterEndDate!),
                      style: const TextStyle(color: Colors.teal),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _filterEndDate = picked);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Min Tutar',
                      labelStyle: const TextStyle(color: Colors.teal, fontSize: 13),
                      prefixText: '₺ ',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.teal.withOpacity(0.02),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max Tutar',
                      labelStyle: const TextStyle(color: Colors.teal, fontSize: 13),
                      prefixText: '₺ ',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.teal.withOpacity(0.02),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVeresiyeList(List<VeresiyeModel> allRecords) {
    final query = _searchController.text.toLowerCase();
    final minAmount = double.tryParse(_minAmountController.text);
    final maxAmount = double.tryParse(_maxAmountController.text);

    final filteredList = allRecords.where((record) {
      // Basic Filters
      if (!_showPaid && record.isPaid) return false;

      // Search Query
      if (query.isNotEmpty) {
        final nameMatch = record.customerName.toLowerCase().contains(query);
        final noteMatch = (record.note ?? '').toLowerCase().contains(query);
        
        // Product names search
        bool productMatch = false;
        try {
          final List<dynamic> decodedList = jsonDecode(record.itemsJson);
          for (var itemMap in decodedList) {
            final productName = (itemMap['productName'] ?? '').toString().toLowerCase();
            if (productName.contains(query)) {
              productMatch = true;
              break;
            }
          }
        } catch (_) {}

        if (!nameMatch && !noteMatch && !productMatch) return false;
      }

      // Date Filters
      if (_filterStartDate != null && record.date.isBefore(_filterStartDate!)) return false;
      if (_filterEndDate != null && record.date.isAfter(_filterEndDate!.add(const Duration(days: 1)))) return false;

      // Amount Filters
      if (minAmount != null && record.totalAmount < minAmount) return false;
      if (maxAmount != null && record.totalAmount > maxAmount) return false;

      return true;
    }).toList();

    // Sort newest first
    filteredList.sort((a, b) => b.date.compareTo(a.date));

    if (filteredList.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: () => Provider.of<TableProvider>(context, listen: false).loadVeresiyeRecords(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          return _buildVeresiyeCard(filteredList[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_online_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Veresiye kaydı bulunamadı.',
            style: TextStyle(
                fontSize: 20,
                color: Colors.black54,
                fontWeight: FontWeight.w600),
          ),
          if (!_showPaid)
            const Text(
              'Filtreyi değiştirerek ödenmiş kayıtları görebilirsiniz.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildVeresiyeCard(VeresiyeModel record) {
    final statusColor = record.isPaid ? Colors.green : Colors.teal;
    final accentColor = record.isPaid ? Colors.green.shade700 : Colors.teal.shade700;

    // JSON'dan sipariş listesini çöz
    List<OrderItem> items = [];
    try {
      final List<dynamic> decodedList = jsonDecode(record.itemsJson);
      items = decodedList.map((itemMap) => OrderItem.fromMap(itemMap)).toList();
    } catch (e) {
      print("Veresiye detayı ayrıştırılırken hata: $e");
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 6,
      color: Colors.white,
      shadowColor: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: statusColor.withOpacity(0.05), width: 1),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            record.isPaid
                ? Icons.check_circle_outline_rounded
                : Icons.account_balance_wallet_outlined,
            color: accentColor,
            size: 28,
          ),
        ),
        title: Text(
          record.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatCurrency(record.totalAmount),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(record.date),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: record.isPaid
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Text(
                  'ÖDENDİ',
                  style: TextStyle(
                      color: Colors.teal.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              )
            : IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.teal.shade300),
                tooltip: 'Kaydı Sil',
                onPressed: () => _deleteRecord(record),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 20),
                const Text(
                  'Sipariş Detayları:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...items.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      leading: Text(
                        '${item.quantity} x',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        _formatCurrency(item.productPrice * item.quantity),
                      ),
                    )),
                if (record.note != null && record.note!.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text(
                    'Masa Notu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Text(
                      record.note!,
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.brown.shade800),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note_rounded,
                          color: Colors.teal),
                      label: const Text('Düzenle',
                          style: TextStyle(color: Colors.teal)),
                      onPressed: () => _editRecord(record),
                    ),
                    const SizedBox(width: 8),
                    if (!record.isPaid)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.price_check_rounded,
                            color: Colors.white),
                        label: const Text('Ödendi İşaretle',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _markAsPaid(record),
                      ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- EYLEM FONKSİYONLARI ---

  void _markAsPaid(VeresiyeModel record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ödemeyi Onayla'),
        content: Text(
            '${record.customerName} adlı kaydın ${_formatCurrency(record.totalAmount)} tutarındaki ödemesini onaylıyor musunuz? Bu tutar GÜNLÜK CİROYA eklenecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!mounted) return;
              Navigator.of(context).pop(); // Diyaloğu kapat

              final updatedRecord = record.copyWith(isPaid: true);

              try {
                // DB'yi güncelle (Bu fonksiyonu DatabaseHelper'da oluşturmalısınız)
                await DatabaseHelper.instance.updateVeresiye(updatedRecord);

                // Ciroyu TableProvider üzerinden güncelle
                // (Bu fonksiyonu TableProvider'da oluşturmalısınız)
                Provider.of<TableProvider>(context, listen: false)
                    .addRevenueFromVeresiye(record.totalAmount);

                _showSnackBar('Ödeme kaydedildi ve ciroya eklendi.',
                    isSuccess: true);
                
                // Provider'ı güncelle (listeyi yenile)
                if (mounted) {
                  Provider.of<TableProvider>(context, listen: false).loadVeresiyeRecords();
                }
              } catch (e) {
                print("Veresiye ödeme hatası: $e");
                _showSnackBar('Ödeme kaydedilirken bir hata oluştu.',
                    isError: true);
              }
            },
            child: const Text('Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editRecord(VeresiyeModel record) {
    final nameController = TextEditingController(text: record.customerName);
    final noteController = TextEditingController(text: record.note ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kaydı Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Başlık / Müşteri Adı',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Not (İsteğe bağlı)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!mounted) return;
              Navigator.of(context).pop(); // Diyaloğu kapat

              final updatedRecord = record.copyWith(
                customerName: nameController.text.trim(),
                note: noteController.text.trim(),
              );

              try {
                // DB'yi güncelle (Bu fonksiyonu DatabaseHelper'da oluşturmalısınız)
                await DatabaseHelper.instance.updateVeresiye(updatedRecord);
                _showSnackBar('Kayıt güncellendi.', isSuccess: true);
                
                // Provider'ı güncelle (listeyi yenile)
                if (mounted) {
                  Provider.of<TableProvider>(context, listen: false).loadVeresiyeRecords();
                }
              } catch (e) {
                print("Veresiye güncelleme hatası: $e");
                _showSnackBar('Kayıt güncellenirken bir hata oluştu.',
                    isError: true);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _deleteRecord(VeresiyeModel record) {
    // Ödenmiş kayıtların silinmesini engellemek iyi bir pratik olabilir
    // Ancak burada, ödenmemişlerin silinmesine izin veriyoruz.
    if (record.isPaid) {
      _showSnackBar('Ödenmiş kayıtlar silinemez.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kaydı Sil', style: TextStyle(color: Colors.teal)),
        content: Text(
            '${record.customerName} adlı kaydı kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!mounted) return;
              Navigator.of(context).pop(); // Diyaloğu kapat

              try {
                // DB'den sil (Bu fonksiyonu DatabaseHelper'da oluşturmalısınız)
                await DatabaseHelper.instance.deleteVeresiye(record.id!);
                _showSnackBar('Kayıt silindi.', isSuccess: true);
                
                // Provider'ı güncelle (listeyi yenile)
                if (mounted) {
                  Provider.of<TableProvider>(context, listen: false).loadVeresiyeRecords();
                }
              } catch (e) {
                print("Veresiye silme hatası: $e");
                _showSnackBar('Kayıt silinirken bir hata oluştu.',
                    isError: true);
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.orange.shade900
            : (isSuccess ? Colors.green.shade600 : Colors.blue.shade600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
