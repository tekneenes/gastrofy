import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';
// Gerçek model dosyalarını import ediyoruz (UYARI: Gerekli olsalar da linter tarafından kullanılmadıkları bildiriliyor)
// Buraya TableModel, VeresiyeModel, DailyRevenueModel, ProductModel, CategoryModel gibi modelleri de eklediğinizi varsayıyorum.
// Linter uyarısını engellemek için model dosyaları içindeki sınıfları burada varsayılan olarak kabul ediyoruz.
import 'dart:convert';
import 'database_helper.dart'; // Kendi DatabaseHelper'ınızı import edin

/// Bu sınıf, kullanıcının sorgusunu alır, veritabanından ilgili veriyi çeker (Retrieval),
/// veriyi temizler ve Gemini'ye göndereceği son istemi oluşturur (Augmented Generation).
class TableAIService {
  final Gemini gemini = Gemini.instance;
  // Simülasyonlu helper'ı kullanıyoruz
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  // 1. Temel Sistem Talimatı (Persona ve Kısıtlamalar)
  static const String systemInstruction = """
  Sen, bir restoran/kafe masa takip ve yönetim asistanısın. Görevin, SANA SAĞLANAN VERİLERİ (CONTEXT) kullanarak kullanıcının sorularını yanıtlamaktır.
  - Sadece ve sadece sağlanan verilere güven.
  - Sağlanan verilerde cevap yoksa, "Bu bilgiye erişimim yok veya veritabanında bu bilgi bulunmuyor." şeklinde net bir yanıt ver.
  - Cevaplarını kısa, öz ve profesyonel bir dille ver. Para birimi olarak her zaman 'TL' kullan.
  - Geçmiş sohbet geçmişini (History) de kullanarak tutarlı cevaplar ver.
  - Eğer bir raporlama (aylık, 3 aylık, 6 aylık) verisi sunuyorsan, o döneme ait toplam ciroyu ve dönemsel performansı analiz ederek kısa bir özet sun.
  - Ürün ve kategori sorularına net, listeleyerek ve mümkünse istatistik (fiyat, satış sayısı, kategoriye göre dağılım) vererek yanıtla.
  """;

  /// Ana RAG Fonksiyonu
  Future<String> getGeminiResponseWithRAG(
      String userQuery, List<Content> chatHistory) async {
    // 2. Retrieval (Veri Çekme) - Kullanıcı sorusuna göre en alakalı veriyi çek.
    String contextData = await _retrieveRelevantData(userQuery);

    // 3. Augmentation (İstem Oluşturma) - Veriyi ve soruyu birleştir.
    String finalPrompt = """
    --- SİSTEM TALİMATI (PERSONA) ---
    $systemInstruction
    -----------------------------
    --- SAĞLANAN VERİ (CONTEXT) ---
    $contextData
    -----------------------------
    --- KULLANICI SORUSU ---
    $userQuery
    """;

    // 4. Gemini'ye Gönderme (History'i dahil et)
    final newMessage = Content(role: 'user', parts: [
      Part.text(finalPrompt),
    ]);

    final fullContents = [...chatHistory, newMessage];

    try {
      final response = await gemini.chat(
        fullContents,
      );

      // Yanıtı almak için TextPart'ları birleştir
      return response?.content?.parts
              ?.map((e) => (e as TextPart).text)
              .join() ??
          "Yapay zekadan geçerli bir cevap alamadım.";
    } catch (e) {
      print("Gemini API Hatası: $e");
      if (e.toString().contains('Invalid API Key')) {
        return "Üzgünüm, API anahtarı geçersiz veya kısıtlı. Lütfen kontrol edin.";
      }
      return "Üzgünüm, Gemini API'ye bağlanırken bir hata oluştu: ${e.toString()}";
    }
  }

