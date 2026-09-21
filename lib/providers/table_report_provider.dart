import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'dart:convert';
import '../models/order_item_model.dart';

/// 📈 Masa bazlı raporlarda kullanılacak özet modeli
class TableSaleSummary {
  final String id;
  final String name;
  final double totalRevenue;
  final int orderCount;
  final int totalDurationSeconds;
  final double avgDurationSeconds;

  TableSaleSummary({
    required this.id,
    required this.name,
    required this.totalRevenue,
    required this.orderCount,
    required this.totalDurationSeconds,
    required this.avgDurationSeconds,
  });
}

/// 📊 Bir masanın derinlemesine analizi
class TableDetailAnalysis {
  final String tableId;
  final String tableName;
  final int peakHour; // 0-23 arası en yoğun saat
  final String mostOrderedProduct;
  final int mostOrderedProductCount;
  final double avgSessionRevenue;
  final List<int> hourlyDistribution; // 24 saatlik yoğunluk verisi
  final Map<String, int> productDistribution; // Masada satılan tüm ürünler

  TableDetailAnalysis({
    required this.tableId,
    required this.tableName,
    required this.peakHour,
    required this.mostOrderedProduct,
    required this.mostOrderedProductCount,
    required this.avgSessionRevenue,
    required this.hourlyDistribution,
    required this.productDistribution,
  });
}

class TableReportProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<TableSaleSummary> _tableSummaries = [];
  TableDetailAnalysis? _currentTableAnalysis;

  List<TableSaleSummary> get tableSummaries => _tableSummaries;
  TableDetailAnalysis? get currentTableAnalysis => _currentTableAnalysis;

  /// 📊 Belirli tarih aralığındaki masa bazlı satış özetini yükler
  Future<void> loadTableSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await _dbHelper.getTableSalesSummary(
      startDate: startDate,
      endDate: endDate,
    );

    _tableSummaries = results.map((map) {
      return TableSaleSummary(
        id: map['tableId'] as String,
        name: map['tableName'] as String,
        totalRevenue: (map['totalRevenue'] as num).toDouble(),
        orderCount: map['orderCount'] as int,
        totalDurationSeconds: (map['totalDurationSeconds'] as num?)?.toInt() ?? 0,
        avgDurationSeconds: (map['avgDurationSeconds'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    notifyListeners();
  }

  /// 📊 Belirli bir masa için detaylı analiz yapar
  Future<void> loadDetailedTableReport({
    required String tableId,
    required String tableName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final records = await _dbHelper.getTableDetailedRecords(
      tableId: tableId,
      startDate: startDate,
      endDate: endDate,
    );

    if (records.isEmpty) {
      _currentTableAnalysis = null;
      notifyListeners();
      return;
    }

    // 1. Saatlik dağılım (Peak Hour)
    List<int> distribution = List.filled(24, 0);
    double totalRevenue = 0;
    Map<String, int> productCounts = {};

    for (var row in records) {
      totalRevenue += (row['total'] as num).toDouble();
      
      // Saat bilgisi extraction
      final createdAtStr = row['createdAt'] as String;
      final createdAt = DateTime.parse(createdAtStr);
      distribution[createdAt.hour]++;

      // Ürün analizi
      final itemsJson = row['itemsJson'] as String? ?? '[]';
      try {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        for (var itemMap in itemsList) {
          final item = OrderItem.fromMap(itemMap);
          productCounts[item.productName] =
              (productCounts[item.productName] ?? 0) + item.quantity;
        }
      } catch (e) {
        debugPrint("Error parsing itemsJson in TableReportProvider: $e");
      }
    }

    // Peak Hour bul
    int peakH = 0;
    int maxSessions = 0;
    for (int i = 0; i < 24; i++) {
        if (distribution[i] > maxSessions) {
            maxSessions = distribution[i];
            peakH = i;
        }
    }

    // En çok satılan ürün
    String topProduct = "Veri Yok";
    int topProductCount = 0;
    if (productCounts.isNotEmpty) {
      var sortedProducts = productCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topProduct = sortedProducts.first.key;
      topProductCount = sortedProducts.first.value;
    }

    _currentTableAnalysis = TableDetailAnalysis(
      tableId: tableId,
      tableName: tableName,
      peakHour: peakH,
      mostOrderedProduct: topProduct,
      mostOrderedProductCount: topProductCount,
      avgSessionRevenue: totalRevenue / records.length,
      hourlyDistribution: distribution,
      productDistribution: productCounts,
    );

    notifyListeners();
  }
}
