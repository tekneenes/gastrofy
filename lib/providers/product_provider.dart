import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

/// 📊 Raporlarda kullanılacak satış özeti modeli
class ProductSaleSummary {
  final String id;
  final String name;
  final int salesQuantity;

  ProductSaleSummary({
    required this.id,
    required this.name,
    required this.salesQuantity,
  });
}

class ProductProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];

  // 📈 Satış özeti listesi (rapor ekranında kullanılır)
  List<ProductSaleSummary> _salesSummary = [];

  String? _fixedProductId;
  bool _showTopSelling = false;

  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  List<ProductSaleSummary> get filteredSalesSummary => _salesSummary;

  String? get fixedProductId => _fixedProductId;
  bool get showTopSelling => _showTopSelling;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  ProductProvider() {
    loadCategories();
    loadProducts();
    _loadSettings();
  }

  // ===================== 🔖 KATEGORİ YÖNETİMİ =====================

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String categoriesJson =
        jsonEncode(_categories.map((c) => c.toJson()).toList());
    await prefs.setString('categories', categoriesJson);
  }

  Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? categoriesJson = prefs.getString('categories');
    if (categoriesJson != null) {
      final List<dynamic> categoriesList = jsonDecode(categoriesJson);
      _categories =
          categoriesList.map((json) => CategoryModel.fromJson(json)).toList();
    } else {
      if (_categories.isEmpty) {
        final defaultCategory = CategoryModel.create(name: 'Genel');
        _categories.add(defaultCategory);
        await _saveCategories();
      }
    }
    notifyListeners();
  }

  void addCategory(String name) {
    final newCategory = CategoryModel.create(name: name);
    _categories.add(newCategory);
    _saveCategories();
    notifyListeners();
  }

  void updateCategory(CategoryModel category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      _saveCategories();
      notifyListeners();
    }
  }

  void deleteCategory(String id) {
    final defaultCategory = _categories.firstWhere(
      (c) => c.name == 'Genel',
      orElse: () => _categories.first,
    );

    for (var product in _products) {
      if (product.categoryId == id) {
        product.categoryId = defaultCategory.id;
        _dbHelper.updateProduct(product);
      }
    }

    _categories.removeWhere((c) => c.id == id);
    _saveCategories();
    notifyListeners();
  }

  // ===================== 📦 ÜRÜN YÖNETİMİ =====================

  Future<void> loadProducts() async {
    _products = await _dbHelper.getProducts();
    _products.sort((a, b) => b.salesCount.compareTo(a.salesCount));
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fixedProductId = prefs.getString('fixedProductId');
    _showTopSelling = prefs.getBool('showTopSelling') ?? false;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_fixedProductId != null) {
      await prefs.setString('fixedProductId', _fixedProductId!);
    } else {
      await prefs.remove('fixedProductId');
    }
    await prefs.setBool('showTopSelling', _showTopSelling);
  }

  Future<void> addProduct(String name, double price, String categoryId) async {
    final newProduct = ProductModel(
      id: _uuid.v4(),
      name: name,
      price: price,
      categoryId: categoryId,
    );
    await _dbHelper.insertProduct(newProduct);
    await loadProducts();
  }

  Future<void> updateProduct(ProductModel product) async {
    await _dbHelper.updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(String id) async {
    if (_fixedProductId == id) {
      _fixedProductId = null;
      await _saveSettings();
    }
    await _dbHelper.deleteProduct(id);
    await loadProducts();
  }

  Future<void> incrementProductSalesCount(
      String productId, int quantity) async {
    ProductModel product = _products.firstWhere((p) => p.id == productId);
    product.salesCount += quantity;
    await _dbHelper.updateProduct(product);
    await loadProducts();
  }

  void toggleFixedProduct(String productId) {
    if (_fixedProductId == productId) {
      _fixedProductId = null;
    } else {
      _fixedProductId = productId;
    }
    _saveSettings();
    notifyListeners();
  }

  void toggleShowTopSelling() {
    _showTopSelling = !_showTopSelling;
    _saveSettings();
    notifyListeners();
  }

  // ===================== 🔍 ÜRÜN FİLTRELEME =====================

  List<ProductModel> get productsForTableSelection {
    List<ProductModel> displayedProducts = List.from(_products);

    if (_fixedProductId != null) {
      ProductModel? fixedProduct = displayedProducts.firstWhere(
        (p) => p.id == _fixedProductId,
        orElse: () =>
            ProductModel(id: '', name: 'Not Found', price: 0.0, categoryId: ''),
      );
      if (fixedProduct.id.isNotEmpty) {
        displayedProducts.removeWhere((p) => p.id == _fixedProductId);
        displayedProducts.insert(0, fixedProduct);
      }
    }

    if (_showTopSelling) {
      displayedProducts.sort((a, b) => b.salesCount.compareTo(a.salesCount));
    }

    return displayedProducts;
  }

  // ===================== 📊 RAPORLAMA & SATIŞ ÖZETİ =====================

  /// 📈 Belirli tarih aralığındaki satış özetini yükler
  Future<void> loadProductSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 🔎 Burada gerçek veritabanı sorgusu yapılabilir.
    // Şimdilik mevcut ürünlerin salesCount değerine göre liste oluşturuyoruz.

    _salesSummary = _products.map((product) {
      return ProductSaleSummary(
        id: product.id,
        name: product.name,
        salesQuantity: product.salesCount,
      );
    }).toList();

    _salesSummary.sort((a, b) => b.salesQuantity.compareTo(a.salesQuantity));

    notifyListeners();
  }

  // ===================== 🧠 EKSTRA =====================

  List<CategoryModel> get globalTopSellingCategories {
    final Map<String, int> categorySales = {};

    for (var product in _products) {
      categorySales[product.categoryId] =
          (categorySales[product.categoryId] ?? 0) + product.salesCount;
    }

    List<CategoryModel> sortedCategories = List.from(_categories);
    sortedCategories.sort((a, b) {
      int salesA = categorySales[a.id] ?? 0;
      int salesB = categorySales[b.id] ?? 0;
      return salesB.compareTo(salesA);
    });

    return sortedCategories;
  }

  bool get isTopSellingFeatureEnabled => _showTopSelling;

  void updateGlobalTopSellingCategories(List<String> categoryIds) {}

  void setTopSellingFeatureEnabled(bool isFeatureEnabled) {
    _showTopSelling = isFeatureEnabled;
    _saveSettings();
    notifyListeners();
  }
}
