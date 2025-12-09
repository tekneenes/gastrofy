// lib/models/order_item_model.dart
class OrderItem {
  int?
      id; // Unique ID for the order item (optional for new items, required for existing)
  int orderId; // ID of the order this item belongs to
  String productId;
  String productName;
  double productPrice;
  int quantity;
  bool isSpecialProduct; // Özel ürün mü?

  OrderItem({
    this.id, // Made optional for when creating new items before they have an ID from the DB
    required this.orderId, // This is crucial for associating with an order
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    this.isSpecialProduct = false,
  });

  // Veritabanından gelen Map'i OrderItem'e dönüştürür
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'], // Assuming 'id' field in the database
      orderId: map['orderId'], // Assuming 'orderId' field in the database
      productId: map['productId'],
      productName: map['productName'],
      productPrice: map['productPrice'],
      quantity: map['quantity'],
      isSpecialProduct: map['isSpecialProduct'] == 1,
    );
  }

  // OrderItem'ı veritabanına kaydetmek için Map'e dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id':
          id, // Include id when converting to map for updates/deletes if needed
      'orderId': orderId, // Crucial for database storage
      'productId': productId,
      'productName': productName,
      'productPrice': productPrice,
      'quantity': quantity,
      'isSpecialProduct': isSpecialProduct ? 1 : 0,
    };
  }
}
