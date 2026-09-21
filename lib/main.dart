import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Uygulamanızın diğer import'ları
import 'screens/splash_screen.dart';
// ...
// (We will replace just the MaterialApp instantiation below)
import 'services/database_helper.dart';
import 'providers/table_provider.dart';
import 'providers/product_provider.dart';
import 'providers/daily_revenue_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/table_report_provider.dart';
import 'providers/product_report_provider.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Flutter motorunu hazırla
  WidgetsFlutterBinding.ensureInitialized();

  // macOS / Masaüstü klavye tekrarlarında oluşan Flutter framework assertion hatasını filtrele
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('_pressedKeys.containsKey')) {
      return;
    }
    FlutterError.presentError(details);
  };

  // Firebase Başlatma
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase başlatılamadı (Dosyalar eksik olabilir): $e");
  }

  // 0. Dotenv'i yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(".env dosyası yüklenemedi: $e");
  }

  // --- WINDOWS/LINUX İÇİN EKLENEN KRİTİK BÖLÜM BAŞLANGICI ---
  if (!kIsWeb) {
    // ignore: avoid_relative_lib_imports
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux;
    if (isDesktop) {
      // Masaüstü veritabanı motorunu başlat
      sqfliteFfiInit();
      // Veritabanı fabrikasını FFI olarak ayarla
      databaseFactory = databaseFactoryFfi;
    }
  }
  // --- WINDOWS/LINUX İÇİN EKLENEN KRİTİK BÖLÜM BİTİŞİ ---

  // 2. Gemini'yi başlat
  String apiKey = "YOUR_GEMINI_API_KEY_HERE";
  try {
    if (dotenv.isInitialized) {
      apiKey = dotenv.env['GEMINI_API_KEY'] ?? apiKey;
    }
  } catch (e) {
    debugPrint("Dotenv erişim hatası: $e");
  }
  Gemini.init(apiKey: apiKey);

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
        ChangeNotifierProvider(create: (context) => CurrencyProvider()),
        ChangeNotifierProvider(create: (context) => TableReportProvider()),
        ChangeNotifierProvider(create: (context) => ProductReportProvider()),
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
      blurValue: 1,
      builder: (context) => MaterialApp(
        title: 'Gastrofy',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr', 'TR'),
          Locale('en', 'US'),
        ],
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
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
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
