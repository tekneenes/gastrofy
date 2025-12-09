import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/database_helper.dart';
import '../models/order_item_model.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  TableModel? _selectedTable;
  ProductModel? _selectedProduct;
  int _quantity = 1;

  List<TableModel> _tables = [];
  List<ProductModel> _products = [];
  List<OrderItem> _orderItems = [];
  OrderModel? _activeOrder;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tables = await DatabaseHelper.instance.getTables();
    final products = await DatabaseHelper.instance.getProducts();
    setState(() {});
  }

  Future<void> _startOrder() async {
    if (_selectedTable == null) return;

    final now = DateTime.now();
    final newOrder = OrderModel(
      tableId: _selectedTable!.id,
      createdAt: now,
      orders: [],
    );

    _activeOrder = await DatabaseHelper.instance
        .insertMainOrder(newOrder); // ✅ veritabanına yaz

    _orderItems = [];
    setState(() {});
  }

  Future<void> _addItemToOrder() async {
    if (_activeOrder == null || _selectedProduct == null) return;

    final item = OrderItem(
      orderId: _activeOrder!.id!,
      productId: _selectedProduct!.id!,
      productName: _selectedProduct!.name,
      productPrice: _selectedProduct!.price,
      quantity: _quantity,
    );

    await DatabaseHelper.instance.insertOrderItem(item);
    _orderItems =
        await DatabaseHelper.instance.getOrderItemsForOrder(_activeOrder!.id!);
    setState(() {});
  }

  Future<void> _endOrder() async {
    _activeOrder = null;
    _orderItems = [];
    _selectedProduct = null;
    _selectedTable = null;
    _quantity = 1;
    setState(() {});
  }

  Widget _buildDropdown<T>(
      String label, T? selected, List<T> items, ValueChanged<T?> onChanged) {
    return DropdownButtonFormField<T>(
      value: selected,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item.toString()),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sipariş Yönetimi")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDropdown<TableModel>(
              "Masa Seç",
              _selectedTable,
              _tables,
              (value) => setState(() => _selectedTable = value),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _startOrder,
              child: const Text("Sipariş Başlat"),
            ),
            const Divider(height: 32),
            if (_activeOrder != null) ...[
              _buildDropdown<ProductModel>(
                "Ürün Seç",
                _selectedProduct,
                _products,
                (value) => setState(() => _selectedProduct = value),
              ),
              TextFormField(
                initialValue: '1',
                decoration: const InputDecoration(labelText: "Adet"),
                keyboardType: TextInputType.number,
                onChanged: (value) => _quantity = int.tryParse(value) ?? 1,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _addItemToOrder,
                child: const Text("Ürün Ekle"),
              ),
              const Divider(height: 32),
              const Text("Sipariş Detayı",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _orderItems.length,
                  itemBuilder: (_, index) {
                    final item = _orderItems[index];
                    return ListTile(
                      title: Text(item.productName),
                      subtitle: Text("Adet: \${item.quantity}"),
                      trailing: Text(
                          "\${(item.productPrice * item.quantity).toStringAsFixed(2)} ₺"),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _endOrder,
                child: const Text("Siparişi Bitir"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
