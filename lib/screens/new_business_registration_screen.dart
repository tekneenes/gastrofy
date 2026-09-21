import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import 'onboarding_screen.dart';
import 'subscription_plans_screen.dart';

class NewBusinessRegistrationScreen extends StatefulWidget {
  const NewBusinessRegistrationScreen({super.key});

  @override
  State<NewBusinessRegistrationScreen> createState() =>
      _NewBusinessRegistrationScreenState();
}

class _NewBusinessRegistrationScreenState
    extends State<NewBusinessRegistrationScreen> {
  final _dbService = DatabaseService();
  final PageController _pageController = PageController();
  final ScrollController _step1ScrollController = ScrollController();
  final ScrollController _step2ScrollController = ScrollController();
  int _currentStep = 0;
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Step 1: İşletme Bilgileri
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _taxNumberController = TextEditingController();

  // Step 2: Yönetici Bilgileri
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminConfirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 3: Sözleşmeler
  bool _privacyPolicyAccepted = false;
  bool _termsOfUseAccepted = false;

  bool _isLoading = false;
  String _privacyText = "";
  String _termsText = "";

  // Placeholder if loading before fetch
  static const String _loadingText = "Yükleniyor...";

  @override
  void initState() {
    super.initState();
    _privacyText = FirebaseService.defaultPrivacyText;
    _termsText = FirebaseService.defaultTermsText;
    _loadContracts();

    // Listen to password changes for live feedback
    _adminPasswordController.addListener(() => setState(() {}));
    _adminConfirmPasswordController.addListener(() => setState(() {}));
  }

  Future<void> _loadContracts() async {
    final dynamicContracts = await FirebaseService.instance.getContracts();
    if (dynamicContracts.isNotEmpty) {
      setState(() {
        _privacyText = (dynamicContracts['privacy']?.trim().isNotEmpty ?? false)
            ? dynamicContracts['privacy']!
            : FirebaseService.defaultPrivacyText;
        _termsText = (dynamicContracts['terms']?.trim().isNotEmpty ?? false)
            ? dynamicContracts['terms']!
            : FirebaseService.defaultTermsText;
      });
    }
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    } else if (Platform.isMacOS) {
      final macosInfo = await deviceInfo.macOsInfo;
      return macosInfo.systemGUID ?? 'unknown_macos';
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.deviceId;
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      return linuxInfo.machineId ?? 'unknown_linux';
    }
    return 'unknown_device';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _step1ScrollController.dispose();
    _step2ScrollController.dispose();
    _companyNameController.dispose();
    _addressController.dispose();
    _companyPhoneController.dispose();
    _taxNumberController.dispose();
    _adminNameController.dispose();
    _adminPhoneController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0 && Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep > 0) {
          _prevStep();
        } else if (!Navigator.of(context).canPop()) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.teal),
            onPressed: () {
              if (_currentStep > 0) {
                _prevStep();
              } else {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const OnboardingScreen(),
                    ),
                  );
                }
              }
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Yeni İşletme Kaydı",
            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Custom Progress Indicator
              _buildCustomProgressIndicator(),
              
              const SizedBox(height: 20),

              // Content PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                    });
                  },
                  children: [
                    _buildStep1Content(),
                    _buildStep2Content(),
                    _buildStep3Content(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomProgressIndicator() {
    final steps = ["İşletme", "Yönetici", "Onay"];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                // Step Circle & Label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                          color: (i == _currentStep || i < _currentStep)
                              ? Colors.teal
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _currentStep
                                ? Colors.teal
                                : Colors.transparent,
                            width: 2,
                          )),
                      child: Center(
                        child: i < _currentStep
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : Text(
                                "${i + 1}",
                                style: TextStyle(
                                    color: (i == _currentStep)
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[i],
                      style: TextStyle(
                        color: (i == _currentStep || i < _currentStep)
                            ? Colors.teal
                            : Colors.grey,
                        fontWeight: i == _currentStep
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // Connector Line (if not last item)
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < _currentStep
                          ? Colors.teal
                          : Colors.grey.shade300,
                      margin: const EdgeInsets.only(
                          bottom: 20, left: 8, right: 8), // Vertical align with circle
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _step1FormKey,
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        controller: _step1ScrollController,
                        child: SingleChildScrollView(
                          controller: _step1ScrollController,
                          padding: const EdgeInsets.only(left: 8, right: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            _StaggeredAnimatedItem(
                              delay: 0,
                              child: _buildStepHeader(
                                title: "İşletme Bilgileri",
                                subtitle: "Restoranınızın temel bilgilerini girin.",
                                imagePath: "assets/gastromind512.png",
                                iconFallback: Icons.store_mall_directory,
                                availableHeight: constraints.maxHeight,
                              ),
                            ),
                            _StaggeredAnimatedItem(
                              delay: 100,
                              child: _buildTextField(
                                controller: _companyNameController,
                                label: "İşletme Adı",
                                icon: Icons.store,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Lütfen işletme adını girin";
                                  }
                                  if (v.trim().length < 2) {
                                    return "İşletme adı en az 2 karakter olmalıdır";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _StaggeredAnimatedItem(
                              delay: 200,
                              child: _buildTextField(
                                controller: _addressController,
                                label: "Adres (İsteğe Bağlı)",
                                icon: Icons.location_on,
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _StaggeredAnimatedItem(
                              delay: 300,
                              child: _buildTextField(
                                controller: _companyPhoneController,
                                label: "İşletme Telefonu (İsteğe Bağlı)",
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) {
                                  if (v != null && v.trim().isNotEmpty && v.trim().length < 10) {
                                    return "Geçerli bir telefon numarası girin (en az 10 hane)";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _StaggeredAnimatedItem(
                              delay: 400,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTextField(
                                      controller: _taxNumberController,
                                      label: "Vergi Numarası (İsteğe Bağlı)",
                                      icon: Icons.confirmation_number_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      validator: (v) {
                                        // İsteğe bağlı
                                        if (v != null && v.trim().isNotEmpty) {
                                          if (v.trim().length != 10 && v.trim().length != 11) {
                                            return "Vergi no 10 haneli VKN veya 11 haneli TCKN olmalıdır";
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.lock_person_outlined, size: 14, color: Colors.teal.shade600),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Vergi numarası isteğe bağlıdır. Sadece bu cihazda saklanır ve sunucularımıza gönderilmez.",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.teal.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StaggeredAnimatedItem(
                      delay: 500,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 20),
                        child: _buildButtonsRow(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildStep2Content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _step2FormKey,
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        controller: _step2ScrollController,
                        child: SingleChildScrollView(
                          controller: _step2ScrollController,
                          padding: const EdgeInsets.only(left: 8, right: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            _StaggeredAnimatedItem(
                              delay: 0,
                              child: _buildStepHeader(
                                title: "Yönetici Bilgileri",
                                subtitle: "Sistemi yönetecek yetkili hesabı oluşturun.",
                                imagePath: "assets/gastromind512.png",
                                iconFallback: Icons.admin_panel_settings,
                                availableHeight: constraints.maxHeight,
                              ),
                            ),
                            _StaggeredAnimatedItem(
                              delay: 100,
                              child: _buildTextField(
                                controller: _adminNameController,
                                label: "Yönetici Adı Soyadı",
                                icon: Icons.person,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Yönetici adı gerekli";
                                  }
                                  if (v.trim().length < 3) {
                                    return "Ad soyad en az 3 karakter olmalıdır";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _StaggeredAnimatedItem(
                              delay: 200,
                              child: _buildTextField(
                                controller: _adminEmailController,
                                label: "E-posta Adresi",
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "E-posta gerekli";
                                  }
                                  final email = v.trim();
                                  if (!email.contains('@') || !email.contains('.')) {
                                    return "Geçerli bir e-posta girin";
                                  }
                                  return null;
                                },
                              ),
                          ),
                          const SizedBox(height: 12),
                          _StaggeredAnimatedItem(
                            delay: 300,
                            child: _buildTextField(
                              controller: _adminPhoneController,
                              label: "Cep Telefonu",
                              icon: Icons.phone_iphone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StaggeredAnimatedItem(
                            delay: 400,
                            child: TextFormField(
                              controller: _adminPasswordController,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (val) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: "Şifre (Sadece Rakam)",
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, color: Colors.teal),
                                      if (_adminPasswordController.text.isNotEmpty &&
                                          _adminConfirmPasswordController.text.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          _adminPasswordController.text ==
                                                  _adminConfirmPasswordController.text
                                              ? Icons.check_circle
                                              : Icons.error_outline,
                                          color: _adminPasswordController.text ==
                                                  _adminConfirmPasswordController.text
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _adminPasswordController.text.isEmpty || _adminConfirmPasswordController.text.isEmpty
                                        ? Colors.grey.shade300
                                        : (_adminPasswordController.text == _adminConfirmPasswordController.text
                                            ? Colors.green
                                            : Colors.red),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _adminPasswordController.text == _adminConfirmPasswordController.text
                                        ? Colors.green
                                        : Colors.red,
                                    width: 2.0,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (v) => v!.length < 6
                                  ? "Şifre en az 6 rakam olmalı"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StaggeredAnimatedItem(
                            delay: 500,
                            child: TextFormField(
                              controller: _adminConfirmPasswordController,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (val) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: "Şifreyi Tekrar Girin",
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_outline, color: Colors.teal),
                                      if (_adminConfirmPasswordController.text.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          _adminPasswordController.text ==
                                                  _adminConfirmPasswordController.text
                                              ? Icons.check_circle
                                              : Icons.error_outline,
                                          color: _adminPasswordController.text ==
                                                  _adminConfirmPasswordController.text
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                suffixIcon: null,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _adminConfirmPasswordController.text.isEmpty
                                        ? Colors.grey.shade300
                                        : (_adminPasswordController.text == _adminConfirmPasswordController.text
                                            ? Colors.green
                                            : Colors.red),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _adminPasswordController.text == _adminConfirmPasswordController.text
                                        ? Colors.green
                                        : Colors.red,
                                    width: 2.0,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              validator: (v) {
                                if (v != _adminPasswordController.text) {
                                  return "Şifreler uyuşmuyor";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StaggeredAnimatedItem(
                    delay: 500,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 20),
                      child: _buildButtonsRow(),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep3Content() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 20),
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StaggeredAnimatedItem(
                          delay: 0,
                          child: _buildStepHeader(
                            title: "Sözleşme Onayı",
                            subtitle: "Kullanım şartlarını ve gizliliği onaylayın.",
                            imagePath: "assets/gastromind512.png",
                            iconFallback: Icons.verified_user,
                            availableHeight: constraints.maxHeight,
                          ),
                        ),
                        _StaggeredAnimatedItem(
                          delay: 200,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade100),
                            ),
                            child: Column(
                              children: [
                                _buildContractTile(
                                  title: "Gizlilik Sözleşmesi",
                                  isAccepted: _privacyPolicyAccepted,
                                  onTap: () => _showContractDialog(
                                    "Gizlilik Sözleşmesi",
                                    _privacyText,
                                    (val) =>
                                        setState(() => _privacyPolicyAccepted = val),
                                  ),
                                ),
                                const Divider(),
                                _buildContractTile(
                                  title: "Kullanım Koşulları",
                                  isAccepted: _termsOfUseAccepted,
                                  onTap: () => _showContractDialog(
                                    "Kullanım Koşulları",
                                    _termsText,
                                    (val) => setState(() => _termsOfUseAccepted = val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                  const SizedBox(height: 16),
                  _StaggeredAnimatedItem(
                    delay: 400,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 20),
                      child: _buildButtonsRow(),
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

  Widget _buildContractTile({
    required String title,
    required bool isAccepted,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAccepted ? Colors.teal.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? Colors.teal.shade200 : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAccepted ? Colors.teal : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAccepted ? Icons.check : Icons.description_outlined,
                  color: isAccepted ? Colors.white : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isAccepted ? FontWeight.bold : FontWeight.w500,
                        color: isAccepted ? Colors.teal.shade900 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAccepted ? "Onaylandı" : "Okumak için tıklayın",
                      style: TextStyle(
                        fontSize: 12,
                        color: isAccepted ? Colors.teal.shade700 : Colors.grey.shade500,
                        fontWeight: isAccepted ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAccepted)
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400)
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(Icons.verified, color: Colors.teal, size: 24),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContractDialog(
      String title, String content, Function(bool) onAccept) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final ScrollController scrollController = ScrollController();
        double scrollProgress = 0.0;
        bool isSwitchedOn = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            scrollController.addListener(() {
              if (scrollController.hasClients) {
                final progress = scrollController.offset /
                    (scrollController.position.maxScrollExtent == 0
                        ? 1
                        : scrollController.position.maxScrollExtent);
                if (progress != scrollProgress) {
                  setDialogState(() {
                    scrollProgress = progress.clamp(0.0, 1.0);
                  });
                }
              }
            });

            final bool hasReadEnd = scrollProgress >= 0.9;

            return Dialog.fullscreen(
              backgroundColor: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balancing spacer
                        ],
                      ),
                    ),
                  ),
                  LinearProgressIndicator(
                    value: scrollProgress,
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                    minHeight: 3,
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: scrollController,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Text(
                          content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: Colors.grey.shade800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!hasReadEnd)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Devam etmek için lütfen metnin sonuna kadar kaydırın.",
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  isSwitchedOn = !isSwitchedOn;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSwitchedOn ? Colors.teal.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSwitchedOn ? Colors.teal.shade200 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Metni okudum ve tüm şartları onaylıyorum.",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSwitchedOn ? FontWeight.w600 : FontWeight.normal,
                                          color: isSwitchedOn ? Colors.teal.shade900 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: isSwitchedOn,
                                      activeColor: Colors.teal,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          isSwitchedOn = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: (hasReadEnd && isSwitchedOn)
                              ? () {
                                  onAccept(true);
                                  Navigator.of(context).pop();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            disabledBackgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: (hasReadEnd && isSwitchedOn) ? 4 : 0,
                          ),
                          child: Text(
                            "Onaylıyorum",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: (hasReadEnd && isSwitchedOn) ? Colors.white : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildStepHeader({
    required String title,
    required String subtitle,
    required String imagePath,
    required IconData iconFallback,
    required double availableHeight,
  }) {
    // If we have less than 500px vertical space (approx), hide the image
    // The availableHeight coming from LayoutBuilder already accounts for some padding/parent widgets
    // Let's use a threshold.
    bool showImage = availableHeight > 550;

    return Column(
      children: [
        if (showImage) ...[
          Image.asset(
            imagePath,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(iconFallback, size: 80, color: Colors.teal);
            },
          ),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildButtonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: _prevStep,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              side: const BorderSide(color: Colors.teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Geri",
                style: TextStyle(color: Colors.teal, fontSize: 16)),
          )
        else
          const SizedBox.shrink(),

        ElevatedButton(
          onPressed:
              _currentStep == 2 ? (_isLoading ? null : _registerBusiness) : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentStep == 2 ? "Kaydı Tamamla" : "Devam Et",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    if (_currentStep < 2) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 20),
                    ]
                  ],
                ),
        ),
      ],
    );
  }

  void _nextStep() {
    // Validate current step
    bool isValid = false;
    if (_currentStep == 0) {
      final formValid = _step1FormKey.currentState?.validate() ?? false;
      if (_companyNameController.text.trim().isEmpty) {
        _showError("Lütfen işletme adını girin.");
        return;
      }
      if (!formValid) {
        _showError("Lütfen işletme bilgilerindeki hataları düzeltin.");
        return;
      }
      isValid = true;
    } else if (_currentStep == 1) {
      final formValid = _step2FormKey.currentState?.validate() ?? false;
      if (_adminNameController.text.trim().isEmpty) {
        _showError("Lütfen yönetici adını girin.");
        return;
      } else if (_adminEmailController.text.trim().isEmpty ||
          !_adminEmailController.text.contains('@') ||
          !_adminEmailController.text.contains('.')) {
        _showError("Geçerli bir e-posta adresi girin.");
        return;
      } else if (_adminPasswordController.text.length < 6) {
        _showError("Şifre en az 6 rakam olmalı.");
        return;
      } else if (_adminPasswordController.text !=
          _adminConfirmPasswordController.text) {
        _showError("Şifreler birbiriyle uyuşmuyor.");
        return;
      }
      if (!formValid) {
        _showError("Lütfen yönetici bilgilerindeki hataları düzeltin.");
        return;
      }
      isValid = true;
    } else {
      isValid = true;
    }

    if (isValid) {
      if (_currentStep < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeInOut
        );
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
    }
  }

  void _showNotification(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  void _showError(String message) => _showNotification(message, isError: true);

  Future<void> _registerBusiness() async {
    if (!_privacyPolicyAccepted || !_termsOfUseAccepted) {
      _showError("Lütfen sözleşmeleri kabul edin.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String deviceId = await _getDeviceId();
      // Standardize PIN to 6 digits
      // Standardize PIN to 6 digits (Numeric only)
      String pin = _adminPasswordController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (pin.length < 6) {
        pin = pin.padRight(6, '0');
      } else {
        pin = pin.substring(0, 6);
      }

      await _dbService.saveUserData(
        companyName: _companyNameController.text,
        userName: _adminNameController.text,
        userContact: _adminPhoneController.text,
        userEmail: _adminEmailController.text,
        userPassword: _adminPasswordController.text,
        quickLoginPin: pin,
        userRole: 'Yönetici',
        termsAcceptedOn: DateTime.now().toIso8601String(),
        deviceId: deviceId,
        status: 'trial',
        licenseStatus: 'active',
        address: _addressController.text,
        companyPhone: _companyPhoneController.text,
        taxNumber: _taxNumberController.text,
      );

      final newUser = {
        'companyName': _companyNameController.text,
        'userName': _adminNameController.text,
        'userContact': _adminPhoneController.text,
        'userEmail': _adminEmailController.text,
        'userPassword': _adminPasswordController.text,
        'quickLoginPin': pin,
        'userRole': 'Yönetici',
        'termsAcceptedOn': DateTime.now().toIso8601String(),
        'deviceId': deviceId,
        'status': 'trial',
        'licenseStatus': 'active',
        'address': _addressController.text,
        'companyPhone': _companyPhoneController.text,
        'taxNumber': _taxNumberController.text,
        'social_instagram_enabled': 0,
        'social_whatsapp_enabled': 0,
        'social_website_enabled': 0,
        'social_twitter_enabled': 0,
        'social_facebook_enabled': 0,
        'social_maps_enabled': 0,
      };

      // Cihaz seviyesinde 7 günlük deneme kontrolü (Donanım kilidi)
      final bool localTrialUsed = await _dbService.hasDeviceUsedTrial();
      final bool remoteTrialUsed = await FirebaseService.instance.checkDeviceTrialUsed(deviceId);
      final bool isDeviceTrialConsumed = localTrialUsed || remoteTrialUsed;

      final DateTime trialExpiry = isDeviceTrialConsumed
          ? DateTime.now() // Deneme hakkı bitti, süre verilmez
          : DateTime.now().add(const Duration(days: 7));

      final String initialStatus = isDeviceTrialConsumed ? 'expired' : 'trial';
      final String initialLicenseStatus = isDeviceTrialConsumed ? 'expired' : 'active';
      final String initialPlan = isDeviceTrialConsumed ? 'Deneme Hakkı Bitti' : 'Ücretsiz Deneme';

      newUser['status'] = initialStatus;
      newUser['licenseStatus'] = initialLicenseStatus;
      newUser['plan'] = initialPlan;
      newUser['expiryDate'] = trialExpiry.toIso8601String();

      // 0. CREATE AUTH USER FIRST (Critical for Firestore Security Rules)
      final authUser = await FirebaseService.instance.createAuthUser(
        _adminEmailController.text, 
        _adminPasswordController.text
      );
      
      if (authUser == null) {
        debugPrint("Auth kullanıcısı oluşturulamadı (veya zaten var), Firestore kaydına devam ediliyor.");
      }

      // 1. Firebase Sync - Firestore
      final bool firestoreSuccess = await FirebaseService.instance.registerCompany(newUser);
      
      if (!firestoreSuccess) {
        throw Exception("Şirket verileri buluta senkronize edilemedi. Lütfen internet bağlantınızı kontrol edin.");
      }

      // 2. Local DB Sync & License Cache
      await _dbService.saveUserData(
        companyName: _companyNameController.text,
        userName: _adminNameController.text,
        userContact: _adminPhoneController.text,
        userEmail: _adminEmailController.text,
        userPassword: _adminPasswordController.text,
        quickLoginPin: pin,
        userRole: 'Yönetici',
        termsAcceptedOn: DateTime.now().toIso8601String(),
        deviceId: deviceId,
        status: initialStatus,
        licenseStatus: initialLicenseStatus,
        address: _addressController.text,
        companyPhone: _companyPhoneController.text,
        taxNumber: _taxNumberController.text,
      );

      // Yerel lisans cache'ini ve cihaz deneme kilidini mühürle
      await _dbService.markDeviceTrialUsed(trialExpiry);
      await _dbService.saveLicenseCache(trialExpiry, initialLicenseStatus, planName: initialPlan);

      if (mounted) {
        if (isDeviceTrialConsumed) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Bu cihazda 7 günlük ücretsiz deneme daha önce kullanılmıştır. Lütfen bir abonelik planı seçiniz."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Kayıt Başarılı! 7 Günlük Ücretsiz Deneme Süreniz Başladı."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ));
        }
        
        await Future.delayed(const Duration(milliseconds: 900));
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => SubscriptionPlansScreen(
              email: _adminEmailController.text,
              isFromRegistration: true,
              loggedInUser: newUser,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showError("Kayıt sırasında bir hata oluştu: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

}

class _StaggeredAnimatedItem extends StatefulWidget {
  final int delay;
  final Widget child;

  const _StaggeredAnimatedItem({required this.delay, required this.child});

  @override
  State<_StaggeredAnimatedItem> createState() => _StaggeredAnimatedItemState();
}

class _StaggeredAnimatedItemState extends State<_StaggeredAnimatedItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
