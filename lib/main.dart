import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Durum yönetimi için
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences için
import 'package:showcaseview/showcaseview.dart'; // ShowCaseWidget için
import 'package:intl/date_symbol_data_local.dart'; // Tarih formatlama için
import 'package:flutter_gemini/flutter_gemini.dart'; // Gemini paketi
// Uygulamanızın diğer import'ları
import 'screens/splash_screen.dart';
import 'services/database_helper.dart';
import 'providers/table_provider.dart';
import 'providers/product_provider.dart';
import 'providers/daily_revenue_provider.dart';

// lib/main.dart (ana uygulama dosyası)

// ⚠️ DİKKAT: BURAYI KENDİ GERÇEK GEMINI API ANAHTARINIZLA DEĞİŞTİRİN!
// Bu anahtar şuan sadece bir placeholder'dır ve çalışmayacaktır.
const String GEMINI_API_KEY = "***REMOVED***";

void main() async {
  // 1. Flutter binding'i başlatılıyor (asenkron işlemler için zorunlu)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. GEMINI'YI BAŞLAT (LateInitializationError'ı çözen adım)
  // Diğer kısımlar kullanmadan önce statik instance'ı hazırlar.
  Gemini.init(
    apiKey: GEMINI_API_KEY,
    // Diğer isteğe bağlı ayarları buraya ekleyebilirsiniz (örneğin caching)
  );

  // 3. Tarih formatlamayı Türkçe ('tr_TR') için başlat
  await initializeDateFormatting('tr_TR', null);

  // 4. Veritabanını başlat
  await DatabaseHelper.instance.database;

  // 5. Uygulamayı başlat
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => ProductProvider()),
        ChangeNotifierProvider(create: (context) => DailyRevenueProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp'ı ShowCaseWidget ile sarıyoruz.
    // Provider yapınız bozulmadan çalışmaya devam edecek.
    return ShowCaseWidget(
      // Eğitim bittiğinde (veya kullanıcı atladığında) bu fonksiyon çalışır.
      onFinish: () async {
        // SharedPreferences'e erişip 'seen_main_tutorial' anahtarını true yap
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('seen_main_tutorial', true);
      },
      builder: (context) => MaterialApp(
        title: 'Masa Takip Uygulaması',
        debugShowCheckedModeBanner: false, // Debug bandını kaldırır
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blueGrey[800],
            foregroundColor: Colors.white,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Colors.blueGrey[700],
            foregroundColor: Colors.white,
          ),
          chipTheme: ChipThemeData(
            selectedColor: Colors.blueGrey[600],
            labelStyle: TextStyle(color: Colors.blueGrey[800]),
            secondaryLabelStyle: const TextStyle(color: Colors.white),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
