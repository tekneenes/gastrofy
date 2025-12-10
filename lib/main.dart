import 'dart:io'; // Platform kontrolü için eklendi (Windows mu değil mi?)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// Uygulamanızın diğer import'ları
import 'screens/splash_screen.dart';
import 'services/database_helper.dart';
import 'providers/table_provider.dart';
import 'providers/product_provider.dart';
import 'providers/daily_revenue_provider.dart';

// ⚠️ API Anahtarınız
const String GEMINI_API_KEY = "YOUR_GEMINI_API_KEY_HERE";
void main() async {
  // 1. Flutter motorunu hazırla
  WidgetsFlutterBinding.ensureInitialized();

  // --- WINDOWS İÇİN EKLENEN KRİTİK BÖLÜM BAŞLANGICI ---
  // Bu blok olmazsa uygulama veritabanına bağlanmaya çalışırken sonsuz döngüde bekler.
  if (Platform.isWindows || Platform.isLinux) {
    // Masaüstü veritabanı motorunu başlat
    sqfliteFfiInit();
    // Veritabanı fabrikasını FFI olarak ayarla
    databaseFactory = databaseFactoryFfi;
  }
  // --- WINDOWS İÇİN EKLENEN KRİTİK BÖLÜM BİTİŞİ ---

  // 2. Gemini'yi başlat
  Gemini.init(apiKey: GEMINI_API_KEY);

  // 3. Tarih formatını ayarla
  await initializeDateFormatting('tr_TR', null);

  // 4. Veritabanını başlat (Try-Catch ile güvenli hale getirildi)
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint("Veritabanı başlatma hatası: $e");
    // Hata olsa bile uygulama açılsın diye akışı kesmiyoruz
  }

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
    return ShowCaseWidget(
      onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('seen_main_tutorial', true);
      },
      builder: (context) => MaterialApp(
        title: 'Masa Takip Uygulaması',
        debugShowCheckedModeBanner: false,
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
