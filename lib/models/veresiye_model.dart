import 'dart:convert';
import 'order_item_model.dart'; // HATA DÜZELTİLDİ: Yanlış import yolu düzeltildi.

class VeresiyeModel {
  final int? id;
  final String customerName;
  final double totalAmount;
  final String? itemsJson;
  final String? note;
  final DateTime createdAt;
  final bool isPaid;

  VeresiyeModel({
    this.id,
    required this.customerName,
    required this.totalAmount,
    this.itemsJson,
    this.note,
    required this.createdAt,
    this.isPaid = false,
  });

  // Veritabanı map'inden modele dönüştürme
  factory VeresiyeModel.fromMap(Map<String, dynamic> map) {
    return VeresiyeModel(
      id: map['id'],
      customerName: map['customerName'],
      totalAmount: map['totalAmount'],
      itemsJson: map['itemsJson'],
      note: map['note'],
      createdAt: DateTime.parse(map['createdAt']),
      isPaid: map['isPaid'] == 1,
    );
  }

  // Modelden veritabanı map'ine dönüştürme
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'totalAmount': totalAmount,
      'itemsJson': itemsJson,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'isPaid': isPaid ? 1 : 0,
    };
  }

  // itemsJson'ı OrderItem listesine dönüştüren yardımcı metot
  List<OrderItem> get items {
    if (itemsJson == null || itemsJson!.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(itemsJson!);
      return decoded.map((itemMap) => OrderItem.fromMap(itemMap)).toList();
    } catch (e) {
      return [];
    }
  }
}
