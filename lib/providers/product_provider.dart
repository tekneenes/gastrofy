import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:convert';
import '../models/order_item_model.dart';
import '../services/firebase_service.dart';
import '../services/database_service.dart';

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

  // GastroQR States
  bool _isGastroQREnabled = false;
  String? _companyEmail;
  String? _companySlug;
  String _themeId = 'retro'; // Varsayılan tema
  bool _showProductPhotos = true; // GastroQR'da resimler görünsün mü?

  List<ProductModel> get products => _products;
  List<CategoryModel> get categories => _categories;
  List<ProductSaleSummary> get filteredSalesSummary => _salesSummary;

  String? get fixedProductId => _fixedProductId;
  bool get showTopSelling => _showTopSelling;
  bool get isGastroQREnabled => _isGastroQREnabled;
  String? get companySlug => _companySlug;
  String get themeId => _themeId;
  bool get showProductPhotos => _showProductPhotos;

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
      // Kullanıcı talebi: Varsayılan olarak 'Genel' kategorisi olmasın
      if (_categories.any((c) => c.name == 'Genel')) {
        _categories.removeWhere((c) => c.name == 'Genel');
        await _saveCategories();
      }
    } else {
      _categories = [];
    }
    notifyListeners();
  }

  void addCategory(String name) {
    final newCategory = CategoryModel.create(name: name);
    _categories.add(newCategory);
    _saveCategories();
    
    // GastroQR Sync
    if (_isGastroQREnabled && _companyEmail != null) {
      FirebaseService.instance.syncCategoryToPublicMenu(_companyEmail!, newCategory.toJson());
    }

    notifyListeners();
  }

  void updateCategory(CategoryModel category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      _saveCategories();
      
      // GastroQR Sync
      if (_isGastroQREnabled && _companyEmail != null) {
        FirebaseService.instance.syncCategoryToPublicMenu(_companyEmail!, category.toJson());
      }

      notifyListeners();
    }
  }

  void deleteCategory(String id) {
    final remainingCategories = _categories.where((c) => c.id != id).toList();
    final String fallbackCategoryId =
        remainingCategories.isNotEmpty ? remainingCategories.first.id : '';

    for (var product in _products) {
      if (product.categoryId == id) {
        product.categoryId = fallbackCategoryId;
        _dbHelper.updateProduct(product);
        
        // Ürün kategorisi değiştiği için ürünü de güncellemeliyiz
        if (_isGastroQREnabled && _companyEmail != null) {
          FirebaseService.instance.syncProductToPublicMenu(_companyEmail!, product.toMap());
        }
      }
    }

    _categories.removeWhere((c) => c.id == id);
    _saveCategories();
    
    // GastroQR Sync
    if (_isGastroQREnabled && _companyEmail != null) {
      FirebaseService.instance.deleteCategoryFromPublicMenu(_companyEmail!, id);
    }

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
    
    // GastroQR Settings
    _isGastroQREnabled = prefs.getBool('isGastroQREnabled') ?? false;
    _companySlug = prefs.getString('companySlug');
    final dbService = DatabaseService();
    _companyEmail = await dbService.readValue('userEmail');
    _themeId = prefs.getString('themeId') ?? 'retro';
    _showProductPhotos = prefs.getBool('showProductPhotos') ?? true;
    
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

  Future<void> addProduct(String name, double price, String categoryId, {String description = '', String imageUrl = ''}) async {
    final newProduct = ProductModel(
      id: _uuid.v4(),
      name: name,
      price: price,
      categoryId: categoryId,
      description: description,
      imageUrl: imageUrl,
    );
    await _dbHelper.insertProduct(newProduct);
    
    // GastroQR Sync
    if (_isGastroQREnabled && _companyEmail != null) {
      FirebaseService.instance.syncProductToPublicMenu(_companyEmail!, newProduct.toMap());
    }

    await loadProducts();
  }

  Future<void> updateProduct(ProductModel product) async {
    await _dbHelper.updateProduct(product);
    
    // GastroQR Sync
    if (_isGastroQREnabled && _companyEmail != null) {
      FirebaseService.instance.syncProductToPublicMenu(_companyEmail!, product.toMap());
    }

    await loadProducts();
  }

  Future<String?> uploadImage(File imageFile, String productId) async {
    if (_companyEmail == null) return null;
    return await FirebaseService.instance.uploadProductImage(_companyEmail!, productId, imageFile);
  }

  Future<void> deleteProduct(String id) async {
    if (_fixedProductId == id) {
      _fixedProductId = null;
      await _saveSettings();
    }
    await _dbHelper.deleteProduct(id);
    
    // GastroQR Sync
    if (_isGastroQREnabled && _companyEmail != null) {
      FirebaseService.instance.deleteProductFromPublicMenu(_companyEmail!, id);
    }

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

  List<ProductModel> getProductsByCategory(String categoryId) {
    return _products.where((p) => p.categoryId == categoryId).toList();
  }

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
    // 1. Tarih aralığındaki kapalı siparişleri çek
    final closedOrders =
        await _dbHelper.getClosedOrdersByDateRange(startDate, endDate);

    // 2. Ürün bazlı satışları hesapla
    final Map<String, int> productSales = {};
    final Map<String, String> productNames = {};

    for (var order in closedOrders) {
      final String itemsJson = order['itemsJson'] ?? '[]';
      if (itemsJson.isNotEmpty) {
        try {
          final List<dynamic> itemsList = jsonDecode(itemsJson);
          for (var itemMap in itemsList) {
            // itemMap bir Map<String, dynamic> olmalı
            final orderItem = OrderItem.fromMap(itemMap);
            productSales[orderItem.productId] =
                (productSales[orderItem.productId] ?? 0) + orderItem.quantity;
            if (orderItem.productName.isNotEmpty) {
              productNames[orderItem.productId] = orderItem.productName;
            }
          }
        } catch (e) {
          debugPrint("Error parsing itemsJson for order ${order['id']}: $e");
        }
      }
    }

    // 3. SalesSummary listesini güncelle
    final Set<String> processedIds = {};
    final List<ProductSaleSummary> list = [];

    for (var product in _products) {
      processedIds.add(product.id);
      list.add(ProductSaleSummary(
        id: product.id,
        name: product.name,
        // Bu aralıktaki satış adedi (yoksa 0)
        salesQuantity: productSales[product.id] ?? 0,
      ));
    }

    // Siparişlerde yer alan ancak katalogda kayıtlı olmayan (özel ürünler vb.) ürünleri de ekle
    productSales.forEach((pId, qty) {
      if (!processedIds.contains(pId)) {
        list.add(ProductSaleSummary(
          id: pId,
          name: productNames[pId] ?? 'Özel Ürün',
          salesQuantity: qty,
        ));
      }
    });

    // 4. Miktara göre sırala (Çok satan en üstte)
    list.sort((a, b) => b.salesQuantity.compareTo(a.salesQuantity));
    _salesSummary = list;

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

  // ===================== GASTROQR MANAGEMENT =====================

  Future<void> toggleGastroQR(bool enabled) async {
    _isGastroQREnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGastroQREnabled', enabled);
    
    if (_companyEmail != null) {
      await FirebaseService.instance.updateGastroQRStatus(_companyEmail!, enabled);
      
      // Eğer açıldıysa tüm verileri bir kere senkronize etmeyi teklif edebiliriz 
      // veya otomatik yapabiliriz. Şimdilik sadece durumu güncelliyoruz.
    }
    
    notifyListeners();
  }

  Future<void> updateGastroQRMetadata(Map<String, dynamic> userData) async {
    if (_companyEmail == null || !_isGastroQREnabled) return;
    
    // Helper to get value with multiple potential keys
    String getVal(List<String> keys) {
      for (var key in keys) {
        final val = userData[key];
        if (val != null && val.toString().isNotEmpty) {
          return val.toString();
        }
      }
      return '';
    }

    // Normalize keys for themes
    final Map<String, dynamic> metadata = {
      'instagram': getVal(['instagramUrl', 'social_instagram_link']),
      'facebook': getVal(['facebookUrl', 'social_facebook_link']),
      'website': getVal(['websiteUrl', 'social_website_link']),
      'tiktok': getVal(['tiktokUrl', 'social_tiktok_link']),
      'twitter': getVal(['twitterUrl', 'social_twitter_link', 'xUrl']),
      'googleMaps': getVal(['googleMapsUrl', 'social_maps_link', 'location_link']),
      'mapEmbed': userData['mapEmbedCode'] ?? '',
      'companyPhone': getVal(['companyPhone', 'phone', 'userContact']),
      'address': userData['address'] ?? '',
      'companyName': userData['companyName'] ?? userData['name'] ?? '',
      'description': getVal(['description', 'desc']),
      'showProductPhotos': _showProductPhotos,
    };
    
    await FirebaseService.instance.updateGastroQRStatus(_companyEmail!, true, metadata: metadata);
  }

  Future<void> syncAllToGastroQR({Map<String, dynamic>? metadata}) async {
    if (_companyEmail == null) return;
    
    // 1. Önce şirket bilgilerini ve aktiflik durumunu güncelle (Böylece şirket dökümanı oluşur)
    await FirebaseService.instance.updateGastroQRStatus(
      _companyEmail!, 
      _isGastroQREnabled, 
      metadata: metadata
    );

    // 2. Kategorileri senkronize et
    for (var category in _categories) {
      await FirebaseService.instance.syncCategoryToPublicMenu(_companyEmail!, category.toJson());
    }
    
    // 3. Ürünleri senkronize et
    for (var product in _products) {
      await FirebaseService.instance.syncProductToPublicMenu(_companyEmail!, product.toMap());
    }
    
    debugPrint("Tüm veriler GastroQR'a senkronize edildi.");
  }

  Future<bool> updateSlug(String newSlug) async {
    if (_companyEmail == null) return false;
    
    // 1. Slug formatı kontrolü (sadece küçük harf, sayı ve tire)
    final slugRegExp = RegExp(r'^[a-z0-9-]+$');
    if (!slugRegExp.hasMatch(newSlug)) return false;

    // 2. Müsaitlik kontrolü
    bool available = await FirebaseService.instance.isSlugAvailable(newSlug);
    if (!available) return false;

    // 3. Güncelle
    await FirebaseService.instance.updateCompanySlug(_companyEmail!, newSlug);
    _companySlug = newSlug;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('companySlug', newSlug);
    
    notifyListeners();
    return true;
  }

  Future<void> updateTheme(String newThemeId) async {
    if (_companyEmail == null) return;
    
    _themeId = newThemeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeId', newThemeId);
    
    await FirebaseService.instance.updateCompanyTheme(_companyEmail!, newThemeId);
    
    notifyListeners();
  }

  Future<void> toggleProductPhotos(bool enabled) async {
    _showProductPhotos = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showProductPhotos', enabled);
    
    if (_companyEmail != null) {
      await FirebaseService.instance.updateCompanyShowPhotos(_companyEmail!, enabled);
    }
    
    notifyListeners();
  }
}
