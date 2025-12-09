import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// Showcase ve Tutorial Keys
import 'package:showcaseview/showcaseview.dart';
import '../utils/tutorial_keys.dart';

// Sayfalar
import 'home_screen.dart' as home_page;
import 'product_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart' as settings_page;
import 'table_records_screen.dart';
import 'veresiye_screen.dart';
import 'splash_screen.dart';
import 'ai_chat_screen.dart';

final GlobalKey screenCaptureKey = GlobalKey();

/// Sayfa tanımları için yardımcı sınıf
class PageDefinition {
  final String title;
  final IconData icon;
  final Widget widget;
  final GlobalKey tutorialKey;
  final String? permissionKey;

  PageDefinition({
    required this.title,
    required this.icon,
    required this.widget,
    required this.tutorialKey,
    this.permissionKey,
  });
}

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> loggedInUser;

  const MainScreen({super.key, required this.loggedInUser});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _alwaysVisible = false;
  bool _dockVisible = false;
  Timer? _hideTimer;

  // Otomatik Oturum Kapatma
  Timer? _inactivityTimer;
  Timer? _logoutCountdownTimer;
  int _autoLogoutMinutes = 15;
  bool _isAutoLogoutEnabled = false;
  int _countdownValue = 60;

  // Dinamik Sayfa Listesi
  List<PageDefinition> _authorizedPages = [];
  bool _isLoadingPages = true;

  @override
  void initState() {
    super.initState();
    _loadDockPreference();
    _loadAutoLogoutSettings();
    _initPagesAndPermissions();
  }

  // -----------------------------------------------------------------
  // YETKİ VE SAYFA YÖNETİMİ
  // -----------------------------------------------------------------

  Future<void> _initPagesAndPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final String role = widget.loggedInUser['userRole'] ?? 'Personel';
    final bool isAdmin = role == 'Yönetici';

    // Kameralar kaldırıldı, liste güncellendi
    final List<PageDefinition> allPages = [
      PageDefinition(
        title: 'Masalar',
        icon: MdiIcons.tableChair,
        widget: home_page.HomeScreen(loggedInUser: widget.loggedInUser),
        tutorialKey: TutorialKeys.dockMasalar,
        permissionKey: null,
      ),
      PageDefinition(
        title: 'Ürünler',
        icon: MdiIcons.shoppingOutline,
        widget: ProductScreen(),
        tutorialKey: TutorialKeys.dockUrunler,
        permissionKey: 'perm_products',
      ),
      PageDefinition(
        title: 'Raporlar',
        icon: Icons.bar_chart,
        widget: const ReportScreen(),
        tutorialKey: TutorialKeys.dockRaporlar,
        permissionKey: 'perm_reports',
      ),
      PageDefinition(
        title: 'Kayıtlar',
        icon: Icons.receipt_long,
        widget: const TableRecordsScreen(),
        tutorialKey: TutorialKeys.dockKayitlar,
        permissionKey: 'perm_records',
      ),
      PageDefinition(
        title: 'Veresiye',
        icon: Icons.article_outlined,
        widget: const VeresiyeScreen(),
        tutorialKey: TutorialKeys.dockVeresiye,
        permissionKey: 'perm_veresiye',
      ),
      // Kameralar Buradan Silindi
      PageDefinition(
        title: 'AI Asistan',
        icon: MdiIcons.brain,
        widget: const AIChatScreen(),
        tutorialKey: TutorialKeys.dockAIChat,
        permissionKey: 'perm_ai',
      ),
      PageDefinition(
        title: 'Ayarlar',
        icon: MdiIcons.cogOutline,
        widget: settings_page.SettingsScreen(
          loggedInUser: widget.loggedInUser,
          initialAutoLogoutEnabled: _isAutoLogoutEnabled,
          initialAutoLogoutMinutes: _autoLogoutMinutes,
          onAutoLogoutChanged: _handleAutoLogoutChanged,
          onUserUpdated: (Map<String, dynamic> p1) {
            setState(() {
              widget.loggedInUser.clear();
              widget.loggedInUser.addAll(p1);
            });
          },
        ),
        tutorialKey: TutorialKeys.dockAyarlar,
        permissionKey: null,
      ),
    ];

    List<PageDefinition> allowed = [];

    for (var page in allPages) {
      if (isAdmin) {
        allowed.add(page);
      } else {
        if (page.permissionKey == null) {
          allowed.add(page);
        } else {
          bool isAllowed = prefs.getBool(page.permissionKey!) ?? false;
          if (isAllowed) {
            allowed.add(page);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _authorizedPages = allowed;
        _isLoadingPages = false;
      });
      _startTutorial(allowed);
    }
  }

  void _startTutorial(List<PageDefinition> currentPages) async {
    final prefs = await SharedPreferences.getInstance();
    final bool seenTutorial = prefs.getBool('seen_main_tutorial') ?? false;

    if (!seenTutorial && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        List<GlobalKey> activeKeys =
            currentPages.map((p) => p.tutorialKey).toList();
        ShowCaseWidget.of(context).startShowCase(activeKeys);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _inactivityTimer?.cancel();
    _logoutCountdownTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // OTOMATİK OTURUM KAPATMA
  // -----------------------------------------------------------------

  Future<void> _loadAutoLogoutSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoLogoutEnabled = prefs.getBool('auto_logout_enabled') ?? false;
      _autoLogoutMinutes = prefs.getInt('auto_logout_minutes') ?? 15;
    });
    if (_isAutoLogoutEnabled) resetInactivityTimer();
  }

  Future<void> _saveAutoLogoutSettings(bool enabled, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_logout_enabled', enabled);
    await prefs.setInt('auto_logout_minutes', minutes);
  }

  void _handleAutoLogoutChanged(bool enabled, int minutes) {
    setState(() {
      _isAutoLogoutEnabled = enabled;
      _autoLogoutMinutes = minutes;
    });
    _saveAutoLogoutSettings(enabled, minutes);

    if (enabled) {
      resetInactivityTimer();
    } else {
      _inactivityTimer?.cancel();
      _logoutCountdownTimer?.cancel();
    }
  }

  void resetInactivityTimer() {
    if (!_isAutoLogoutEnabled || !mounted) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
        Duration(minutes: _autoLogoutMinutes), _showLogoutCountdownDialog);
  }

  void _secureLogout() {
    _inactivityTimer?.cancel();
    _logoutCountdownTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showLogoutCountdownDialog() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _logoutCountdownTimer?.cancel();
    _countdownValue = 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Timer başlatma
            if (_logoutCountdownTimer == null ||
                !_logoutCountdownTimer!.isActive) {
              _logoutCountdownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!mounted) {
                  timer.cancel();
                  return;
                }
                if (_countdownValue > 0) {
                  setDialogState(() => _countdownValue--);
                } else {
                  timer.cancel();
                  if (Navigator.of(context).canPop()) Navigator.pop(context);
                  _secureLogout();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_bottom_rounded,
                        size: 48, color: Colors.orange.shade700),
                    const SizedBox(height: 16),
                    const Text('Oturum Kapatılıyor',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Hareketsizlik nedeniyle oturumunuz sonlandırılacak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: _countdownValue / 60,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.orange,
                          ),
                        ),
                        Text('$_countdownValue',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _logoutCountdownTimer?.cancel();
                          Navigator.pop(context);
                          resetInactivityTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Oturum devam ediyor.'),
                              backgroundColor: Colors.teal,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Devam Et',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _logoutCountdownTimer?.cancel();
    });
  }

  // -----------------------------------------------------------------
  // DOCK YÖNETİMİ
  // -----------------------------------------------------------------

  Future<void> _loadDockPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alwaysVisible = prefs.getBool('dock_always_visible') ?? false;
      if (_alwaysVisible) {
        _dockVisible = true;
      } else if (_selectedIndex == 0) {
        _dockVisible = true;
        _startHideTimer();
      }
    });
  }

  Future<void> _saveDockPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dock_always_visible', value);
  }

  void _onItemTapped(int index) {
    resetInactivityTimer();
    setState(() => _selectedIndex = index);
    _showDockTemporarily();
  }

  void _toggleDock(bool show) {
    if (!_alwaysVisible) {
      setState(() => _dockVisible = show);
      if (show) _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_alwaysVisible) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!_alwaysVisible && mounted) setState(() => _dockVisible = false);
    });
  }

  void _showDockTemporarily() {
    _toggleDock(true);
  }

  void _showDockSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Menü Ayarları"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SwitchListTile(
              title: const Text("Menü sürekli açık kalsın"),
              subtitle: const Text("Otomatik gizlenmeyi kapatır."),
              activeColor: Colors.teal,
              value: _alwaysVisible,
              onChanged: (val) {
                resetInactivityTimer();
                setState(() {
                  _alwaysVisible = val;
                  _dockVisible = val;
                  if (!val) _startHideTimer();
                });
                _saveDockPreference(val);
                setStateDialog(() {});
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPages) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      body: GestureDetector(
        onTap: () {
          _showDockTemporarily();
          resetInactivityTimer();
        },
        onTapDown: (_) => resetInactivityTimer(),
        onPanDown: (_) => resetInactivityTimer(),
        onVerticalDragUpdate: (details) {
          _showDockTemporarily();
          resetInactivityTimer();
          final double? delta = details.primaryDelta;
          if (delta == null) return;
          if (delta < -10) {
            _toggleDock(true);
          } else if (delta > 10) _toggleDock(false);
        },
        child: RepaintBoundary(
          key: screenCaptureKey,
          child: Stack(
            children: [
              // Ana İçerik
              Positioned.fill(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _authorizedPages.map((p) => p.widget).toList(),
                ),
              ),
              // Dock
              _buildModernDock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDock() {
    // Dock genişliği içerik kadar olsun ama çok dar olmasın
    final double dockWidth =
        (_authorizedPages.length * 60.0 + 40.0).clamp(300.0, 600.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        offset: _dockVisible ? Offset.zero : const Offset(0, 2.0),
        child: SafeArea(
          child: GestureDetector(
            onLongPress: () {
              resetInactivityTimer();
              _showDockSettings();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 70,
              width: dockWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 1.5),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_authorizedPages.length, (index) {
                        return _buildDockIcon(index);
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockIcon(int index) {
    final page = _authorizedPages[index];
    final isSelected = _selectedIndex == index;

    return Showcase(
      key: page.tutorialKey,
      title: page.title,
      description: '${page.title} sayfasına git',
      targetShapeBorder: const CircleBorder(),
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // HATA DÜZELTME: easeOutBack 0'ın altına inip gölge hatası veriyordu.
          // easeOutCubic hem yumuşak hem de güvenlidir.
          curve: Curves.easeOutCubic,

          // Seçili ikon hafifçe yukarı kalkar
          transform: Matrix4.translationValues(0, isSelected ? -6 : 0, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            shape: BoxShape.circle,
            // HATA DÜZELTME: null yerine boş liste veya şeffaf gölge
            // interpolasyonu (geçişi) garantiye alır.
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    const BoxShadow(
                        color: Colors.transparent,
                        blurRadius: 0,
                        offset: Offset.zero)
                  ],
          ),
          child: Icon(
            page.icon,
            size: 26,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
