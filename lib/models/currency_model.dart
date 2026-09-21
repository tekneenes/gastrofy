class CurrencyData {
  final String label;
  final String buying;
  final String selling;
  final String change;

  CurrencyData({
    required this.label,
    required this.buying,
    required this.selling,
    required this.change,
  });

  factory CurrencyData.fromMap(String label, Map<String, dynamic> map) {
    return CurrencyData(
      label: label,
      buying: map['Alış'] ?? '0.00',
      selling: map['Satış'] ?? '0.00',
      change: map['Değişim'] ?? '%0.00',
    );
  }
}

class CurrencyRates {
  final String updateDate;
  final CurrencyData usd;
  final CurrencyData eur;
  final CurrencyData gold;
  final CurrencyData gbp;
  final CurrencyData rub;
  final CurrencyData kwd;
  final CurrencyData sar;
  final CurrencyData silver;
  final CurrencyData palladium;

  CurrencyRates({
    required this.updateDate,
    required this.usd,
    required this.eur,
    required this.gold,
    required this.gbp,
    required this.rub,
    required this.kwd,
    required this.sar,
    required this.silver,
    required this.palladium,
  });

  factory CurrencyRates.fromJson(Map<String, dynamic> json) {
    return CurrencyRates(
      updateDate: json['Update_Date'] ?? '',
      usd: CurrencyData.fromMap('USD', json['USD'] ?? {}),
      eur: CurrencyData.fromMap('EUR', json['EUR'] ?? {}),
      gold: CurrencyData.fromMap('Altın', json['gram-altin'] ?? {}),
      gbp: CurrencyData.fromMap('Sterlin', json['GBP'] ?? {}),
      rub: CurrencyData.fromMap('Ruble', json['RUB'] ?? {}),
      kwd: CurrencyData.fromMap('Kuv. Dinar', json['KWD'] ?? {}),
      sar: CurrencyData.fromMap('Riyal', json['SAR'] ?? {}),
      silver: CurrencyData.fromMap('Gümüş', json['gumus'] ?? {}),
      palladium: CurrencyData.fromMap('Paladyum', json['gram-paladyum'] ?? {}),
    );
  }
}
