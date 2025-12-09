import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/product_model.dart';
import '../models/category_model.dart';
import '../providers/product_provider.dart';
import '../services/menu_generator_service.dart';
import 'html_preview_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen>
    with SingleTickerProviderStateMixin {
  // Controller'lar
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController();

  String? _selectedCategoryId;
  late TabController _tabController;

  // Yeni Menü Özelliği İçin Alanlar
  final MenuGeneratorService _menuService = MenuGeneratorService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Ürün & Kategori Yönetimi',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,

        // Menü Oluşturma Butonu
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: Icon(Icons.menu_book_rounded,
                  color: Colors.deepPurple.shade600, size: 30),
              tooltip: 'Menü Oluştur',
              onPressed:
                  _isLoading ? null : () => _showMenuGeneratorDialog(context),
            ),
          ),
        ],

        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.deepPurple.shade50,
          ),
          indicatorPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          labelColor: Colors.deepPurple.shade700,
          unselectedLabelColor: Colors.grey[600],
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.inventory_2_rounded),
                  SizedBox(width: 8),
                  Text('Ürünler')
                ])),
            Tab(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.folder_special_rounded),
                  SizedBox(width: 8),
                  Text('Kategoriler')
                ])),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 16),
                  Text('İşlem yapılıyor, lütfen bekleyin...',
                      style: TextStyle(fontSize: 16, color: Colors.deepPurple)),
                ],
              ),
            )
          : Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductListTab(productProvider),
                    _buildCategoryListTab(productProvider),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading
            ? null
            : () {
                if (_tabController.index == 0) {
                  _showAddEditProductDialog();
                } else {
                  _showAddEditCategoryDialog();
                }
              },
        label: Text(
          _tabController.index == 0 ? 'Yeni Ürün Ekle' : 'Yeni Kategori Ekle',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: _tabController.index == 0
            ? Colors.teal.shade500
            : Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // --- MENÜ OLUŞTURMA METOTLARI ---

  void _showMenuGeneratorDialog(BuildContext context) {
    _showStyledDialog(
      context: context,
      title: 'Menü Oluştur',
      icon: Icons.design_services_rounded,
      iconColor: Colors.deepPurple.shade600,
      content: const Text(
        'Mevcut ürün ve kategorilerinizle otomatik bir PDF menüsü oluşturmak üzeresiniz.\n\nDevam etmek istiyor musunuz?',
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            Navigator.of(context).pop();
            _generateAndExportMenu(context);
          },
          child: const Text('Oluştur & Önizle',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _generateAndExportMenu(BuildContext context) async {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    if (productProvider.products.isEmpty) {
      _showSnackBar('Lütfen önce ürün ekleyin.', isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Varsayılan şablonu kullan
    final template = defaultMenuTemplate;

    final finalHtmlContent = _menuService.generateMenuHtml(
        template, productProvider.products, productProvider.categories);

    await _menuService.exportToPdfAndPreview(context, finalHtmlContent);

    setState(() {
      _isLoading = false;
    });

    _showSnackBar('Menü başarıyla oluşturuldu ve önizleme ekranı açıldı.',
        isSuccess: true);
  }

  // --- LİSTE SEKME İÇERİKLERİ ---

  Widget _buildProductListTab(ProductProvider productProvider) {
    if (productProvider.products.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Henüz Ürün Eklenmedi',
        subtitle: 'Yeni bir ürün eklemek için + butonuna tıklayın.',
      );
    }

    final Map<String, List<ProductModel>> productsByCategory = {};
    for (var product in productProvider.products) {
      final categoryName = productProvider.categories
          .firstWhere(
            (c) => c.id == product.categoryId,
            orElse: () => CategoryModel(id: '', name: 'Kategorisiz'),
          )
          .name;
      if (!productsByCategory.containsKey(categoryName)) {
        productsByCategory[categoryName] = [];
      }
      productsByCategory[categoryName]!.add(product);
    }

    final sortedCategoryNames = productsByCategory.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: sortedCategoryNames.length,
      itemBuilder: (context, categoryIndex) {
        final categoryName = sortedCategoryNames[categoryIndex];
        final products = productsByCategory[categoryName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10.0, left: 8.0, bottom: 8.0),
              child: Text(
                categoryName,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
              ),
            ),
            ...products.map((product) => _buildProductItemCard(product)),
          ],
        );
      },
    );
  }

  Widget _buildCategoryListTab(ProductProvider productProvider) {
    if (productProvider.categories.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_off_outlined,
        title: 'Henüz Kategori Eklenmedi',
        subtitle: 'Yeni bir kategori eklemek için + butonuna tıklayın.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: productProvider.categories.length,
      itemBuilder: (context, index) {
        final category = productProvider.categories[index];
        return _buildCategoryItemCard(category, productProvider);
      },
    );
  }

  // --- KART TASARIMLARI ---

  Widget _buildProductItemCard(ProductModel product) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.fastfood_rounded,
                  color: Colors.teal.shade600, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Satış Sayısı: ${product.salesCount}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                  .format(product.price),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700),
            ),
            const SizedBox(width: 8),
            _buildPopupMenuButton(product),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItemCard(
      CategoryModel category, ProductProvider provider) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.folder_special_rounded,
              color: Colors.orange.shade700, size: 28),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: _buildCategoryPopupMenuButton(category, provider),
      ),
    );
  }

  PopupMenuButton<String> _buildPopupMenuButton(ProductModel product) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          _showAddEditProductDialog(product: product);
        } else if (value == 'delete') {
          _showDeleteConfirmationDialog(
              context: context,
              title: 'Ürün Silme Onayı',
              content:
                  '${product.name} ürününü silmek istediğinizden emin misiniz?',
              onConfirm: () {
                Provider.of<ProductProvider>(context, listen: false)
                    .deleteProduct(product.id);
                Navigator.of(context).pop();
                _showSnackBar('${product.name} ürünü silindi.');
              });
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_rounded),
            title: Text('Düzenle'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_rounded),
            title: Text('Sil'),
          ),
        ),
      ],
    );
  }

  PopupMenuButton<String> _buildCategoryPopupMenuButton(
      CategoryModel category, ProductProvider provider) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          _showAddEditCategoryDialog(category: category);
        } else if (value == 'delete') {
          _showDeleteConfirmationDialog(
            context: context,
            title: 'Kategori Silme Onayı',
            content:
                '${category.name} kategorisini silmek istediğinizden emin misiniz? Bu kategoriye ait ürünler "Kategorisiz" olarak işaretlenecektir.',
            onConfirm: () {
              provider.deleteCategory(category.id);
              Navigator.of(context).pop();
              _showSnackBar('${category.name} kategorisi silindi.');
            },
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_rounded),
            title: Text('Düzenle'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_rounded),
            title: Text('Sil'),
          ),
        ),
      ],
    );
  }

  // --- DİYALOG METOTLARI ---

  void _showAddEditProductDialog({ProductModel? product}) {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    _nameController.text = product?.name ?? '';
    _priceController.text =
        product != null ? product.price.toStringAsFixed(2) : '';
    _selectedCategoryId = product?.categoryId;

    _showStyledDialog(
      context: context,
      title: product == null ? 'Yeni Ürün Ekle' : 'Ürünü Düzenle',
      icon: Icons.fastfood_rounded,
      iconColor: Colors.teal.shade500,
      content: StatefulBuilder(builder: (context, setStateSB) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStyledTextField(
              controller: _nameController,
              labelText: 'Ürün Adı',
              hintText: 'Örn: Hamburger',
            ),
            const SizedBox(height: 16),
            _buildStyledTextField(
              controller: _priceController,
              labelText: 'Fiyat',
              hintText: 'Örn: 150.00',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: _styledInputDecoration('Kategori'),
              hint: const Text('Bir kategori seçin'),
              value: _selectedCategoryId,
              items: productProvider.categories.map((category) {
                return DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setStateSB(() => _selectedCategoryId = newValue);
              },
              validator: (value) =>
                  value == null ? 'Lütfen bir kategori seçin.' : null,
            ),
          ],
        );
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade500,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            final name = _nameController.text.trim();
            final price = double.tryParse(_priceController.text);
            if (name.isNotEmpty &&
                price != null &&
                price > 0 &&
                _selectedCategoryId != null) {
              if (product == null) {
                productProvider.addProduct(name, price, _selectedCategoryId!);
              } else {
                product.name = name;
                product.price = price;
                product.categoryId = _selectedCategoryId!;
                productProvider.updateProduct(product);
              }
              Navigator.of(context).pop();
              _nameController.clear();
              _priceController.clear();
              _selectedCategoryId = null;
              _showSnackBar(
                  product == null
                      ? 'Ürün başarıyla eklendi.'
                      : 'Ürün güncellendi.',
                  isSuccess: true);
            } else {
              _showSnackBar('Lütfen tüm alanları doğru bir şekilde doldurun.');
            }
          },
          child: Text(product == null ? 'Ekle' : 'Güncelle',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showAddEditCategoryDialog({CategoryModel? category}) {
    _categoryNameController.text = category?.name ?? '';
    _showStyledDialog(
      context: context,
      title: category == null ? 'Yeni Kategori Ekle' : 'Kategoriyi Düzenle',
      icon: Icons.folder_special_rounded,
      iconColor: Colors.orange.shade600,
      content: _buildStyledTextField(
        controller: _categoryNameController,
        labelText: 'Kategori Adı',
        hintText: 'Örn: Tatlılar',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            final name = _categoryNameController.text.trim();
            if (name.isNotEmpty) {
              final productProvider =
                  Provider.of<ProductProvider>(context, listen: false);
              if (category == null) {
                productProvider.addCategory(name);
              } else {
                category.name = name;
                productProvider.updateCategory(category);
              }
              Navigator.of(context).pop();
              _categoryNameController.clear();
              _showSnackBar(
                  category == null
                      ? 'Kategori başarıyla eklendi.'
                      : 'Kategori güncellendi.',
                  isSuccess: true);
            } else {
              _showSnackBar('Lütfen geçerli bir kategori adı girin.');
            }
          },
          child: Text(category == null ? 'Ekle' : 'Güncelle',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // --- HELPER METOTLARI ---

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
                fontSize: 22,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showStyledDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required List<Widget> actions,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [iconColor.withOpacity(0.8), iconColor],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 58, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 20),
                content,
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    _showStyledDialog(
      context: context,
      title: title,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red.shade500,
      content: Text(
        content,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: onConfirm,
          child: const Text('Sil', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildStyledTextField(
      {required TextEditingController controller,
      required String labelText,
      String? hintText,
      TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _styledInputDecoration(labelText, hintText: hintText),
    );
  }

  InputDecoration _styledInputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(
          color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.deepPurple.shade400, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor:
            isSuccess ? Colors.teal.shade600 : Colors.redAccent.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
