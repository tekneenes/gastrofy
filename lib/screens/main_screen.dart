import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart';
import '../utils/tutorial_keys.dart';
import '../widgets/custom_tutorial_tooltip.dart';

// Sayfalar
import 'home_screen.dart' as home_page;
import 'product_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart' as settings_page;
import 'table_records_screen.dart';
import 'veresiye_screen.dart';
import 'splash_screen.dart';
import 'ai_chat_screen.dart';
import 'subscription_plans_screen.dart';
import '../services/database_service.dart';
import '../widgets/plan_feature_lock_view.dart';

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
  bool _alwaysVisible = true; // Default to always visible
  bool _dockVisible = true;   // Default to visible
  Timer? _hideTimer;

  // Otomatik Oturum Kapatma
  Timer? _inactivityTimer;
  Timer? _logoutCountdownTimer;
  int _autoLogoutMinutes = 15;
  bool _isAutoLogoutEnabled = false;
  int _countdownValue = 60;

  // Dinamik Sayfa Listesi
  List<PageDefinition> _authorizedPages = [];
  final Set<int> _visitedIndices = {0};
  bool _isLoadingPages = false;

  @override
  void initState() {
    super.initState();
    // İlk sayfa (Masalar) hemen hazır olsun, yükleme ekranı ve kasma yaşanmasın
    _authorizedPages = [
      PageDefinition(
        title: 'Masalar',
        icon: MdiIcons.tableChair,
        widget: home_page.HomeScreen(loggedInUser: widget.loggedInUser),
        tutorialKey: TutorialKeys.dockMasalar,
        permissionKey: null,
      ),
    ];
    _loadDockPreference();
    _loadAutoLogoutSettings();
    _initPagesAndPermissions();
    
    // Uygulama açıldığında son giriş zamanını güncelle (Auto-Delete için) - UI animasyonunu aksatmamak için hafif gecikmeli
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          FirebaseService.instance.updateLastLogin(widget.loggedInUser);
        }
      });
    });
  }

  // -----------------------------------------------------------------
  // YETKİ VE SAYFA YÖNETİMİ
  // -----------------------------------------------------------------

  Future<void> _initPagesAndPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final String role = widget.loggedInUser['userRole'] ?? 'Personel';
    final bool isAdmin = role == 'Yönetici';

    final licenseInfo = await DatabaseService().getLicenseRemainingInfo();
    final bool isExpired = licenseInfo['isExpired'] == true;
    final String currentPlan = licenseInfo['planName'] ?? widget.loggedInUser['plan'] ?? 'Ücretsiz Deneme';
    final bool isAnnualOrTrial = currentPlan.contains('Yıllık') || currentPlan.contains('Deneme') || currentPlan.contains('Trial');
    final String userEmail = widget.loggedInUser['userEmail']?.toString() ?? '';

    // Süresi dolmuşsa lisans yenileme uyarısı
    if (isExpired && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showExpiredSubscriptionDialog();
      });
    }

    // AI Danışmanı: Yıllık Plan ve Deneme Sürümünde açık, Aylık Planda kilitli
    final Widget aiWidget = isAnnualOrTrial
        ? const AIChatScreen()
        : PlanFeatureLockView(
            featureName: 'Table Intelligence (Yapay Zeka Satış Danışmanı)',
            description: 'İşletmenizin satışlarını katlayan, sipariş önerileri ve masa doluluk analitiği sunan Table Intelligence, Yıllık Plan üyelerine özeldir.',
            email: userEmail,
            loggedInUser: widget.loggedInUser,
            onUpgraded: () => _initPagesAndPermissions(),
          );

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
      PageDefinition(
        title: 'AI Asistan',
        icon: MdiIcons.brain,
        widget: aiWidget,
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

  void _showExpiredSubscriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Abonelik Süreniz Sona Erdi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Gastrofy restoran yönetim sistemini kullanmaya devam etmek için lütfen bir abonelik planı seçiniz veya satın alımlarınızı geri yükleyiniz.',
          style: TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final email = widget.loggedInUser['userEmail']?.toString() ?? '';
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionPlansScreen(
                    email: email,
                    loggedInUser: widget.loggedInUser,
                  ),
                ),
              );
              _initPagesAndPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Abonelik Paketlerini İncele', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkContractsReapproval() async {
    final contracts = await FirebaseService.instance.getContracts();
    if (contracts.isEmpty) return;

    final String privacy = contracts['privacy'] ?? '';
    final String terms = contracts['terms'] ?? '';

    // İçerik boşsa uyarı gösterme (Kullanıcı isteği: "şuan boş panelde ama uyarı çıktı")
    if (privacy.trim().isEmpty && terms.trim().isEmpty) return;

    final Timestamp? updatedAt = contracts['updatedAt'] as Timestamp?;
    if (updatedAt == null) return;

    // Kullanıcı verisinden son onay tarihini al
    Timestamp? lastAccepted = widget.loggedInUser['lastAcceptedTermsAt'] as Timestamp?;
    
    // Eğer veride yoksa (eski kullanıcı), Firestore'dan güncel veriyi çekmeyi dene
    if (lastAccepted == null) {
      final email = widget.loggedInUser['userEmail'] ?? '';
      if (email.isNotEmpty) {
        final q = FirebaseFirestore.instance.collection('companies').where('email', isEqualTo: email);
        final snap = await q.get();
        if (snap.docs.isNotEmpty) {
          lastAccepted = snap.docs.first.data()['lastAcceptedTermsAt'] as Timestamp?;
        }
      }
    }

    // Karşılaştır: Eğer sözleşme güncellenme tarihi, kullanıcının onay tarihinden sonraysa
    if (lastAccepted == null || updatedAt.toDate().isAfter(lastAccepted.toDate())) {
      if (!mounted) return;
      _showMandatoryApprovalDialog(contracts);
    }
  }

  void _showMandatoryApprovalDialog(Map<String, dynamic> contracts) {
    bool isPrivacyAccepted = false;
    bool isTermsAccepted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool canAccept = isPrivacyAccepted && isTermsAccepted;

          return Dialog.fullscreen(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Sözleşme Güncellemesi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.teal,
                  automaticallyImplyLeading: false,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.security_update_warning_rounded, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'Hizmet Şartlarımız Güncellendi',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Size daha iyi hizmet verebilmek için Gizlilik Politikası ve Kullanım Koşullarımızı güncelledik. Devam edebilmek için lütfen yeni şartları inceleyip onaylayın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 32),
                        _buildContractApprovalTile(
                          title: 'Gizlilik Politikası',
                          isAccepted: isPrivacyAccepted,
                          onChanged: (val) => setDialogState(() => isPrivacyAccepted = val!),
                          onTapText: () => _showTextContentDialog('Gizlilik Politikası', contracts['privacy'] ?? FirebaseService.defaultPrivacyText),
                        ),
                        const SizedBox(height: 16),
                        _buildContractApprovalTile(
                          title: 'Kullanım Koşulları',
                          isAccepted: isTermsAccepted,
                          onChanged: (val) => setDialogState(() => isTermsAccepted = val!),
                          onTapText: () => _showTextContentDialog('Kullanım Koşulları', contracts['terms'] ?? FirebaseService.defaultTermsText),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: canAccept ? () async {
                        final email = widget.loggedInUser['userEmail'] ?? '';
                        await FirebaseService.instance.updateContractAcceptanceDate(email);
                        if (mounted) Navigator.pop(context);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Onaylıyorum ve Devam Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContractApprovalTile({
    required String title,
    required bool isAccepted,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onTapText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        value: isAccepted,
        onChanged: onChanged,
        activeColor: Colors.teal,
        title: InkWell(
          onTap: onTapText,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, decoration: TextDecoration.underline, color: Colors.teal),
          ),
        ),
        subtitle: const Text('Okudum ve kabul ediyorum'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  void _showTextContentDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Text(title, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.teal,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(content, style: const TextStyle(fontSize: 16, height: 1.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _startTutorial(List<PageDefinition> currentPages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool seen = prefs.getBool('seen_main_tutorial') ?? false;
      if (seen) return;

      if (mounted) {
        _showTutorialWelcomeDialog(currentPages);
      }
    } catch (e) {
      debugPrint('Tutorial check error: $e');
    }
  }

  void _showTutorialWelcomeDialog(List<PageDefinition> currentPages) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.teal.shade600),
            const SizedBox(width: 10),
            const Text('Hoş Geldiniz!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulamayı daha etkili kullanabilmeniz için kısa bir tur yapmak ister misiniz?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(
              'Şimdi ana sayfa üzerindeki temel özellikleri ve hızlı işlem butonlarını adım adım göstereceğiz.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('seen_main_tutorial', true);
              } catch (_) {}
            },
            child: Text(
              'Eğitimi Atla',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('seen_main_tutorial', true);
              } catch (_) {}
              _executeShowcase(currentPages);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eğitime Başla'),
          ),
        ],
      ),
    );
  }

  void _executeShowcase(List<PageDefinition> currentPages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Alt menü (Dock) tuşları
      List<GlobalKey> activeKeys =
          currentPages.map((p) => p.tutorialKey).toList();

      // Eğer Ana Sayfadaysak (index 0), yukarıdaki butonları da sıraya ekleyelim
      if (_selectedIndex == 0) {
        activeKeys.insertAll(0, [
          // ÜST ŞERİT (AppBar)
          TutorialKeys.homeCikis,
          TutorialKeys.homeDoviz,
          // APPBAR BUTONLARI (Sağ Üst)
          TutorialKeys.homeMasaEkle,
          TutorialKeys.homeHizliSatis,
          TutorialKeys.homeGorunumModu,
          TutorialKeys.homeYenile,
          TutorialKeys.homeIstatistikler,
          // ALT TABAKA
          TutorialKeys.homeBolgeler,
          TutorialKeys.homeMasalarArea,
        ]);
      }

      ShowCaseWidget.of(context).startShowCase(activeKeys);
    });
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
      _alwaysVisible = prefs.getBool('dock_always_visible') ?? true;
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
    setState(() {
      _selectedIndex = index;
      _visitedIndices.add(index);
    });
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
    if (_isLoadingPages && _authorizedPages.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _showDockTemporarily();
          resetInactivityTimer();
        },
        onPointerMove: (_) => resetInactivityTimer(),
        child: RepaintBoundary(
          key: screenCaptureKey,
          child: Stack(
            children: [
              // Ana İçerik - Tembel (Lazy) Yükleme ile sadece ziyaret edilen sayfalar inşa edilir
              Positioned.fill(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: List.generate(_authorizedPages.length, (index) {
                    if (_visitedIndices.contains(index)) {
                      return _authorizedPages[index].widget;
                    }
                    return const SizedBox.shrink();
                  }),
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

    final themeColor = isSelected ? Colors.blueAccent : Colors.teal;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: isSelected ? 12 : 0),
      child: Showcase.withWidget(
        key: page.tutorialKey,
        targetShapeBorder: const CircleBorder(),
        container: CustomTutorialTooltip(
          title: page.title,
          description: '${page.title} sayfasına git',
          themeColor: themeColor,
        ),
        child: GestureDetector(
          onTap: () => _onItemTapped(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
              shape: BoxShape.circle,
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
                        offset: Offset.zero,
                      )
                    ],
            ),
            child: Icon(
              page.icon,
              size: 26,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
