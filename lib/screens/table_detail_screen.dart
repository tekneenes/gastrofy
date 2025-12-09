import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // FontFeature.tabularFigures için
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

class TableDetailScreen extends StatefulWidget {
  final String tableId;
  const TableDetailScreen({super.key, required this.tableId});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  TableModel? _currentTableData;
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  bool _showSalesCount = false;
  final CategoryModel _allCategory = CategoryModel(id: 'all', name: 'Tümü');
  int _currentTabControllerLength = 1;
  final ScrollController _orderListController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTableDataAndTimer(listen: false);
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      _updateTabController(productProvider.categories);
    });
  }

  @override
  void didUpdateWidget(covariant TableDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTableDataAndTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final productProvider = Provider.of<ProductProvider>(context);
    _updateTabController(productProvider.categories);
    _updateTableDataAndTimer();
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

  void _updateTableDataAndTimer({bool listen = true}) {
    if (!mounted) return;
    final tableProvider = Provider.of<TableProvider>(context, listen: listen);
    try {
      final newTableData = tableProvider.tables.firstWhere(
        (t) => t.id == widget.tableId,
        orElse: () => throw Exception("Masa bulunamadı: ${widget.tableId}"),
      );

      bool wasOccupied = _currentTableData?.isOccupied ?? false;
      bool isOccupiedNow = newTableData.isOccupied;
      bool shouldRestartTimer =
          _currentTableData?.isOccupied != newTableData.isOccupied ||
              _currentTableData?.startTime != newTableData.startTime ||
              _currentTableData == null;

      setState(() {
        _currentTableData = newTableData;
        _elapsedTime =
            (newTableData.isOccupied && newTableData.startTime != null)
                ? DateTime.now().difference(newTableData.startTime!)
                : Duration.zero;
      });

      if (wasOccupied && !isOccupiedNow) {
        _timer?.cancel();
        _timer = null;
      }

      if (shouldRestartTimer || (isOccupiedNow && _timer == null)) {
        _startOrUpdateTimer(newTableData);
      }
    } catch (e) {
      print("Masa detayı güncellenirken hata: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  void _startOrUpdateTimer(TableModel table) {
    _timer?.cancel();
    _timer = null;
    if (table.isOccupied && table.startTime != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          _timer = null;
          return;
        }
        if (_currentTableData == null ||
            !_currentTableData!.isOccupied ||
            _currentTableData!.startTime == null) {
          setState(() => _elapsedTime = Duration.zero);
          timer.cancel();
          _timer = null;
          return;
        }
        setState(() {
          _elapsedTime =
              DateTime.now().difference(_currentTableData!.startTime!);
        });
      });
    } else {
      if (mounted) {
        setState(() => _elapsedTime = Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _noteController.dispose();
    _orderListController.dispose();
    super.dispose();
  }

  // --- BUILD METOTLARI ---

  @override
  Widget build(BuildContext context) {
    return Consumer2<TableProvider, ProductProvider>(
      builder: (context, tableProvider, productProvider, child) {
        final currentTable = _currentTableData;

        if (currentTable == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Masa Yükleniyor...')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Masa bilgisi alınamadı.\nLütfen geri dönüp tekrar deneyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: _buildStyledAppBar(currentTable),
          body: Row(
            children: [
              // Sol Taraf: Sipariş Detayları
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      _buildSummaryCard(currentTable),
                      const SizedBox(height: 16),
                      _buildOrderListSection(
                          currentTable, tableProvider, productProvider),
                      const SizedBox(height: 16),
                      _buildActionButtons(currentTable),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Sağ Taraf: Ürün Listesi
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
                  child: _buildProductSection(
                      productProvider, currentTable, tableProvider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- YENİLENMİŞ WIDGET'LAR ---

  PreferredSizeWidget _buildStyledAppBar(TableModel currentTable) {
    return AppBar(
      title: Text('${currentTable.name} Detay',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
              fontSize: 24)),
      toolbarHeight: 70,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        _buildAppBarAction(
          _showSalesCount
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          _showSalesCount
              ? 'Satış Sayılarını Gizle'
              : 'Satış Sayılarını Göster',
          Colors.teal,
          () {
            if (mounted) {
              setState(() => _showSalesCount = !_showSalesCount);
              _showSnackBar(
                _showSalesCount
                    ? 'Ürün satış sayıları GÖRÜNÜYOR.'
                    : 'Ürün satış sayıları GİZLENDİ.',
              );
            }
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildSummaryCard(TableModel currentTable) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn(
                  'Geçen Süre',
                  '${_elapsedTime.inHours.toString().padLeft(2, '0')}:${(_elapsedTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                  Icons.timer_rounded,
                  Colors.deepPurple),
              _buildInfoColumn(
                  'Mevcut Ciro',
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(currentTable.totalRevenue),
                  Icons.account_balance_wallet_rounded,
                  Colors.teal),
            ],
          ),
          if (currentTable.note != null && currentTable.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildNoteDisplay(currentTable),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showNoteEditDialog(context, currentTable),
              icon: Icon(
                  currentTable.note != null && currentTable.note!.isNotEmpty
                      ? Icons.edit_note_rounded
                      : Icons.note_add_rounded,
                  size: 20,
                  color: Colors.blue.shade700),
              label: Text(
                currentTable.note != null && currentTable.note!.isNotEmpty
                    ? 'Notu Düzenle'
                    : 'Not Ekle',
                style: TextStyle(
                    color: Colors.blue.shade700, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
      String title, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color.withOpacity(0.8), size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteDisplay(TableModel currentTable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_rounded,
              size: 22, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentTable.note!,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.brown.shade800,
                  fontStyle: FontStyle.italic,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListSection(TableModel currentTable,
      TableProvider tableProvider, ProductProvider productProvider) {
    return Expanded(
      child: currentTable.orders.isEmpty
          ? _buildEmptyOrderState()
          : Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04), blurRadius: 10)
                  ]),
              child: ListView.builder(
                controller: _orderListController,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: currentTable.orders.length,
                itemBuilder: (context, index) {
                  if (index < 0 || index >= currentTable.orders.length) {
                    return const SizedBox.shrink();
                  }
                  final orderItem = currentTable.orders[index];
                  return _buildOrderItem(orderItem, currentTable, tableProvider,
                      productProvider, index);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyOrderState() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Bu masada henüz sipariş yok.',
            style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Sağdaki menüden ürün ekleyebilirsiniz.',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    ));
  }

  Widget _buildOrderItem(OrderItem orderItem, TableModel currentTable,
      TableProvider tableProvider, ProductProvider productProvider, int index) {
    final color = Colors.primaries[index % Colors.primaries.length];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border(left: BorderSide(color: color, width: 5)),
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
                      orderItem.productName,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(orderItem.productPrice)} x ${orderItem.quantity}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                          .format(orderItem.productPrice * orderItem.quantity),
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
                  final bool isLastItemOnTable =
                      currentTable.orders.length == 1 &&
                          orderItem.quantity == 1;

                  tableProvider.decrementOrderItem(currentTable.id, orderItem);

                  if (!orderItem.isSpecialProduct) {
                    productProvider.incrementProductSalesCount(
                        orderItem.productId, -1);
                  }

                  if (isLastItemOnTable) {
                    tableProvider.clearTable(currentTable.id,
                        addToRevenue: false);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Text(
                  '${orderItem.quantity}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              _buildQuantityButton(
                icon: Icons.add,
                color: Colors.green.shade500,
                onTap: () {
                  tableProvider.incrementOrderItem(currentTable.id, orderItem);
                  if (!orderItem.isSpecialProduct) {
                    productProvider.incrementProductSalesCount(
                        orderItem.productId, 1);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildActionButtons(TableModel currentTable) {
    return Row(
      children: [
        Expanded(
          child: _buildStyledButton(
            text: 'Veresiyeye Ekle',
            icon: Icons.book_online_rounded,
            color: Colors.blue.shade600,
            isEnabled: currentTable.orders.isNotEmpty,
            onPressed: () =>
                _showVeresiyeConfirmationDialog(context, currentTable),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStyledButton(
            text: 'Hesabı Kapat',
            icon: Icons.payment_rounded,
            color: Colors.red.shade500,
            isEnabled: currentTable.orders.isNotEmpty,
            onPressed: () => _showPaymentConfirmationDialog(
                context, currentTable, _elapsedTime),
          ),
        ),
      ],
    );
  }

  Widget _buildStyledButton({
    required String text,
    required IconData icon,
    required Color color,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: isEnabled ? onPressed : null,
      icon: Icon(icon, color: Colors.white, size: 22),
      label: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.grey.shade400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 18),
        elevation: 4,
        shadowColor: isEnabled ? color.withOpacity(0.4) : Colors.transparent,
      ),
    );
  }

  Widget _buildProductSection(ProductProvider productProvider,
      TableModel currentTable, TableProvider tableProvider) {
    List<CategoryModel> categoryList = [
      _allCategory,
      ...productProvider.categories
    ];
    final allProducts = productProvider.products;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // *** UI DÜZELTME: KATEGORİ SEKMELERİ YENİLENDİ ***
          // Daha modern, arka planlı ve buton görünümlü (Pill/Chip tarzı) sekmeler
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              // remove divider
              dividerColor: Colors.transparent,
              // Indicator tasarımı: Beyaz kutu, gölge ve yuvarlatılmış köşeler
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.deepPurple.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              // Tab elemanları
              tabs: categoryList
                  .map((category) => Tab(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          child: Text(category.name),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // *** KATEGORİ SEKMELERİ BİTİŞ ***

          const SizedBox(height: 12),
          _buildProductActionButtons(productProvider, currentTable),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: categoryList.map((category) {
                final filteredProducts = (category.id == 'all')
                    ? allProducts
                    : allProducts
                        .where((p) => p.categoryId == category.id)
                        .toList();
                return _buildProductList(
                    context, filteredProducts, currentTable, category);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductActionButtons(
      ProductProvider productProvider, TableModel currentTable) {
    // Öne çıkanlar butonu kaldırıldı, sadece Özel Ürün Ekle kaldı
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAddSpecialProductDialog(context, currentTable),
        icon: Icon(Icons.add_shopping_cart_rounded,
            size: 20, color: Colors.purple.shade600),
        label: Text(
          'Listede Olmayan Özel Ürün Ekle',
          style: TextStyle(
            color: Colors.purple.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.purple.shade200, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.purple.shade50.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<ProductModel> products,
      TableModel currentTable, CategoryModel currentCategory) {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);

    String getCategoryName(String categoryId) {
      if (categoryId.isEmpty) return 'Belirtilmemiş';
      try {
        return productProvider.categories
            .firstWhere((c) => c.id == categoryId)
            .name;
      } catch (e) {
        return 'Diğer';
      }
    }

    // *** MANTIK DÜZELTME: Öne Çıkanlar Mantığı Kaldırıldı ***
    // Sadece alfabetik sıralama ve sabitlenen ürün mantığı kaldı.
    List<ProductModel> productsToDisplay = List.from(products);

    // Eğer "Tümü" seçiliyse isme göre sırala
    if (currentCategory.id == 'all') {
      productsToDisplay.sort((a, b) => a.name.compareTo(b.name));
    }

    if (productProvider.fixedProductId != null) {
      ProductModel? fixedProduct;
      try {
        fixedProduct = productsToDisplay.firstWhere(
          (p) => p.id == productProvider.fixedProductId,
        );
        productsToDisplay.remove(fixedProduct);
        productsToDisplay.insert(0, fixedProduct);
      } catch (e) {
        // Sabitlenen ürün bu listede yoksa yoksay
      }
    }

    if (productsToDisplay.isEmpty) {
      return const Center(
        child: Text('Bu kategoride ürün bulunmamaktadır.',
            style: TextStyle(fontSize: 16, color: Colors.black54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: productsToDisplay.length,
      itemBuilder: (context, index) {
        final product = productsToDisplay[index];
        final isFixed = productProvider.fixedProductId == product.id;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          elevation: isFixed ? 3 : 1,
          shadowColor: isFixed
              ? Colors.blue.withOpacity(0.3)
              : Colors.black.withOpacity(0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isFixed ? Colors.blue[50] : Colors.grey.shade50,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(product.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(product.price),
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                if (_showSalesCount)
                  Text(
                    'Satış: ${product.salesCount} | Kategori: ${getCategoryName(product.categoryId)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: isFixed
                ? Icon(Icons.push_pin_rounded,
                    color: Colors.blue.shade600, size: 22)
                : null, // Yıldız ikonu kaldırıldı
            onTap: () {
              final newOrderItem = OrderItem(
                orderId: 0,
                productId: product.id,
                productName: product.name,
                productPrice: product.price,
                quantity: 1,
                isSpecialProduct: false,
              );

              tableProvider.addOrUpdateOrder(currentTable.id, newOrderItem);
              productProvider.incrementProductSalesCount(product.id, 1);

              if (_orderListController.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_orderListController.hasClients) {
                    _orderListController.animateTo(
                      _orderListController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
            },
            onLongPress: () {
              productProvider.toggleFixedProduct(product.id);
              _showSnackBar(
                productProvider.fixedProductId == product.id
                    ? '${product.name} sabitlendi.'
                    : '${product.name} sabitlemesi kaldırıldı.',
              );
            },
          ),
        );
      },
    );
  }

  // --- HELPER METOTLARI ---

  Widget _buildAppBarAction(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 26, color: color),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
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
            isSuccess ? Colors.teal.shade600 : const Color(0xFF1A1A2E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  // --- DİYALOG METOTLARI ---

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

  void _showNoteEditDialog(BuildContext context, TableModel currentTable) {
    _noteController.text = currentTable.note ?? '';
    _showStyledDialog(
      context: context,
      title: 'Masa Notu Ekle/Düzenle',
      icon: Icons.edit_note_rounded,
      iconColor: Colors.amber.shade600,
      content: TextField(
        controller: _noteController,
        maxLines: 4,
        maxLength: 150,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: 'Masa ile ilgili önemli bir not girin...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.amber.shade700, width: 2)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            if (!mounted) return;
            final newNote = _noteController.text.trim();
            try {
              Provider.of<TableProvider>(context, listen: false)
                  .updateTableNote(
                      currentTable.id, newNote.isEmpty ? null : newNote);
              Navigator.of(context).pop();
              _showSnackBar('Masa notu kaydedildi.', isSuccess: true);
            } catch (e) {
              print("Not güncellenirken hata: $e");
              _showSnackBar('Not kaydedilirken bir hata oluştu.');
            }
          },
          child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showPaymentConfirmationDialog(
      BuildContext context, TableModel currentTable, Duration elapsedTime) {
    _showStyledDialog(
        context: context,
        title: 'Hesabı Kapat ve Masayı Temizle',
        icon: Icons.payment_rounded,
        iconColor: Colors.red.shade500,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Bu masanın hesabını kapatmak istediğinizden emin misiniz? Bu işlem ciroya eklenecektir.'),
            const SizedBox(height: 16),
            Center(
              child: Text(
                NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                    .format(currentTable.totalRevenue),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ),
          ],
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
            onPressed: () async {
              if (!mounted) return;

              TableProvider tableProvider;
              try {
                tableProvider =
                    Provider.of<TableProvider>(context, listen: false);
              } catch (e) {
                print("Provider alınamadı: $e");
                _showSnackBar('İşlem sırasında bir hata oluştu.');
                return;
              }

              final itemsJson = jsonEncode(
                  currentTable.orders.map((item) => item.toMap()).toList());

              try {
                await DatabaseHelper.instance.saveClosedTable(
                  tableId: currentTable.id,
                  tableName: currentTable.name,
                  totalRevenue: currentTable.totalRevenue,
                  startTime: currentTable.startTime ??
                      DateTime.now().subtract(elapsedTime),
                  endTime: DateTime.now(),
                  elapsedTime: elapsedTime.inSeconds,
                  note: currentTable.note,
                  itemsJson: itemsJson,
                );

                await tableProvider.clearTable(currentTable.id);

                _timer?.cancel();
                _timer = null;

                if (mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Hesap kapatıldı ve ciro eklendi.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
              } catch (e) {
                print("Hesap kapatma hatası: $e");
                if (mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  _showSnackBar('Hata: Hesap kapatma başarısız oldu.');
                }
              }
            },
            child: const Text('Hesabı Kapat',
                style: TextStyle(color: Colors.white)),
          ),
        ]);
  }

  void _showVeresiyeConfirmationDialog(
      BuildContext context, TableModel currentTable) {
    final TextEditingController customerNameController =
        TextEditingController();
    _showStyledDialog(
        context: context,
        title: 'Veresiye Defterine Ekle',
        icon: Icons.book_online_rounded,
        iconColor: Colors.blue.shade600,
        content: Column(
          children: [
            const Text(
                'Bu hesap veresiye defterine eklenecek ve masa temizlenecektir. Bu tutar günlük ciroya eklenmez.'),
            const SizedBox(height: 16),
            TextField(
              controller: customerNameController,
              decoration: InputDecoration(
                labelText: 'Başlık / Müşteri Adı',
                hintText: 'örn: Ahmet Yılmaz',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (!mounted) return;

              TableProvider tableProvider;
              try {
                tableProvider =
                    Provider.of<TableProvider>(context, listen: false);
              } catch (e) {
                print("Provider alınamadı: $e");
                _showSnackBar('İşlem sırasında bir hata oluştu.');
                return;
              }

              final customerName = customerNameController.text.trim().isEmpty
                  ? currentTable.name
                  : customerNameController.text.trim();

              final itemsJson = jsonEncode(
                  currentTable.orders.map((item) => item.toMap()).toList());

              try {
                await DatabaseHelper.instance.saveAsVeresiye(
                  customerName: customerName,
                  totalAmount: currentTable.totalRevenue,
                  itemsJson: itemsJson,
                  note: currentTable.note,
                );

                await tableProvider.clearTable(currentTable.id,
                    addToRevenue: false);

                _timer?.cancel();
                _timer = null;

                if (mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Hesap veresiye defterine eklendi.'),
                      backgroundColor: Colors.blue,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
              } catch (e) {
                print("Veresiye ekleme hatası: $e");
                if (mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  _showSnackBar('Hata: Veresiyeye ekleme başarısız oldu.');
                }
              }
            },
            child: const Text('Veresiyeye Ekle',
                style: TextStyle(color: Colors.white)),
          ),
        ]);
  }

  void _showAddSpecialProductDialog(
      BuildContext context, TableModel currentTable) {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    _showStyledDialog(
      context: context,
      title: 'Özel Ürün Ekle',
      icon: Icons.add_shopping_cart_rounded,
      iconColor: Colors.purple.shade500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: 'Ürün Adı (örn: Çilekli Pasta)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: 'Fiyat (örn: 15.50)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              prefixText: '₺ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade500,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (!mounted) return;

            final price =
                double.tryParse(priceController.text.replaceAll(',', '.'));
            final name = nameController.text.trim().isEmpty
                ? 'Özel Ürün'
                : nameController.text.trim();

            if (price != null && price > 0) {
              final newSpecialItem = OrderItem(
                orderId: 0,
                productId: const Uuid().v4(),
                productName: name,
                productPrice: price,
                quantity: 1,
                isSpecialProduct: true,
              );
              try {
                Provider.of<TableProvider>(context, listen: false)
                    .addOrUpdateOrder(currentTable.id, newSpecialItem);

                Navigator.of(context).pop();
              } catch (e) {
                print("Özel ürün eklenirken hata: $e");
                _showSnackBar('Özel ürün eklenirken bir hata oluştu.');
              }
            } else {
              _showSnackBar('Lütfen geçerli bir pozitif fiyat girin.');
            }
          },
          child: const Text('Ekle', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
