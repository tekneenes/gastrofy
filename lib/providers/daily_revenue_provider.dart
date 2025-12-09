import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_revenue_model.dart';
import '../services/database_helper.dart';
import 'package:uuid/uuid.dart';

class DailyRevenueProvider with ChangeNotifier {
  List<DailyRevenue> _dailyRevenues = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<DailyRevenue> get dailyRevenues => _dailyRevenues;

  DailyRevenueProvider() {
    // Varsayılan olarak son 30 gün verisini yükle
    loadDailyRevenues();
  }

  // 🔹 Tarih aralığı parametreleri ekledik
  Future<void> loadDailyRevenues(
      {DateTime? startDate, DateTime? endDate}) async {
    if (startDate != null && endDate != null) {
      // Belirli tarih aralığını yükle
      _dailyRevenues =
          await _dbHelper.getDailyRevenuesByRange(startDate, endDate);
    } else {
      // Varsayılan: son 30 gün
      _dailyRevenues = await _dbHelper.getDailyRevenuesLast30Days();
    }
    notifyListeners();
  }

  Future<void> addRevenue(double amount) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _dbHelper.insertOrUpdateDailyRevenue(
      DailyRevenue(id: const Uuid().v4(), date: today, revenue: amount),
    );
    await loadDailyRevenues(); // Güncel veriyi yükle
  }
}
