import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../models/order_item_model.dart';
import '../models/product_model.dart';
import '../models/table_model.dart';
import '../providers/product_provider.dart';
import '../providers/table_provider.dart';
import '../services/database_helper.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class QuickSaleScreen extends StatefulWidget {
  final Map<String, dynamic>? loggedInUser;
  final String? userRole;

  const QuickSaleScreen({
    super.key,
    this.loggedInUser,
    this.userRole,
  });

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen>
    with TickerProviderStateMixin {
  late TableModel _tempTable;
  late TabController _tabController;
  bool _showChangeCalculator = true;
  final CategoryModel _allCategory = CategoryModel(id: 'all', name: 'Tümü');
  int _currentTabControllerLength = 1;
  final ScrollController _orderListController = ScrollController();

  late String _userRole;
  final TextEditingController _receivedAmountController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _userRole = widget.loggedInUser?['userRole'] ?? widget.userRole ?? 'Garson';
    
    // Initialize a blank temporary table
    _tempTable = TableModel(
      id: 'QUICK_SALE',
      name: 'Hızlı Satış',
      position: 0,
      isOccupied: true,
      startTime: DateTime.now(),
    );

    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      _updateTabController(productProvider.categories);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final productProvider = Provider.of<ProductProvider>(context);
    _updateTabController(productProvider.categories);
  }

  void _updateTabController(List<CategoryModel> currentCategories) {
    final newLength = currentCategories.length + 1;
    if (newLength == _currentTabControllerLength) return;
    final oldIndex = _tabController.index;
    if (!mounted) return;
    _tabController.dispose();
    _tabController = TabController(length: newLength, vsync: this);
    _currentTabControllerLength = newLength;
    _tabController.index = (oldIndex < newLength) ? oldIndex : 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderListController.dispose();
    _receivedAmountController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TableProvider, ProductProvider>(
      builder: (context, tableProvider, productProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: _buildStyledAppBar(),
          body: Row(
            children: [
              // Left side: Order details
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      _buildQuickSaleHeader(),
                      const SizedBox(height: 16),
                      _buildOrderListSection(productProvider),
                      if (_showChangeCalculator) ...[
                        const SizedBox(height: 16),
                        _buildChangeCalculationSection(),
                      ],
                      const SizedBox(height: 16),
                      _buildActionButtons(tableProvider),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Right side: Product selection
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildProductSection(productProvider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildStyledAppBar() {
    return AppBar(
      title: const Text('Hızlı Satış',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
              fontSize: 24)),
      toolbarHeight: 70,
      leadingWidth: 70,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      leading: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Color(0xFF1A1A2E)),
              ),
            ),
          ),
        ),
      ),
      actions: [
        _buildAppBarAction(
          _showChangeCalculator
              ? Icons.calculate_rounded
              : Icons.calculate_outlined,
          _showChangeCalculator ? 'Gizle' : 'Göster',
          _showChangeCalculator ? Colors.blue : Colors.grey,
          () {
            setState(() => _showChangeCalculator = !_showChangeCalculator);
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildAppBarAction(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            borderRadius: BorderRadius.circular(14),
            splashColor: color.withOpacity(0.2),
            highlightColor: color.withOpacity(0.1),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.12), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.35), width: 1.5),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSaleHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toplam Tutar',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                    .format(_tempTable.totalRevenue),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  'Hızlı Satış',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListSection(ProductProvider productProvider) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sipariş Listesi',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.purple),
                    onPressed: () => _showAddSpecialProductDialog(),
                    tooltip: 'Özel Ürün Ekle',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tempTable.orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_basket_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Henüz ürün eklenmedi',
                              style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _orderListController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _tempTable.orders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderItem(_tempTable.orders[index], index, productProvider);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item, int index, ProductProvider productProvider) {
    const color = Colors.teal;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: const Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(item.productPrice)} x ${item.quantity}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                          .format(item.productPrice * item.quantity),
                      style: TextStyle(
                          fontSize: 16,
                          color: color.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              _buildQuantityButton(
                icon: Icons.remove,
                color: Colors.red.shade400,
                onTap: () {
                  setState(() {
                    if (item.quantity > 1) {
                      item.quantity--;
                    } else {
                      _tempTable.orders.removeAt(index);
                    }
                    _recalculateTotal();
                  });
                  if (!item.isSpecialProduct) {
                    productProvider.incrementProductSalesCount(item.productId, -1);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _buildQuantityButton(
                icon: Icons.add,
                color: Colors.green.shade500,
                onTap: () {
                  setState(() {
                    item.quantity++;
                    _recalculateTotal();
                  });
                  if (!item.isSpecialProduct) {
                    productProvider.incrementProductSalesCount(item.productId, 1);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recalculateTotal() {
    _tempTable.totalRevenue = _tempTable.orders
        .fold(0.0, (sum, item) => sum + (item.productPrice * item.quantity));
  }

  Widget _buildQuantityButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildProductSection(ProductProvider productProvider) {
    final categories = productProvider.categories;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade700,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: [
            const Tab(text: 'Tümü'),
            ...categories.map((c) => Tab(text: c.name)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductList(productProvider.products, productProvider),
              ...categories.map((c) => _buildProductList(
                  productProvider.getProductsByCategory(c.id),
                  productProvider)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductList(List<ProductModel> products, ProductProvider productProvider) {
    if (products.isEmpty) {
      return const Center(child: Text('Bu kategoride ürün bulunamadı.'));
    }

    final List<ProductModel> productsToDisplay = List.from(products);
    productsToDisplay.sort((a, b) {
      if (productProvider.fixedProductId == a.id) return -1;
      if (productProvider.fixedProductId == b.id) return 1;
      return 0;
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: productsToDisplay.length,
      itemBuilder: (context, index) {
        final product = productsToDisplay[index];
        final isFixed = productProvider.fixedProductId == product.id;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isFixed
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: isFixed
                ? Border.all(color: Colors.blue.shade200, width: 1.5)
                : null,
          ),
          child: InkWell(
            onTap: () {
              bool itemExists = false;
              setState(() {
                for (var item in _tempTable.orders) {
                  if (item.productId == product.id && !item.isSpecialProduct) {
                    item.quantity++;
                    itemExists = true;
                    break;
                  }
                }
                if (!itemExists) {
                  _tempTable.orders.add(OrderItem(
                    orderId: 0,
                    productId: product.id,
                    productName: product.name,
                    productPrice: product.price,
                    quantity: 1,
                    isSpecialProduct: false,
                  ));
                }
                _recalculateTotal();
              });
              productProvider.incrementProductSalesCount(product.id, 1);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isFixed ? Colors.blue.shade100 : Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        product.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.trending_up_rounded, size: 14, color: Colors.blue.shade400),
                            const SizedBox(width: 4),
                            Text('${product.salesCount} Satış', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text(NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(product.price),
                        style: TextStyle(fontSize: 15, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChangeCalculationSection() {
    // Controller'dan alınan anlık veri
    final rawText = _receivedAmountController.text.trim().replaceAll(',', '.');
    final received = double.tryParse(rawText) ?? 0.0;
    final isInputEmpty = _receivedAmountController.text.isEmpty;
    final change = isInputEmpty ? 0.0 : (received - _tempTable.totalRevenue);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.teal.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Para Üstü Hesapla",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Toplam: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(_tempTable.totalRevenue)}",
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _receivedAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  cursorColor: Colors.teal,
                  decoration: InputDecoration(
                    labelText: "Alınan Tutar",
                    hintText: "0.00",
                    prefixIcon:
                        const Icon(Icons.payments_outlined, color: Colors.teal),
                    suffixIcon: _receivedAmountController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _receivedAmountController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.teal, width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Para Üstü",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                            .format(change < 0 ? 0 : change),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isInputEmpty
                              ? Colors.grey.shade400
                              : (change >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hızlı Ödeme Butonları (Kaydırılabilir)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Tam Hesap Butonu
                _buildQuickAmountButton("Tam Hesap", _tempTable.totalRevenue),
                const SizedBox(width: 8),
                // Diğer Banknotlar ve Sık Kullanılan Tutarlar
                ...[200, 150, 140, 120, 100, 90, 80, 70, 60, 50, 45, 40, 30, 25, 20, 10, 5].map((amount) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildQuickAmountButton(
                          "₺$amount", amount.toDouble()),
                    )),
              ],
            ),
          ),
          if (change < 0 && !isInputEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Alınan tutar eksik: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(change.abs())}",
                        style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, double value) {
    return InkWell(
      onTap: () {
        _receivedAmountController.text = value.toStringAsFixed(2);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: Colors.teal.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildActionButtons(TableProvider tableProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildStyledButton(
            text: 'İptal Et',
            icon: Icons.close_rounded,
            color: Colors.grey,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStyledButton(
            text: 'Satışı Tamamla',
            icon: Icons.check_circle_rounded,
            color: Colors.green.shade600,
            onPressed: () => _completeSale(tableProvider),
          ),
        ),
      ],
    );
  }

  void _completeSale(TableProvider tableProvider) async {
    if (_tempTable.orders.isEmpty) {
      _showSnackBar('Lütfen en az bir ürün ekleyin.');
      return;
    }

    final itemsJson = jsonEncode(_tempTable.orders.map((item) => item.toMap()).toList());

    try {
      await DatabaseHelper.instance.saveClosedTable(
        tableId: 'QUICK_SALE',
        tableName: 'Hızlı Satış',
        totalRevenue: _tempTable.totalRevenue,
        startTime: _tempTable.startTime!,
        endTime: DateTime.now(),
        elapsedTime: DateTime.now().difference(_tempTable.startTime!).inSeconds,
        itemsJson: itemsJson,
      );

      await tableProvider.addRevenueFromVeresiye(_tempTable.totalRevenue);

      // LOG: Hızlı Satış Tamamlandı
      await tableProvider.addLog(
        user: widget.loggedInUser ?? {'userName': 'Bilinmeyen'},
        actionType: 'Ödeme',
        details: 'Hızlı Satış tamamlandı: ${_tempTable.totalRevenue.toStringAsFixed(2)} TL',
      );

      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Hızlı satış tamamlandı.', isSuccess: true);
      }
    } catch (e) {
      _showSnackBar('Satış tamamlanırken hata oluştu.');
    }
  }

  Widget _buildStyledButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showAddSpecialProductDialog() {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özel Ürün Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Ürün Adı')),
            const SizedBox(height: 10),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Fiyat')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null) {
                setState(() {
                  _tempTable.orders.add(OrderItem(
                    orderId: 0,
                    productId: const Uuid().v4(),
                    productName: nameController.text.isEmpty ? 'Özel' : nameController.text,
                    productPrice: price,
                    quantity: 1,
                    isSpecialProduct: true,
                  ));
                  _recalculateTotal();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
