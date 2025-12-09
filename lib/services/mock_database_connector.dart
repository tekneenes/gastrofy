// Bu dosya, Gemini'a veri sağlamak için DatabaseHelper sınıfınızdaki
// temel metotları simüle eder. Gerçek uygulamada, bu metotlar
// mevcut DatabaseHelper sınıfınızı çağırmalıdır.

import 'dart:convert';
import 'dart:math';

// Gerçek hayatta, TableModel, DailyRevenue vb. modellerinizi import edecektiniz.
// Burada JSON formatında simülasyon yapıyoruz.

class MockDatabaseConnector {
  // Bu, gerçek DatabaseHelper.instance gibi davranır
  static final MockDatabaseConnector instance = MockDatabaseConnector._();
  MockDatabaseConnector._();

  /// Simüle edilmiş veresiye kaydı listesi
  static const List<Map<String, dynamic>> _mockVeresiye = [
    {
      'id': 101,
      'customerName': 'Ali Yılmaz',
      'totalAmount': 155.50,
      'isPaid': 0,
      'date': '2025-10-25',
    },
    {
      'id': 102,
      'customerName': 'Veli Kaya',
      'totalAmount': 420.00,
      'isPaid': 0,
      'date': '2025-10-20',
    },
    {
      'id': 103,
      'customerName': 'Ayşe Demir',
      'totalAmount': 85.00,
      'isPaid': 1,
      'date': '2025-10-18',
    },
  ];

  /// Simüle edilmiş masa listesi
  static const List<Map<String, dynamic>> _mockTables = [
    {'id': 'T1', 'name': 'Masa 1', 'isOccupied': 1, 'totalRevenue': 120.50},
    {'id': 'T2', 'name': 'Masa 2', 'isOccupied': 0, 'totalRevenue': 0.0},
    {'id': 'T3', 'name': 'Masa 3', 'isOccupied': 1, 'totalRevenue': 350.00},
    {'id': 'T4', 'name': 'Masa 4', 'isOccupied': 1, 'totalRevenue': 85.00},
    {'id': 'T5', 'name': 'Masa 5', 'isOccupied': 0, 'totalRevenue': 0.0},
  ];

  // -----------------------------------------------------------
  // 1. İşlev: Aktif Masa Durumunu Getir
  // Gerçek uygulamada: DatabaseHelper'daki getTables() metodunu çağırırsınız.
  // -----------------------------------------------------------
  Future<String> getActiveTableStatus() async {
    // Sadece isOccupied (Dolu/Boş) ve isim bilgisini JSON formatında döndürelim
    final result = _mockTables
        .map((table) => {
              'name': table['name'],
              'isOccupied': table['isOccupied'] == 1 ? 'Dolu' : 'Boş',
              'revenue': table['totalRevenue'],
            })
        .toList();

    return jsonEncode(result);
  }

  // -----------------------------------------------------------
  // 2. İşlev: Günlük Ciroyu Getir
  // Gerçek uygulamada: DatabaseHelper'daki getTodayRevenue() metodunu çağırırsınız.
  // -----------------------------------------------------------
  Future<String> getTodayRevenue() async {
    // Rastgele bir ciro üretelim
    final todayRevenue = (Random().nextDouble() * 5000) + 1000;
    return jsonEncode({'todayRevenue': todayRevenue.toStringAsFixed(2)});
  }

  // -----------------------------------------------------------
  // 3. İşlev: Ödenmemiş Veresiye Kayıtlarını Listele
  // Gerçek uygulamada: DatabaseHelper'daki getVeresiyeRecords() metodunu filtreleyerek çağırırsınız.
  // -----------------------------------------------------------
  Future<String> getUnpaidVeresiyeRecords() async {
    final result = _mockVeresiye
        .where((record) => record['isPaid'] == 0)
        .map((record) => {
              'customer': record['customerName'],
              'amount': record['totalAmount'],
            })
        .toList();

    return jsonEncode(result);
  }
}
