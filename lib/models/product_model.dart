// lib/models/product_model.dart (DOĞRU SÜRÜM)
class ProductModel {
  String id;
  String name;
  double price;
  int salesCount;
  // EKLENDİ
  String categoryId;
  String description;
  String imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.salesCount = 0,
    // EKLENDİ
    required this.categoryId,
    this.description = '',
    this.imageUrl = '',
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      salesCount: map['salesCount'] ?? 0,
      // EKLENDİ (Veritabanında yoksa boş string olmalı)
      categoryId: map['categoryId'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'salesCount': salesCount,
      // EKLENDİ
      'categoryId': categoryId,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}
