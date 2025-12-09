import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:video_player/video_player.dart';
import 'login_screen.dart';
import '../services/database_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _dbService = DatabaseService();
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadDataAndNavigate();
  }

  void _initializeVideo() {
    // Video dosyasının assets/splash_video.mp4 yolunda olduğunu varsayıyoruz
    // pubspec.yaml dosyasına bu asset'i eklemeyi unutmayın
    _videoController = VideoPlayerController.asset('assets/splash_video.mp4')
      ..initialize().then((_) {
        // Video yüklendiğinde oynat, döngüye al ve sessize al
        _videoController.play();
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      }).catchError((error) {
        debugPrint("Video yükleme hatası: $error");
      });
  }

  /// Gerekli verileri yükler ve ardından LoginScreen'e yönlendirir.
  Future<void> _loadDataAndNavigate() async {
    // Splash ekranının en az 3 saniye görünmesini sağla
    await Future.delayed(const Duration(seconds: 6));

    // Veritabanı kontrollerini yap
    final allUsers = await _dbService.getAllUsers();
    final adminExists = await _dbService.hasAdmin();

    // Widget'ın hala ekranda olduğundan emin ol
    if (mounted) {
      // Verileri yükleyerek LoginScreen'e git
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            allUsers: allUsers,
            adminExists: adminExists,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black, // Normal arka plan siyah
      body: Stack(
        children: [
          // 1. KATMAN: Video Arka Planı
          if (_isVideoInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(color: Colors.black), // Video yüklenene kadar siyah ekran

          // 2. KATMAN: Hafif Karartma (Overlay)
          // Videonun çok parlak olması durumunda yazıların okunmasını sağlar
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // 3. KATMAN: İçerik (Logo ve Yazılar)
          // Logo ve Yükleniyor... yazısı

          // Geliştirici Bilgisi
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildDeveloperInfo(),
          ),
        ],
      ),
    );
  }

  /// Geliştirici bilgisi widget'ı
  Widget _buildDeveloperInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo karanlık modda daha iyi görünsün diye hafif bir kapsayıcı eklenebilir
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            'assets/metsoft.png',
            height: 80,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.code, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Metsoft Yazılım',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.white, // Beyaz yazı
            fontSize: 16,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                blurRadius: 3.0,
                color: Colors.black,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AnimatedTextKit(
          repeatForever: false,
          totalRepeatCount: 1,
          animatedTexts: [
            TypewriterAnimatedText(
              'Developed by MET • Powered by MetSoft',
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.7), // Açık gri yazı
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
              speed: const Duration(milliseconds: 70),
              cursor: '',
            )
          ],
        ),
      ],
    );
  }
}
