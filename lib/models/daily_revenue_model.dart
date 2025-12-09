import 'dart:convert';

class DailyRevenue {
  final String id;
  final String date; // yyyy-MM-dd formatında
  final double revenue;
  // YENİ: Satılan ürünleri ve adetlerini tutan Map
  // Örnek: {'Kola': 2, 'Hamburger': 1}
  final Map<String, int> soldProducts;

  DailyRevenue({
    required this.id,
    required this.date,
    required this.revenue,
    Map<String, int>? soldProducts,
  }) : soldProducts = soldProducts ?? {}; // Varsayılan olarak boş bir map ata

  // Veritabanı işlemleri için toMap ve fromMap metodlarını güncelliyoruz
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'revenue': revenue,
      // Map'i veritabanında saklamak için JSON string'e çeviriyoruz
      'soldProducts': jsonEncode(soldProducts),
    };
  }

  // Hatanın düzeltildiği fromMap metodu
  factory DailyRevenue.fromMap(Map<String, dynamic> map) {
    return DailyRevenue(
      // DÜZELTME: Eğer veritabanından 'id' alanı boş (null) gelirse,
      // varsayılan olarak boş bir string ata ('').
      id: map['id'] ?? '',

      // DÜZELTME: Eğer veritabanından 'date' alanı boş (null) gelirse,
      // varsayılan olarak boş bir string ata ('').
      // Hatanın asıl kaynağı bu satırdı.
      date: map['date'] ?? '',

      // DÜZELTME: Eğer veritabanından 'revenue' alanı boş (null) gelirse,
      // varsayılan olarak 0.0 değerini ata.
      revenue: map['revenue']?.toDouble() ?? 0.0,

      // Veritabanından okurken JSON string'i tekrar Map'e çeviriyoruz
      // Bu kısım zaten doğru yazılmıştı.
      soldProducts:
          Map<String, int>.from(jsonDecode(map['soldProducts'] ?? '{}')),
    );
  }
}
