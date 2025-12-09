// lib/models/category_model.dart
import 'package:uuid/uuid.dart';

class CategoryModel {
  final String id;
  String name;

  CategoryModel({
    required this.id,
    required this.name,
  });

  // Yeni bir kategori oluştururken kullanmak için factory metodu
  factory CategoryModel.create({required String name}) {
    return CategoryModel(
      id: const Uuid().v4(),
      name: name,
    );
  }

  // JSON dönüşümü (SharedPreferences'a kaydetmek için)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  // JSON'dan nesne oluşturma (SharedPreferences'dan yüklemek için)
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
