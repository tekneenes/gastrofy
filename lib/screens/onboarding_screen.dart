import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'new_business_registration_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final bool adminExists;
  final int initialPage;

  const OnboardingScreen({
    super.key,
    this.allUsers = const [],
    this.adminExists = false,
    this.initialPage = 0,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  late int _currentPage;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title": "Hoş Geldiniz",
      "text": "Restoran yönetiminde yeni bir çağ başlıyor.",
      "lottie": "assets/animations/gastromindwelcomeanimation.json"
    },
    {
      "title": "Masalar Cebinizde",
      "text": "Tüm masaların durumunu anlık olarak takip edin.",
      "lottie": "assets/animations/gastromindwelcomenote.json",
      "speed": 0.5
    },
    {
      "title": "Hızlı Sipariş",
      "text": "Saniyeler içinde sipariş alın ve mutfağa iletin.",
      "lottie": "assets/animations/gastromindwelcomeorder.json"
    },
    {
      "title": "Detaylı Raporlar",
      "text": "Günlük, haftalık ve aylık satış raporlarına ulaşın.",
      "lottie": "assets/animations/gastromindwelcomereport.json"
    },
    {
      "title": "Veresiye Yönetimi",
      "text": "Müşteri veresiyelerini kayıt altına alın ve takip edin.",
      "lottie": "assets/animations/gastromindwelcomeoncredit.json"
    },
    // {
    //   "title": "Personel Yönetimi",
    //   "text": "Çalışanlarınızın performansını ve yetkilerini düzenleyin.",
    //   "lottie": "assets/animations/gastromindwelcomepersonel.json"
    // },
    {
      "title": "Yedekleme ve Güvenlik",
      "text": "Verileriniz güvende, istediğiniz zaman yedekleyin.",
      "lottie": "assets/animations/gastromindwelcomesecurity.json"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is OverscrollNotification &&
                      notification.overscroll > 10 &&
                      _currentPage == _onboardingData.length - 1) {
                    _finishOnboarding();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (value) {
                    setState(() {
                      _currentPage = value;
                    });
                  },
                  itemCount: _onboardingData.length,
                  itemBuilder: (context, index) {
                    return _buildOnboardingPage(
                      title: _onboardingData[index]['title']!,
                      text: _onboardingData[index]['text']!,
                      image: _onboardingData[index]['image'] as String?,
                      lottie: _onboardingData[index]['lottie'] as String?,
                      height: _onboardingData[index]['height'] as double?,
                      speed: _onboardingData[index]['speed'] as double?,
                    );
                  },
                ),
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage({
    required String title,
    required String text,
    String? image,
    String? lottie,
    double? height,
    double? speed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animasyon alanı - Mevcut boşluğun çoğunu kaplasın
                  SizedBox(
                    height: height ?? constraints.maxHeight * 0.6,
                    child: Center(
                      child: lottie != null
                          ? OnboardingAnimation(
                              lottieAsset: lottie,
                              speed: speed ?? 1.0,
                            )
                          : Image.asset(
                              image!,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(
                                  Icons.restaurant_menu,
                                  size: 100,
                                  color: Colors.teal),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildBottomControls() {
    final bool isLastPage = _currentPage == _onboardingData.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _onboardingData.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.teal
                      : Colors.teal.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _finishOnboarding,
                child: const Text('Atla',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: isLastPage ? _finishOnboarding : _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.symmetric(
                    horizontal: isLastPage ? 24 : 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isLastPage ? 14 : 30),
                  ),
                  elevation: 2,
                ),
                child: isLastPage
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Kayıt Ol",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      )
                    : const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isNavigating) return;
    _isNavigating = true;
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NewBusinessRegistrationScreen(),
        ),
      );
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }
}

class OnboardingAnimation extends StatefulWidget {
  final String lottieAsset;
  final double speed;

  const OnboardingAnimation({
    super.key,
    required this.lottieAsset,
    this.speed = 1.0,
  });

  @override
  State<OnboardingAnimation> createState() => _OnboardingAnimationState();
}

class _OnboardingAnimationState extends State<OnboardingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _setSpeed();
  }

  @override
  void didUpdateWidget(OnboardingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _setSpeed();
    }
  }

  void _setSpeed() {
    // Lottie animasyonunun süresini almak için bir callback gerekebilir 
    // veya sadece hızı kontrol edebiliriz.
    // AnimationController'ın duration'ı yerine Lottie widget'ı 
    // hızı controller üzerinden yönetebilir.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.lottieAsset,
      controller: _controller,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        _controller.repeat(reverse: false, period: composition.duration * (1 / widget.speed));
      },
      fit: BoxFit.contain,
    );
  }
}
