import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'dart:convert';
import '../models/order_item_model.dart';

/// 📊 Bir ürünün derinlemesine analizi
class ProductDetailAnalysis {
  final String productId;
  final String productName;
  final int totalQuantity;
  final double totalRevenue;
  final int peakHour;
  final List<int> hourlyDistribution;
  final Map<String, int> tableDistribution;

  ProductDetailAnalysis({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.peakHour,
    required this.hourlyDistribution,
    required this.tableDistribution,
  });
}

class ProductReportProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  ProductDetailAnalysis? _currentProductAnalysis;

  ProductDetailAnalysis? get currentProductAnalysis => _currentProductAnalysis;

  /// 📊 Belirli bir ürün için detaylı analiz yapar
  Future<void> loadDetailedProductReport({
    required String productId,
    required String productName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Tüm kayıtları çekip ürün bazlı filtreleyeceğiz
    final records = await _dbHelper.getClosedOrdersByDateRange(
      startDate,
      endDate,
    );

    if (records.isEmpty) {
      _currentProductAnalysis = null;
      notifyListeners();
      return;
    }

    int totalQty = 0;
    double totalRev = 0;
    List<int> hourlyDist = List.filled(24, 0);
    Map<String, int> tableDist = {};

    for (var row in records) {
      final itemsJson = row['itemsJson'] as String? ?? '[]';
      final tableName = row['tableName'] as String? ?? 'Bilinmeyen Masa';
      
      try {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        bool productFoundInOrder = false;
        
        for (var itemMap in itemsList) {
          final item = OrderItem.fromMap(itemMap);
          if (item.productId == productId) {
            totalQty += item.quantity;
            totalRev += (item.productPrice * item.quantity);
            
            // Masa dağılımı
            tableDist[tableName] = (tableDist[tableName] ?? 0) + item.quantity;
            productFoundInOrder = true;
          }
        }

        if (productFoundInOrder) {
          // Saatlik dağılım (Sadece bu ürünün satıldığı siparişlerin saatleri)
          final createdAtStr = row['createdAt'] as String;
          final createdAt = DateTime.parse(createdAtStr);
          hourlyDist[createdAt.hour]++;
        }
      } catch (e) {
        debugPrint("Error parsing itemsJson in ProductReportProvider: $e");
      }
    }

    if (totalQty == 0) {
      _currentProductAnalysis = null;
      notifyListeners();
      return;
    }

    // Peak Hour bul
    int peakH = 0;
    int maxSales = 0;
    for (int i = 0; i < 24; i++) {
        if (hourlyDist[i] > maxSales) {
            maxSales = hourlyDist[i];
            peakH = i;
        }
    }

    _currentProductAnalysis = ProductDetailAnalysis(
      productId: productId,
      productName: productName,
      totalQuantity: totalQty,
      totalRevenue: totalRev,
      peakHour: peakH,
      hourlyDistribution: hourlyDist,
      tableDistribution: tableDist,
    );

    notifyListeners();
  }
}
