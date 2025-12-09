import 'dart:convert';
import 'package:flutter_gemini/src/models/content/content.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'database_helper.dart';

class TableAIService {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  String? _apiKey;

  final List<Map<String, dynamic>> _conversationHistory = [];

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  static const String systemInstruction = """
Sen, bir restoran/kafe masa takip ve yönetim asistanısın. Görevin, SANA SAĞLANAN VERİLERİ (CONTEXT) kullanarak kullanıcının sorularını yanıtlamaktır.
  - Sadece ve sadece sağlanan verilere güven.
  - Sağlanan verilerde cevap yoksa, "Bu bilgiye erişimim yok veya veritabanında bu bilgi bulunmuyor." şeklinde net bir yanıt ver.
  - Cevaplarını kısa, öz ve profesyonel bir dille ver. Para birimi olarak her zaman 'TL' kullan.
  - Geçmiş sohbet geçmişini (History) de kullanarak tutarlı cevaplar ver.
  - Eğer bir raporlama (aylık, 3 aylık, 6 aylık) verisi sunuyorsan, o döneme ait toplam ciroyu ve dönemsel performansı analiz ederek kısa bir özet sun.
  - Ürün ve kategori sorularına net, listeleyerek ve mümkünse istatistik (fiyat, satış sayısı, kategoriye göre dağılım) vererek yanıtla.
  - Masa durumu sorularında, toplam masa sayısı, dolu ve boş masa sayısını belirt. Eğer dolu masalar hakkında bilgi istenirse, en fazla 5 dolu masanın adını ve o masaların cirosunu listele.
  -  elindeki verilerle neler yapabileceğini bil ve kullanıcının sorularına en iyi şekilde yanıt ver.
  -ve işletmeye istenirse öneriler verebilirsin.
  - Cevaplarında kesinlikle kod parçacıkları, markdown formatı veya özel karakterler kullanma.
  - ve sorulursa kendini tanıtma. kendini table intelligence olarak tanı ve sorulursa neler yapabildiğini anlat 
  - satişları artırmaya yönelik önerilerde bulunabilirsin madde madde veya sadece düz metin olarak önerilerde verebilirsin. ama bunu yaparken kesinlikle hayali veriler kullanma. sadece elindeki verileri kullanarak önerilerde bulun ve parantez içinde table intelligence hata yapabilir bu bilgileri doğrulayın diye bir mesaj koy.
  """;
  Future<String> getGeminiResponseWithRAG(
      String userQuery, List<Content> chatHistory) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return "❌ API anahtarı ayarlanmamış.";
    }

    // 1. Veri çekme
    String contextData = await _retrieveRelevantData(userQuery);

    // 2. Context'i kısalt
    if (contextData.length > 2000) {
      contextData = contextData.substring(0, 2000) + "\n...(kısaltıldı)";
    }

    // 3. Prompt oluştur
    String finalPrompt = """$systemInstruction

VERİ:
$contextData

SORU: $userQuery""";

    // 4. History'ye ekle
    _conversationHistory.add({
      "role": "user",
      "parts": [
        {"text": finalPrompt}
      ]
    });

    // 5. API isteği - v1beta ve gemini-2.5-flash kullan
    final String apiUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

    try {
      print("API İsteği gönderiliyor: gemini-2.5-flash");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": _conversationHistory,
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 800,
            "topP": 0.8,
            "topK": 10
          }
        }),
      );

      print("Yanıt Kodu: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['candidates'] != null &&
            jsonResponse['candidates'].isNotEmpty) {
          final text =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];

          // History'ye model yanıtını ekle
          _conversationHistory.add({
            "role": "model",
            "parts": [
              {"text": text}
            ]
          });

          // History çok uzarsa kısalt (son 16 mesaj)
          if (_conversationHistory.length > 16) {
            _conversationHistory.removeRange(
                0, _conversationHistory.length - 16);
          }

          return text;
        } else if (jsonResponse['promptFeedback'] != null) {
          print("Prompt Feedback: ${jsonResponse['promptFeedback']}");
          return "❌ Güvenlik nedeniyle yanıt verilemedi. Lütfen sorunuzu farklı şekilde sorun.";
        } else {
          print("Beklenmeyen yanıt formatı: $jsonResponse");
          return "❌ Yanıt alınamadı.";
        }
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        print("400 Hatası: $error");
        return "❌ İstek formatı hatalı. Lütfen daha basit bir soru deneyin.";
      } else if (response.statusCode == 404) {
        print("404 Hatası: ${response.body}");
        return "❌ Model bulunamadı. Lütfen API anahtarınızı kontrol edin.";
      } else if (response.statusCode == 429) {
        return "❌ Çok fazla istek. Birkaç saniye bekleyin.";
      } else if (response.statusCode == 403) {
        return "❌ API anahtarı geçersiz veya kota doldu.";
      } else {
        print("Bilinmeyen Hata: ${response.body}");
        return "❌ Bağlantı hatası (${response.statusCode}).";
      }
    } catch (e) {
      print("Exception: $e");
      return "❌ Bağlantı hatası: $e";
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  // VERİ ÇEKME FONKSİYONU
  Future<String> _retrieveRelevantData(String query) async {
    final queryLower = query.toLowerCase();

    try {
      // 1. ÜRÜN/KATEGORİ
      if (queryLower.contains('ürün') ||
          queryLower.contains('kategori') ||
          queryLower.contains('fiyat') ||
          queryLower.contains('menü')) {
        final data = await dbHelper.getProductsAndCategories();
        final products = data['products'] as List<dynamic>? ?? [];
        final categories = data['categories'] as List<dynamic>? ?? [];

        if (products.isEmpty) return "Menüde ürün bulunmuyor.";

        String context = "ÜRÜN BİLGİSİ:\n";
        context +=
            "Toplam: ${products.length} ürün, ${categories.length} kategori\n";

        if (products.isNotEmpty) {
          var sortedProducts = List.from(products);
          sortedProducts.sort((a, b) => ((b as dynamic).salesCount as int)
              .compareTo((a as dynamic).salesCount as int));

          context += "\nEN POPÜLER 5 ÜRÜN:\n";
          for (var p in sortedProducts.take(5)) {
            context +=
                "- ${(p as dynamic).name}: ${(p as dynamic).price} TL (${(p as dynamic).salesCount} satış)\n";
          }
        }
        return context;
      }

      // 2. MASA DURUMU
      if (queryLower.contains('masa') ||
          queryLower.contains('doluluk') ||
          queryLower.contains('boş')) {
        final tables = await dbHelper.getTables();
        if (tables.isEmpty) return "Masa kaydı bulunmuyor.";

        final dolu = tables.where((t) => (t as dynamic).isOccupied).length;
        final bos = tables.length - dolu;

        String context = "MASA DURUMU:\n";
        context += "Toplam: ${tables.length} masa\n";
        context += "Dolu: $dolu masa\n";
        context += "Boş: $bos masa\n";

        if (dolu > 0) {
          context += "\nDOLU MASALAR:\n";
          final doluMasalar =
              tables.where((t) => (t as dynamic).isOccupied).take(5);
          for (var t in doluMasalar) {
            context +=
                "- ${(t as dynamic).name}: ${(t as dynamic).totalRevenue.toStringAsFixed(2)} TL\n";
          }
        }

        return context;
      }

      // 3. CİRO
      if (queryLower.contains('ciro') ||
          queryLower.contains('gelir') ||
          queryLower.contains('bugün')) {
        final todayRevenue = await dbHelper.getTodayRevenue();
        final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
        return "CİRO BİLGİSİ:\nBugün ($today): ${todayRevenue.toStringAsFixed(2)} TL";
      }

      // 4. VERESİYE
      if (queryLower.contains('veresiye') ||
          queryLower.contains('alacak') ||
          queryLower.contains('borç')) {
        final records = await dbHelper.getVeresiyeRecords();
        if (records.isEmpty) return "Veresiye kaydı yok.";

        final unpaid =
            records.where((r) => (r as dynamic).isPaid == 0).toList();
        final total = unpaid.fold(
            0.0, (sum, item) => sum + (item as dynamic).totalAmount);

        String context = "VERESİYE DURUMU:\n";
        context += "Ödenmemiş Toplam: ${total.toStringAsFixed(2)} TL\n";
        context += "Ödenmemiş Kayıt: ${unpaid.length} adet\n";

        if (unpaid.isNotEmpty) {
          context += "\nSON 3 KAYIT:\n";
          for (var r in unpaid.take(3)) {
            context +=
                "- ${(r as dynamic).customerName}: ${(r as dynamic).totalAmount.toStringAsFixed(2)} TL\n";
          }
        }

        return context;
      }

      // 5. RAPORLAMA
      if (queryLower.contains('rapor') || queryLower.contains('analiz')) {
        final now = DateTime.now();
        DateTime startDate;
        String period;

        if (queryLower.contains('son 7') || queryLower.contains('hafta')) {
          startDate = now.subtract(const Duration(days: 6));
          period = "Son 7 Gün";
        } else if (queryLower.contains('son 30') || queryLower.contains('ay')) {
          startDate = now.subtract(const Duration(days: 29));
          period = "Son 30 Gün";
        } else {
          startDate = now.subtract(const Duration(days: 6));
          period = "Son 7 Gün";
        }

        final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        final revenues =
            await dbHelper.getDailyRevenuesByRange(startDate, endDate);

        if (revenues.isEmpty) return "$period için veri yok.";

        final total =
            revenues.fold(0.0, (sum, r) => sum + (r as dynamic).revenue);
        final avg = total / revenues.length;

        return "RAPOR ($period):\n"
            "Toplam Ciro: ${total.toStringAsFixed(2)} TL\n"
            "Ortalama: ${avg.toStringAsFixed(2)} TL/gün\n"
            "Gün Sayısı: ${revenues.length}";
      }

      // 6. GENEL ÖZET
      final tables = await dbHelper.getTables();
      final todayRevenue = await dbHelper.getTodayRevenue();
      final dolu = tables.where((t) => (t as dynamic).isOccupied).length;

      return "GENEL DURUM:\n"
          "Dolu Masa: $dolu/${tables.length}\n"
          "Bugünkü Ciro: ${todayRevenue.toStringAsFixed(2)} TL";
    } catch (e) {
      print("Veri Çekme Hatası: $e");
      return "Veritabanı hatası oluştu.";
    }
  }
}
