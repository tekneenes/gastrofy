import 'order_item_model.dart';

// OrderModel, bir masadaki genel siparişi temsil eder.
// Siparişin ne zaman başladığı ve hangi masaya ait olduğu gibi temel bilgileri tutar.
// Siparişin detayları (hangi ürünler, kaç adet) OrderItem'lar tarafından tutulur.
class OrderModel {
  int? id; // Veritabanı tarafından otomatik atanacak benzersiz kimlik
  final String tableId; // Siparişin ait olduğu masanın ID'si
  final DateTime createdAt; // Siparişin oluşturulma zamanı
  // Ek olarak, bu modele 'totalAmount' veya 'endTime' gibi alanlar da ekleyebilirsiniz.

  // NOTE: orders listesi OrderModel'in kendisinde tutulmaz, veritabanından alınır
  // Ancak TableModel'in içinde kolay erişim için tutulabilir.
  // Bu liste sadece OrderModel nesnesi bellekte oluşturulduğunda geçici olarak kullanılabilir,
  // veritabanına doğrudan kaydedilmez.
  List<OrderItem>
      orders; // DÜZELTME: Bu alan artık 'final' değil, değiştirilebilir.

  OrderModel({
    this.id,
    required this.tableId,
    required this.createdAt,
    this.orders =
        const [], // DÜZELTME: 'required' kaldırıldı ve varsayılan olarak boş bir liste atanıyor.
  });

  // Veritabanından gelen Map'i OrderModel'e dönüştürür
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'],
      tableId: map['tableId'],
      createdAt: DateTime.parse(map['createdAt']),
      orders: [], // orders alanı veritabanından yüklenmez, ayrı bir sorgu ile getirilir, bu yüzden burada boş mutable liste olarak başlatılır.
    );
  }

  // OrderModel'i veritabanına kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id':
          id, // ID null ise, veritabanı otomatik atayacaktır (INTEGER PRIMARY KEY)
      'tableId': tableId,
      'createdAt':
          createdAt.toIso8601String(), // DateTime'ı string olarak kaydet
    };
  }

  // DÜZELTME: copyWith metodu eklendi
  OrderModel copyWith({
    int? id,
    String? tableId,
    DateTime? createdAt,
    List<OrderItem>? orders,
  }) {
    return OrderModel(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      createdAt: createdAt ?? this.createdAt,
      orders: orders ?? this.orders,
    );
  }
}