  /// Kullanıcının sorusuna göre veritabanından ilgili bilgiyi çeken ve formatlayan fonksiyon.
  Future<String> _retrieveRelevantData(String query) async {
    final queryLower = query.toLowerCase();

    // 1. ÜRÜN VE KATEGORİ SORGUSU (YENİ)
    if (queryLower.contains('ürün') ||
        queryLower.contains('kategori') ||
        queryLower.contains('fiyat') ||
        queryLower.contains('menü')) {
      try {
        final data = await dbHelper.getProductsAndCategories();
        final products = data['products'] as List<dynamic>? ?? [];
        final categories = data['categories'] as List<dynamic>? ?? [];

        if (products.isEmpty && categories.isEmpty) {
          return "Menüde kayıtlı ürün veya kategori bilgisi bulunmamaktadır.";
        }

        String context = "--- ÜRÜN VE KATEGORİ VERİSİ ---\n";

        // Kategori Bilgileri
        context += "Toplam Kategori Sayısı: ${categories.length}\n";
        final Map<String, String> categoryMap = {
          for (var c in categories) c.id as String: c.name as String
        };

        // Ürün Bilgileri ve Analiz
        context += "Toplam Ürün Sayısı: ${products.length}\n";
        final Map<String, int> productCountByCategory = {};
        double totalSales = 0;
        double avgPrice = 0;

        if (products.isNotEmpty) {
          // En çok satan ürünü bulmak için başlangıç değeri
          // Hata olasılığına karşı kontrol ekledik.
          dynamic bestSeller = products.isNotEmpty ? products.first : null;
          double totalPriceSum = 0;
          int totalSalesCount = 0;

          for (var p in products) {
            // Satış sayısı ve toplam fiyatı hesapla
            final salesCount = (p.salesCount as int? ?? 0);
            final price = (p.price as double? ?? 0.0);

            totalSalesCount += salesCount;
            totalPriceSum += price;
            totalSales += salesCount * price;

            // Kategoriye göre ürün sayısını hesapla
            final categoryName =
                categoryMap[p.categoryId as String] ?? 'Kategorisiz';
            productCountByCategory[categoryName] =
                (productCountByCategory[categoryName] ?? 0) + 1;

            // En çok satan kontrolü
            if (bestSeller != null &&
                salesCount > (bestSeller.salesCount as int? ?? 0)) {
              bestSeller = p;
            }
          }

          avgPrice = products.length > 0 ? totalPriceSum / products.length : 0;

          // Ürün İstatistikleri
          context +=
              "Toplam Satış Hacmi (Fiyat x Satış Adedi): ${totalSales.toStringAsFixed(2)} TL\n";
          context += "Toplam Satılan Ürün Adedi: $totalSalesCount adet\n";
          context +=
              "Ortalama Ürün Fiyatı: ${avgPrice.toStringAsFixed(2)} TL\n";
          if (bestSeller != null) {
            context +=
                "En Çok Satan Ürün: ${bestSeller.name} (${bestSeller.salesCount} adet)\n";
          } else {
            context += "En Çok Satan Ürün: Veri yok\n";
          }

          // Kategoriye göre ürün dağılımı
          context += "\n--- KATEGORİYE GÖRE ÜRÜN DAĞILIMI ---\n";
          productCountByCategory.forEach((name, count) {
            context += "$name: $count ürün\n";
          });

          // Detaylı Ürün Listesi (LLM'e tüm detayı vermek yerine ilk 5'i ve önemli istatistikleri veriyoruz)
          context +=
              "\n--- İLK 5 ÜRÜN DETAYI (ID, Adı, Fiyat, Satış Adedi, Kategori) ---\n";
          context += products
              .take(5)
              .map((p) =>
                  'ID: ${p.id}, Adı: ${p.name}, Fiyat: ${(p.price as double? ?? 0.0).toStringAsFixed(2)} TL, Satış: ${(p.salesCount as int? ?? 0)} adet, Kategori: ${categoryMap[p.categoryId as String] ?? 'Kategorisiz'}')
              .join('\n');
        }

        return context;
      } catch (e) {
        print("Ürün/Kategori Veri Çekme Hatası: $e");
        return "UYARI: Ürün/Kategori verileri çekilirken veritabanı hatası oluştu. Lütfen DatabaseHelper dosyanızdaki 'categories' tablosunun oluşturulduğundan ve veritabanı sürümünün doğru olduğundan emin olun. Teknik Hata: $e";
      }
    }

    // 2. Masa Durumu Sorgusu (MEVCUT)
    if (queryLower.contains('masa') ||
        queryLower.contains('doluluk') ||
        queryLower.contains('boş')) {
      try {
        final tables = await dbHelper.getTables();
        if (tables.isEmpty) return "Aktif masa kaydı bulunmamaktadır.";

        final activeTables =
            tables.where((t) => (t as dynamic).isOccupied).toList();
        final freeTables =
            tables.where((t) => !(t as dynamic).isOccupied).toList();

        String context = "Tüm Masa Sayısı: ${tables.length}\n";
        context += "Dolu Masa Sayısı: ${activeTables.length}\n";
        context += "Boş Masa Sayısı: ${freeTables.length}\n";

        context += "\n--- DOLU MASALAR ---\n";
        if (activeTables.isNotEmpty) {
          context += activeTables
              .map((t) =>
                  '${(t as dynamic).name} (ID: ${(t as dynamic).id}), Ciro: ${(t as dynamic).totalRevenue.toStringAsFixed(2)} TL, Başlangıç: ${DateFormat('HH:mm').format((t as dynamic).startTime!)}')
              .join('\n');
        } else {
          context += 'Hiç dolu masa yok.';
        }

        context += "\n\n--- BOŞ MASALAR ---\n";
        context += freeTables.map((t) => (t as dynamic).name).join(', ');

        return context;
      } catch (e) {
        print("Masa Veri Çekme Hatası: $e");
        return "UYARI: Masa verileri çekilirken veritabanı hatası oluştu. Teknik Hata: $e";
      }
    }

    // 3. Ciro / Gelir Sorgusu (MEVCUT)
    if (queryLower.contains('ciro') ||
        queryLower.contains('gelir') ||
        (queryLower.contains('bugün') && !queryLower.contains('rapor'))) {
      try {
        final todayRevenue = await dbHelper.getTodayRevenue();
        final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
        String context =
            "Bugünün ($today) toplam cirosu: ${todayRevenue.toStringAsFixed(2)} TL.\n";

        return context;
      } catch (e) {
        print("Bugün Ciro Veri Çekme Hatası: $e");
        return "UYARI: Bugünün ciro bilgisi çekilirken veritabanı hatası oluştu. Teknik Hata: $e";
      }
    }

    // 4. Veresiye Sorgusu (MEVCUT)
    if (queryLower.contains('veresiye') ||
        queryLower.contains('alacak') ||
        queryLower.contains('müşteri borç')) {
      try {
        final records = await dbHelper.getVeresiyeRecords();
        if (records.isEmpty)
          return "Aktif veya geçmiş veresiye kaydı bulunmamaktadır.";

        final unpaid =
            records.where((r) => (r as dynamic).isPaid == 0).toList();
        final totalUnpaidAmount = unpaid.fold(
            0.0, (sum, item) => sum + (item as dynamic).totalAmount);

        String context =
            "Toplam Ödenmemiş Veresiye (Alacak) Tutarı: ${totalUnpaidAmount.toStringAsFixed(2)} TL.\n";
        context += "Toplam Veresiye Kayıt Sayısı: ${records.length}\n";

        context += "\n--- ÖDENMEMİŞ EN SON 5 KAYIT (Tarihli) ---\n";
        if (unpaid.isNotEmpty) {
          context += unpaid
              .take(5)
              .map((r) =>
                  'ID: ${(r as dynamic).id}, Müşteri: ${(r as dynamic).customerName}, Tutar: ${(r as dynamic).totalAmount.toStringAsFixed(2)} TL, Tarih: ${DateFormat('dd.MM.yyyy').format((r as dynamic).date as DateTime)}')
              .join('\n');
        } else {
          context += 'Tebrikler, ödenmemiş veresiye kaydı yok.';
        }

        return context;
      } catch (e) {
        print("Veresiye Veri Çekme Hatası: $e");
        return "UYARI: Veresiye verileri çekilirken veritabanı hatası oluştu. Teknik Hata: $e";
      }
    }

    // 5. Gelişmiş Raporlama Sorgusu (MEVCUT)
    if (queryLower.contains('raporla') ||
        queryLower.contains('analiz') ||
        queryLower.contains('aylık') ||
        queryLower.contains('son 3 ay') ||
        queryLower.contains('son 6 ay')) {
      try {
        final now = DateTime.now();
        DateTime startDate;
        String periodName;

        if (queryLower.contains('bugün') || queryLower.contains('günlük')) {
          startDate = DateTime(now.year, now.month, now.day);
          periodName = "Bugün";
        } else if (queryLower.contains('son 7 gün') ||
            queryLower.contains('haftalık')) {
          startDate = now.subtract(const Duration(days: 6));
          periodName = "Son 7 Gün";
        } else if (queryLower.contains('son 30 gün') ||
            queryLower.contains('aylık')) {
          startDate = now.subtract(const Duration(days: 29));
          periodName = "Son 30 Gün";
        } else if (queryLower.contains('son 3 ay') ||
            queryLower.contains('üç aylık')) {
          startDate = now.subtract(const Duration(days: 90));
          periodName = "Son 3 Ay";
        } else if (queryLower.contains('son 6 ay') ||
            queryLower.contains('altı aylık')) {
          startDate = now.subtract(const Duration(days: 180));
          periodName = "Son 6 Ay";
        } else {
          startDate = now.subtract(const Duration(days: 29));
          periodName = "Son 30 Gün (Varsayılan)";
        }

        final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final revenues =
            await dbHelper.getDailyRevenuesByRange(startDate, endDate);

        if (revenues.isEmpty) {
          return "$periodName (${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}) aralığında kayıtlı ciro verisi bulunmamaktadır.";
        }

        final totalRevenue =
            revenues.fold(0.0, (sum, r) => sum + (r as dynamic).revenue);
        final avgDailyRevenue = totalRevenue / revenues.length;
        final uniqueDays = revenues.length;

        String context = "--- CİRO RAPORU ($periodName) ---\n";
        context +=
            "Rapor Aralığı: ${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}\n";
        context += "Toplam Ciro: ${totalRevenue.toStringAsFixed(2)} TL\n";
        context += "Raporlanan Gün Sayısı: $uniqueDays\n";
        context +=
            "Ortalama Günlük Ciro: ${avgDailyRevenue.toStringAsFixed(2)} TL\n";

        context += "\n--- İLK 5 GÜN DETAYI ---\n";
        context += revenues
            .take(5)
            .map((r) =>
                'Tarih: ${(r as dynamic).date}, Ciro: ${(r as dynamic).revenue.toStringAsFixed(2)} TL')
            .join('\n');

        if (revenues.length > 5) {
          context += "\n--- SON 5 GÜN DETAYI ---\n";
          context += revenues.reversed
              .take(5)
              .map((r) =>
                  'Tarih: ${(r as dynamic).date}, Ciro: ${(r as dynamic).revenue.toStringAsFixed(2)} TL')
              .toList()
              .reversed
              .join('\n');
        }

        return context;
      } catch (e) {
        print("Raporlama Veri Çekme Hatası: $e");
        return "UYARI: Raporlama verileri çekilirken veritabanı hatası oluştu. Teknik Hata: $e";
      }
    }

    // 6. Genel Özet (Hiçbir spesifik niyet tespit edilemezse) (MEVCUT)
    try {
      final tables = await dbHelper.getTables();
      final todayRevenue = await dbHelper.getTodayRevenue();

      return "Mevcut Genel Durum Özeti:\n"
          "- Aktif Masa Sayısı: ${tables.where((t) => (t as dynamic).isOccupied).length}\n"
          "- Boş Masa Sayısı: ${tables.where((t) => !(t as dynamic).isOccupied).length}\n"
          "- Bugün Toplam Ciro: ${todayRevenue.toStringAsFixed(2)} TL. "
          "Lütfen daha spesifik sorular sorun (Örn: 'Veresiye borçları ne durumda?', 'Son 3 ayı raporla' veya 'Hangi ürünler en çok satılıyor?').";
    } catch (e) {
      print("Genel Özet Veri Çekme Hatası: $e");
      return "UYARI: Genel özet verileri çekilirken veritabanı hatası oluştu. Teknik Hata: $e";
    }
  }
}
