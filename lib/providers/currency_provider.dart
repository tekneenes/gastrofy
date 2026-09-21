import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/currency_model.dart';
import '../services/currency_service.dart';

class CurrencyProvider with ChangeNotifier {
  final CurrencyService _service = CurrencyService();
  CurrencyRates? _rates;
  Timer? _timer;

  CurrencyRates? get rates => _rates;

  CurrencyProvider() {
    fetchRates();
    _startTimer();
  }

  void _startTimer() {
    // 5 dakikada bir güncelle
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      fetchRates();
    });
  }

  Future<void> fetchRates() async {
    final response = await _service.fetchRates();
    if (response != null) {
      _rates = response;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
