import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import 'main_screen.dart';

class PlanFeatureItem {
  final String text;
  final bool isIncluded;
  final bool isHighlighted;

  const PlanFeatureItem(
    this.text, {
    this.isIncluded = true,
    this.isHighlighted = false,
  });
}

class SubscriptionPlansScreen extends StatefulWidget {
  final String email;
  final String? currentPlan;
  final bool isFromRegistration;
  final Map<String, dynamic>? loggedInUser;

  const SubscriptionPlansScreen({
    super.key,
    required this.email,
    this.currentPlan,
    this.isFromRegistration = false,
    this.loggedInUser,
  });

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> with SingleTickerProviderStateMixin {
  int _selectedPlanIndex = 1; // Default to Annual Plan (index 1)
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isStoreAvailable = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();

    _initInAppPurchase();
  }

  void _initInAppPurchase() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (mounted) {
        setState(() {
          _isStoreAvailable = isAvailable;
        });
      }
      if (isAvailable) {
        _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
          _handlePurchaseUpdates,
          onDone: () => _purchaseSubscription?.cancel(),
          onError: (err) => debugPrint("IAP check error: $err"),
        );
      }
    } catch (e) {
      debugPrint("IAP error: $e");
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
        _onPurchaseSuccess();
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Satın alma hatası: ${purchaseDetails.error?.message ?? 'Bilinmeyen hata'}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _goToMain() {
    if (widget.loggedInUser != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainScreen(loggedInUser: widget.loggedInUser!),
        ),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _onPurchaseSuccess() async {
    final planName = _selectedPlanIndex == 1 ? "Yıllık Plan" : "Aylık Plan";
    final expiry = _selectedPlanIndex == 1 
        ? DateTime.now().add(const Duration(days: 365)) 
        : DateTime.now().add(const Duration(days: 30));
    
    try {
      await DatabaseService().saveLicenseCache(expiry, 'active', planName: planName);
    } catch (e) {
      debugPrint("License cache save error: $e");
    }

    try {
      if (widget.email.isNotEmpty) {
        await FirebaseService.instance.activateBypassLicense(widget.email, planName);
      }
    } catch (e) {
      debugPrint("Firebase plan update error: $e");
    }

    if (widget.loggedInUser != null) {
      widget.loggedInUser!['plan'] = planName;
      widget.loggedInUser!['licenseStatus'] = 'active';
      widget.loggedInUser!['expiryDate'] = expiry.toIso8601String();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Abonelik Başarılı!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          'Tebrikler! Gastrofy Premium ($planName) başarıyla aktif edildi. Tüm özelliklerden sınırsız olarak yararlanabilirsiniz.',
          style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.isFromRegistration) {
                _goToMain();
              } else {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text('Kullanmaya Başla', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);

    // If store is live & configured
    if (_isStoreAvailable) {
      try {
        const Set<String> kProductIds = {'gastrofy_monthly_299', 'gastrofy_annual_2990'};
        final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kProductIds);
        if (response.productDetails.isNotEmpty) {
          final targetId = _selectedPlanIndex == 1 ? 'gastrofy_annual_2990' : 'gastrofy_monthly_299';
          final product = response.productDetails.firstWhere(
            (p) => p.id == targetId,
            orElse: () => response.productDetails.first,
          );
          final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
          return;
        }
      } catch (e) {
        debugPrint("Store purchase attempt error: $e");
      }
    }

    // Direct desktop & testing flow
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      await _onPurchaseSuccess();
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isLoading = true);
    try {
      if (_isStoreAvailable) {
        await _inAppPurchase.restorePurchases();
        await Future.delayed(const Duration(seconds: 2));
      } else {
        // Fallback: Check local license cache
        final cached = await DatabaseService().readLicenseCache();
        if (cached['status'] == 'active') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mevcut aktif aboneliğiniz doğrulandı ve geri yüklendi."),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            _goToMain();
            return;
          }
        } else {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Geri yükleme işlemi tamamlandı. Aktif bir abonelik bulunamadıysa lütfen Apple ID hesabınızı kontrol edin."),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Geri yükleme hatası: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showContractDialog(String type) {
    final bool isPrivacy = type == 'privacy';
    final String title = isPrivacy ? 'Gizlilik Politikası' : 'Kullanım Koşulları (EULA)';
    final String content = isPrivacy 
        ? FirebaseService.defaultPrivacyText 
        : "${FirebaseService.defaultTermsText}\n\nStandart Apple Son Kullanıcı Lisans Sözleşmesi (EULA):\nhttps://www.apple.com/legal/internet-services/itunes/dev/stdeula/";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isPrivacy ? Icons.privacy_tip_outlined : Icons.gavel_rounded,
              color: const Color(0xFF0284C7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String buttonLabel = _selectedPlanIndex == 1
        ? "Yıllık Premium'a Geç (₺2,990 / Yıl)"
        : "Aylık Premium'a Geç (₺299 / Ay)";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isFromRegistration
            ? null
            : IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF1E293B), size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _handleRestorePurchases,
            icon: const Icon(Icons.restore_rounded, size: 18, color: Color(0xFF0284C7)),
            label: const Text(
              'Geri Yükle',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          if (widget.isFromRegistration &&
              widget.loggedInUser?['status'] != 'expired' &&
              widget.loggedInUser?['licenseStatus'] != 'expired')
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(
                onPressed: _goToMain,
                icon: const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF0284C7)),
                label: const Text(
                  'Şimdilik Atla',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient Element
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.22),
                    const Color(0xFFF8FAFC).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        const Center(
                          child: Icon(Icons.diamond_rounded, size: 56, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'İşletmenizi Kontrol Altına Alın',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sınırları kaldırın. Detaylı analizler, yapay zeka ve tüm masalarla gelirinizi katlayın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // SIDE-BY-SIDE PLAN CARDS
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isWide = constraints.maxWidth > 640;

                            final monthlyCard = _buildPlanCard(
                              index: 0,
                              badge: "ESNEK BAŞLANGIÇ",
                              badgeColor: const Color(0xFF64748B),
                              title: "Aylık Plan",
                              subtitle: "İşletmenizi dijitalleştirmeye hemen başlayın",
                              price: "₺299",
                              period: "/ay",
                              note: "Her ay yenilenir, taahhütsüz",
                              features: const [
                                PlanFeatureItem("Sınırsız Masa & Canlı Adisyon Takibi"),
                                PlanFeatureItem("Hızlı Satış & Gel-Al"),
                                PlanFeatureItem("Ürün, Kategori ve Menü Yönetimi"),
                                PlanFeatureItem("Müşteri Veresiye & Borç Defteri"),
                                PlanFeatureItem("Günlük Ciro ve Kasa Takibi"),
                                PlanFeatureItem("Detaylı PDF Rapor Çıktısı Alma"),
                                PlanFeatureItem("İnternetsiz (Çevrimdışı) Kesintisiz Çalışma"),
                                PlanFeatureItem("Table Intelligence (Yapay Zeka Danışmanı)", isIncluded: false),
                                PlanFeatureItem("Detaylı Ürün & Masa Satış Analitikleri", isIncluded: false),
                                PlanFeatureItem("2 Ay Ücretsiz İndirim Avantajı", isIncluded: false),
                              ],
                              isPopular: false,
                            );

                            final annualCard = _buildPlanCard(
                              index: 1,
                              badge: "EN POPÜLER • 2 AY HEDİYE",
                              badgeColor: const Color(0xFF0284C7),
                              title: "Yıllık Plan",
                              subtitle: "Tüm özellikler açık en avantajlı paket",
                              price: "₺2,990",
                              period: "/yıl",
                              note: "Aylık sadece ₺249'a gelir (₺598 Kazanç!)",
                              features: const [
                                PlanFeatureItem("Sınırsız Masa & Canlı Adisyon Takibi"),
                                PlanFeatureItem("Hızlı Satış & Gel-Al"),
                                PlanFeatureItem("Ürün, Kategori ve Menü Yönetimi"),
                                PlanFeatureItem("Müşteri Veresiye & Borç Defteri"),
                                PlanFeatureItem("Günlük Ciro ve Kasa Takibi"),
                                PlanFeatureItem("Detaylı PDF Rapor Çıktısı Alma"),
                                PlanFeatureItem("İnternetsiz (Çevrimdışı) Kesintisiz Çalışma"),
                                PlanFeatureItem("Table Intelligence (Yapay Zeka Satış Danışmanı)", isHighlighted: true),
                                PlanFeatureItem("Detaylı Ürün & Masa Satış Analitikleri", isHighlighted: true),
                                PlanFeatureItem("2 Ay Ücretsiz Kullanım (₺598 Tasarruf)", isHighlighted: true),
                              ],
                              isPopular: true,
                            );

                            if (isWide) {
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: monthlyCard),
                                    const SizedBox(width: 20),
                                    Expanded(child: annualCard),
                                  ],
                                ),
                              );
                            } else {
                              return Column(
                                children: [
                                  annualCard,
                                  const SizedBox(height: 20),
                                  monthlyCard,
                                ],
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 32),

                        // Action Button
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              children: [
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSubscribe,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 58),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 6,
                                    shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.35),
                                  ),
                                  child: _isLoading 
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                      )
                                    : Text(
                                        buttonLabel,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                ),

                                if (widget.isFromRegistration &&
                                    widget.loggedInUser?['status'] != 'expired' &&
                                    widget.loggedInUser?['licenseStatus'] != 'expired') ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: _goToMain,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF475569),
                                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                      minimumSize: const Size(double.infinity, 52),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    child: const Text(
                                      'Şimdilik Ücretsiz Deneme ile Başla',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),
                                // Clickable Legal & Restore Actions (Apple Guideline 3.1.2)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: () => _showContractDialog('terms'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Kullanım Şartları (EULA)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0284C7),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(' • ', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                    TextButton(
                                      onPressed: () => _showContractDialog('privacy'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Gizlilik Politikası',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0284C7),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(' • ', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                    TextButton(
                                      onPressed: _isLoading ? null : _handleRestorePurchases,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Satın Alımları Geri Yükle',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0284C7),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Apple Subscriptions Policy Disclosure
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade50.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.blueGrey.shade100, width: 0.8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade700),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Abonelik ve Otomatik Yenileme Bilgilendirmesi',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '• Ödeme, satın alma onayınızla birlikte Apple ID / App Store hesabınızdan tahsil edilir.\n'
                                        '• Seçtiğiniz abonelik paketi (Aylık ₺299 veya Yıllık ₺2,990), mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği takdirde otomatik olarak yenilenir.\n'
                                        '• Yenileme ücreti, mevcut dönemin bitiminden 24 saat önce hesabınızdan alınır.\n'
                                        '• Satın alma sonrasında App Store Hesap Ayarları üzerinden aboneliğinizi dilediğiniz zaman yönetebilir ve otomatik yenilemeyi kapatabilirsiniz.\n'
                                        '• Varsa ücretsiz deneme süresinin kullanılmayan kısmı, abonelik başlatıldığında iptal olur.',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          height: 1.45,
                                          color: Colors.blueGrey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required String note,
    required List<PlanFeatureItem> features,
    required bool isPopular,
  }) {
    final isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedPlanIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? const Color(0xFF0284C7).withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 22 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badge & Radio Check
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPopular
                        ? const Color(0xFF0284C7)
                        : badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: isPopular ? Colors.white : badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade400,
                      width: isSelected ? 0 : 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Title & Subtitle
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 18),

            // Price Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPopular ? const Color(0xFF059669) : Colors.blueGrey.shade400,
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),

            // Features List
            Text(
              "PAKET İÇERİĞİ",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Colors.blueGrey.shade300,
              ),
            ),
            const SizedBox(height: 14),

            ...features.map(
              (item) {
                final bool isInc = item.isIncluded;
                final bool isHigh = item.isHighlighted;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: !isInc
                              ? Colors.grey.shade100
                              : (isHigh
                                  ? const Color(0xFF0284C7).withValues(alpha: 0.14)
                                  : const Color(0xFF10B981).withValues(alpha: 0.12)),
                        ),
                        child: Icon(
                          !isInc ? Icons.close_rounded : Icons.check,
                          size: 13,
                          color: !isInc
                              ? Colors.grey.shade400
                              : (isHigh ? const Color(0xFF0284C7) : const Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isHigh
                                ? FontWeight.w700
                                : (isInc ? FontWeight.w500 : FontWeight.w400),
                            color: !isInc
                                ? Colors.grey.shade400
                                : (isHigh
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF334155)),
                            decoration: !isInc ? TextDecoration.lineThrough : null,
                            decorationColor: Colors.grey.shade300,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Select indicator button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF0284C7).withValues(alpha: 0.08)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Center(
                child: Text(
                  isSelected ? "Seçili Paket" : "Bu Planı Seç",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF0284C7) : Colors.blueGrey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
