import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_item_model.dart';
import '../providers/table_provider.dart';
import '../services/database_helper.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadVeresiyeRecords();
  }

  Future<void> _loadVeresiyeRecords() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // DatabaseHelper'ınızda bu fonksiyonun olduğunu varsayıyoruz
      final records = await DatabaseHelper.instance.getVeresiyeRecords();
      if (mounted) {
        setState(() {
          _veresiyeList = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Veresiye kayıtları yüklenirken hata: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Kayıtlar yüklenirken bir hata oluştu.', isError: true);
      }
    }
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
    final filteredList = _showPaid
        ? _veresiyeList
        : _veresiyeList.where((v) => !v.isPaid).toList();

    // Kayıtları en yeniden eskiye doğru sırala
    filteredList.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Veresiye Defteri',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilterChip(
              label: const Text('Ödenenleri Göster'),
              selected: _showPaid,
              onSelected: (bool value) {
                setState(() {
                  _showPaid = value;
                });
              },
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue.shade800,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredList.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadVeresiyeRecords,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final record = filteredList[index];
                      return _buildVeresiyeCard(record);
                    },
                  ),
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
    final color = record.isPaid ? Colors.green : Colors.blue;

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
      elevation: 4,
      shadowColor: color.withAlpha((255 * 0.2).round()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withAlpha((255 * 0.5).round()), width: 1),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.1).round()),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            record.isPaid
                ? Icons.check_circle_outline_rounded
                : Icons.person_outline_rounded,
            color: color.shade700,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color.shade800),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(record.date),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: record.isPaid
            ? Chip(
                label: const Text('ÖDENDİ'),
                backgroundColor: Colors.green.shade100,
                labelStyle: TextStyle(
                    color: Colors.green.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              )
            : IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400),
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
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
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
                      icon: Icon(Icons.edit_note_rounded,
                          color: Colors.orange.shade700),
                      label: Text('Düzenle',
                          style: TextStyle(color: Colors.orange.shade800)),
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
                          backgroundColor: Colors.green.shade600,
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
                _loadVeresiyeRecords(); // Listeyi yenile
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
                _loadVeresiyeRecords(); // Listeyi yenile
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
        title: const Text('Kaydı Sil', style: TextStyle(color: Colors.red)),
        content: Text(
            '${record.customerName} adlı kaydı kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!mounted) return;
              Navigator.of(context).pop(); // Diyaloğu kapat

              try {
                // DB'den sil (Bu fonksiyonu DatabaseHelper'da oluşturmalısınız)
                await DatabaseHelper.instance.deleteVeresiye(record.id!);
                _showSnackBar('Kayıt silindi.', isSuccess: true);
                _loadVeresiyeRecords(); // Listeyi yenile
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
            ? Colors.red.shade600
            : (isSuccess ? Colors.green.shade600 : Colors.blue.shade600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
