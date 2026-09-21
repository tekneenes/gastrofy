import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';

class CurrencyService {
  static const String apiUrl = 'https://finans.truncgil.com/today.json';

  Future<CurrencyRates?> fetchRates() async {
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Cache data silently
        _cacheRates(response.body);
        return CurrencyRates.fromJson(data);
      } else {
        print('Döviz servisi hatası: ${response.statusCode}');
      }
    } catch (e) {
      print('Döviz kurları alınamadı (Bağlantı Hatası): $e');
      print('Önbellekten veri yükleniyor...');
      return _loadCachedRates();
    }
    // If all else fails, try cache
    return _loadCachedRates();
  }

  Future<void> _cacheRates(String jsonString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency_cache', jsonString);
    } catch (e) {
      print('Döviz cacheleme hatası: $e');
    }
  }

  Future<CurrencyRates?> _loadCachedRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('currency_cache');
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        return CurrencyRates.fromJson(data);
      }
    } catch (e) {
      print('Cache yükleme hatası: $e');
    }
    return null;
  }
}
