import 'order_item_model.dart';
import 'order_model.dart';

class TableModel {
  final String id;
  String name;
  bool isOccupied;
  DateTime? startTime;
  double totalRevenue;
  OrderModel? currentOrder;
  List<OrderItem> orders; // sipariş detayları
  int position; // sıralama pozisyonu
  String? note; // YENİ: Masa için not alanı

  TableModel({
    required this.id,
    required this.name,
    this.isOccupied = false,
    this.startTime,
    this.totalRevenue = 0.0,
    this.currentOrder,
    List<OrderItem>? orders,
    required this.position,
    this.note, // YENİ: Kurucuya eklendi
  }) : orders = orders ?? [];

  // Veritabanından okuma
  factory TableModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedStartTime;
    if (map['startTime'] != null) {
      try {
        parsedStartTime = DateTime.parse(map['startTime']);
      } catch (e) {
        // Hata durumunda null döndür
        parsedStartTime = null;
      }
    }

    // Not alanını oku. Eğer null değilse, String olarak al.
    final String? tableNote = map['note'];

    return TableModel(
      id: map['id'],
      name: map['name'],
      isOccupied: map['isOccupied'] == 1,
      startTime: parsedStartTime,
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      currentOrder: null, // OrderModel genelde ayrı yüklenir
      orders: [],
      position: map['position'] ?? 0,
      note: tableNote, // YENİ: Not buraya eklendi
    );
  }

  // Veritabanına yazma
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isOccupied': isOccupied ? 1 : 0,
      'startTime': startTime?.toIso8601String(),
      'totalRevenue': totalRevenue,
      'position': position,
      'note': note, // YENİ: Not toMap'e eklendi
    };
  }

  // Kopya oluşturup güncelleme
  TableModel copyWith({
    String? id,
    String? name,
    bool? isOccupied,
    DateTime? startTime,
    double? totalRevenue,
    OrderModel? currentOrder,
    List<OrderItem>? orders,
    int? position,
    String? note, // YENİ: copyWith'e eklendi
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isOccupied: isOccupied ?? this.isOccupied,
      startTime: startTime ?? this.startTime,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      currentOrder: currentOrder ?? this.currentOrder,
      orders: orders ?? this.orders,
      position: position ?? this.position,
      note: note ?? this.note, // YENİ: Not güncellemesi
    );
  }
}
