import 'package:flutter/material.dart';

// Bu sınıf, uygulamanızdaki eğitim adımları için
// GlobalKey'leri tek bir yerde tutar.
class TutorialKeys {
  // Dock İkonları
  static final GlobalKey dockMasalar = GlobalKey();
  static final GlobalKey dockUrunler = GlobalKey();
  static final GlobalKey dockRaporlar = GlobalKey();
  static final GlobalKey dockKameralar = GlobalKey();
  static final GlobalKey dockKayitlar = GlobalKey();
  static final GlobalKey dockAyarlar = GlobalKey();
  static final GlobalKey dockVeresiye = GlobalKey();

  static final GlobalKey dockAIChat = GlobalKey();

  // Bildirim Butonu
  static final GlobalKey bildirimButonu = GlobalKey();

  // İPUCU: HomeScreen'deki "Masa Ekle" butonu için de
  // buraya bir key ekleyip, o sayfada kullanabilirsiniz.
  static final GlobalKey homeMasaEkle = GlobalKey();
  static final GlobalKey homeHizliSatis = GlobalKey();
  static final GlobalKey homeYenile = GlobalKey();
  static final GlobalKey homeIstatistikler = GlobalKey();
  static final GlobalKey homeBolgeler = GlobalKey();
  static final GlobalKey homeDoviz = GlobalKey();
  static final GlobalKey homeCanliLog = GlobalKey();
  static final GlobalKey homeMasalarArea = GlobalKey();
  static final GlobalKey homeGorunumModu = GlobalKey();
  static final GlobalKey homeCikis = GlobalKey();
  static final GlobalKey dockCikis = GlobalKey();
}
