# Gastrofy 🍽️🧾
### Enterprise Cloud POS, Table Management & Restaurant Intelligence Ecosystem

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Multiplatform](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Web-4E5D6C?style=for-the-badge)](https://flutter.dev/multi-platform)
[![Offline First](https://img.shields.io/badge/Offline--First-SQLite%20%2B%20Firestore%20Sync-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://pub.dev/packages/sqflite)
[![AI Engine](https://img.shields.io/badge/AI%20Intelligence-Google%20Gemini-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Thermal Print](https://img.shields.io/badge/Printing-ESC%2FPOS%20%26%20PDF%20Receipts-388E3C?style=for-the-badge)](https://pub.dev/packages/printing)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](LICENSE)

> **Restoranlar, kafeler ve gastronomi işletmeleri için geliştirilmiş; çevrimdışı öncelikli (Offline-First) hibrit mimariye sahip, yapay zeka destekli menü & ciro analitiği, akıllı QR menü entegrasyonu, termal fiş/adisyon yazdırma ve çoklu şube yönetimini tek çatı altında toplayan yeni nesil POS ekosistemi.**

---

## 🌟 Neden Gastrofy?

Geleneksel POS ve adisyon yazılımları; internet kesintilerinde kilitlenen hantal altyapılar, yüksek komisyonlu lisanslama modelleri ve cihaz bağımlılığı nedeniyle restoran operasyonlarını aksatır.

**Gastrofy (GastroMind)**; masaüstü (Windows/macOS) ve mobil (iOS/Android) cihazlarda tekil Dart çekirdeğiyle çalışır. İnternet kopsa dahi yerel **SQLite (`sqflite_common_ffi`)** üzerinde adisyon açmaya, masa taşımaya ve tahsilat yapmaya devam eder; bağlantı sağlandığında **Cloud Firestore** ile çift yönlü otomatik senkronize olur.

---

## 🏛️ Mimari ve Sistem Tasarımı

```
┌────────────────────────────────────────────────────────┐
│            Gastrofy Cross-Platform Client              │
│    (iOS App Store • Google Play • Windows POS • Web)   │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────┴────────────────────────────┐
│                    Gastrofy Core Motors                │
├─────────────────────┬───────────────────┬──────────────┤
│ 📋 POS & Masa Motor │ 🤖 Gemini AI BI   │ ⚡ Offline    │
│  - Adisyon Bölme    │  - Ciro Tahmini   │    First Sync│
│  - Masa Taşıma      │  - Menü Önerisi   │  - SQLite FFI│
│  - Mutfak Terminali │  - Dinamik Fiyat  │  - Firestore │
│  - Veresiye Defteri │  - AI Sohbet Asis │    Event Bus │
└─────────────────────┴───────────────────┴──────────────┘
                            │
┌───────────────────────────┴────────────────────────────┐
│      Harici Donanım & Çevre Birimleri Köprüsü          │
│  (Termal Fiş Yazıcılar ESC/POS • Barkod/QR Okuyucu •   │
│   Yüz Tanıma Personel Takibi • Dahili Shelf HTTP API)  │
└────────────────────────────────────────────────────────┘
```

---

## ⚡ Temel Yetenekler & Modüller

### 1. 🪑 İnteraktif Masa & Sipariş Yönetimi (`screens/`)
- Özelleştirilebilir salon ve masa planı (İç mekan, teras, bahçe, VIP).
- Tek dokunuşla masa taşıma, masa birleştirme ve adisyon bölme (split-bill).
- Garson ve mutfak terminalleri arasında gerçek zamanlı sipariş akışı.

### 2. ⚡ Sıfır Kesinti Hibrit Senkronizasyon (`local_sync_service.dart`)
- **Offline-First:** İnternet bağlantısı koptuğunda tam kapasite yerel veritabanında çalışmaya devam eder.
- Bağlantı geri geldiğinde çakışmasız (conflict-free) bulut senkronizasyonu.

### 3. 🤖 Google Gemini Yapay Zeka Analitiği (`table_ai_service.dart`)
- Saatlik ve günlük yoğunluk analizi, ciro tahminleri ve kâr marjı raporları.
- Akıllı menü optimizasyonu: En çok/en az satan ürün analizi ve dinamik çapraz satış önerileri.
- Dahili yapay zeka işletme asistanı ile doğal dilde ciro sorgulama.

### 4. 🖨️ Termal Yazıcı & Fiş/Rapor Çıktısı (`pdf_report_service.dart`)
- 58mm ve 80mm ESC/POS termal fiş yazıcıları ve ağ yazıcılarıyla tam uyum.
- Detaylı Gün Sonu Z-Raporları, KDV dökümleri ve mutfak sipariş fişleri.

### 5. 📱 QR Menü & Müşteri Masası Entegrasyonu (`GastroQR`)
- Müşterilerin kendi telefonlarından karekod okutarak masadan doğrudan sipariş verebilmesi veya menüyü görüntülemesi.

### 6. 👥 Personel Yetkilendirme & Biyometrik Giriş (`face_recognition_service.dart`)
- Rol bazlı yetkilendirme (Kasiyer, Garson, Mutfak Şefi, Müdür).
- İsteğe bağlı yüz tanıma veya PIN kodu ile hızlı personel vardiya takibi.

### 7. 📒 Müşteri Cari & Veresiye Defteri (`veresiye_screen.dart`)
- Sürekli müşteriler için veresiye hesap takibi, kısmi tahsilat ve bakiye geçmişi.

---

## 📂 Dizin Yapısı

```
lib/
├── models/                           # Ürün, Masa, Adisyon, Rapor ve Personel modelleri
├── providers/                        # Sipariş, Masa, Rapor ve Ayar Provider'ları
├── screens/                          # 36 adet modüler ekran arayüzü
│   ├── home_screen.dart              # Salon masa planı ve ana operasyon ekranı
│   ├── DetailedRevenueScreen.dart    # Gelişmiş gelir, kâr ve ciro grafikleri
│   ├── quick_sale_screen.dart        # Hızlı paket servis / al-götür satış ekranı
│   ├── ai_chat_screen.dart           # Gemini AI işletme analitik asistanı
│   ├── veresiye_screen.dart          # Müşteri borç / veresiye defteri
│   └── staff_management_screen.dart  # Personel yetkilendirme ve roller
├── services/                         # 15 temel iş mantığı servisi
│   ├── database_helper.dart          # SQLite yerel veritabanı motoru
│   ├── local_sync_service.dart       # SQLite <-> Firestore senkronizasyon köprüsü
│   ├── pdf_report_service.dart       # ESC/POS ve PDF fiş çıktı servisi
│   └── table_ai_service.dart         # Google Gemini yapay zeka entegrasyonu
└── main.dart                         # Uygulama kök yapılandırması
```

---

## 🚀 Başlangıç ve Yerel Çalıştırma

### Gereksinimler
- **Flutter SDK:** 3.24.0 veya üzeri
- **Dart SDK:** 3.0.0 veya üzeri

```bash
# Repoyu klonlayın
git clone https://github.com/tekneenes/gastrofy.git
cd gastrofy

# Bağımlılıkları yükleyin
flutter pub get

# Cihazınızda başlatın
flutter run -d macos    # veya -d windows / -d chrome
```

---

## 📜 Lisans & Atıflar

Bu proje **[Apache License 2.0](LICENSE)** altında lisanslanmıştır.  
Kullanılan üçüncü taraf açık kaynak kütüphaneler ve atıflar **[NOTICE](NOTICE)** dosyasında listelenmiştir.

---

## 👨‍💻 Geliştirici

**Muhammed Enes Tekne**  
- **GitHub:** [@tekneenes](https://github.com/tekneenes)  
- **LinkedIn:** [Muhammed Enes Tekne](https://www.linkedin.com/in/muhammed-enes-tekne)  
- **Portfolyo:** [tekneenes.github.io](https://tekneenes.github.io)
