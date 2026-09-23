import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import 'main_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'new_business_registration_screen.dart';
import 'subscription_plans_screen.dart';

class LoginScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final bool adminExists;

  const LoginScreen({
    super.key,
    required this.allUsers,
    required this.adminExists,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('com.example.flutter_face_app/python');

  final _dbService = DatabaseService();

  bool _isLoginUIVisible = false;
  bool _isRegistered = false;
  bool _showLoginForm = false;

  // PIN Girişi animasyonu için state'ler
  bool _isVerifyingPin = false;
  bool _isLoginSuccess = false;

  bool _showPasswordResetEmailForm = false;
  bool _isSendingResetEmail = false;

  bool _adminExists = false;
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, dynamic>? _selectedUser;
  bool _isFastLoginEnabled = false;

  late AnimationController _formAnimationController;
  late Animation<double> _formAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _quickLoginPinController = TextEditingController();

  bool _obscurePassword = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _formAnimationController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _formAnimation = CurvedAnimation(
        parent: _formAnimationController, curve: Curves.easeInOut);

    _initializeDataFromWidget();
  }

  Future<void> _initializeDataFromWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final bool fastLogin = prefs.getBool('fast_login_enabled') ?? false;

    if (mounted) {
      setState(() {
        _isFastLoginEnabled = fastLogin;
        _allUsers = widget.allUsers;
        _isRegistered = widget.allUsers.isNotEmpty;
        _adminExists = widget.adminExists;
        _isLoginUIVisible = true;
      });

      _formAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _formAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _quickLoginPinController.dispose();
    super.dispose();
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
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

  Future<bool> _checkLicense(Map<String, dynamic> user, {bool forceRemote = false}) async {
    // Lisans kontrol istekleri iptal edildi
    return true;
  }

  Future<bool?> _showManualMigrationDialog(Map<String, dynamic> user) async {
    final passwordController = TextEditingController();
    final String savedPassword = user['userPassword']?.toString() ?? '';

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cihaz Değişikliği Onayı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu hesap başka bir cihaza kayıtlı. Lisansı bu cihaza taşımak istiyor musunuz?'),
            const SizedBox(height: 8),
            const Text('Not: Eski cihazdaki bağlantı kopacaktır.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yönetici Şifrenizi Girin', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == savedPassword) {
                Navigator.pop(context, true);
              } else {
                _showSnackBar('Hatalı şifre!', isSuccess: false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Doğrula ve Taşı'),
          ),
        ],
      ),
    );
  }


  void _showPromoCodeDialog(String email) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lisans / Promo Kod Gir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lisans sürenizi uzatmak için kodunuzu girin.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                hintText: 'Örn: ABC1-DEFG-2026',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ElevatedButton(
            onPressed: () async {
              final result = await FirebaseService.instance.redeemPromoCode(email, codeController.text.trim());
              if (result.startsWith("SUCCESS:")) {
                final days = result.split(":")[1];
                Navigator.pop(context);
                _showSnackBar('Tebrikler! Lisansınız $days gün uzatıldı.', isSuccess: true);
              } else {
                _showSnackBar(result, isSuccess: false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Kodu Kullan'),
          ),
        ],
      ),
    );
  }


  Future<void> _handleQuickLogin() async {
    final String? savedPin = _selectedUser!['quickLoginPin']?.toString();
    final int requiredLength = savedPin?.length ?? 4;

    if (_selectedUser == null || _quickLoginPinController.text.length < requiredLength)
      return;

    if (savedPin == null || savedPin.isEmpty) {
      if (mounted) {
        _quickLoginPinController.clear();
        _showSnackBar(
            'Bu kullanıcı için PIN girişi aktif değil. Lütfen şifre ile giriş yapın.',
            isSuccess: false);
      }
      return;
    }

    setState(() {
      _isVerifyingPin = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (_quickLoginPinController.text == savedPin) {
      if (mounted) {
        // Lisans Kontrolü
        final bool isLicenseValid = await _checkLicense(_selectedUser!);
        if (!isLicenseValid) return;

        setState(() {
          _isLoginSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 2000));

        if (_selectedUser != null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) =>
                  MainScreen(loggedInUser: _selectedUser!)));
        }
      }
    } else if (mounted) {
      _quickLoginPinController.clear();
      _showSnackBar('Hatalı PIN kodu!', isSuccess: false);
      setState(() {
        _isVerifyingPin = false;
      });
    }
  }

  Future<void> _handleFullLogin() async {
    if (_selectedUser == null) return;
    if (_formKey.currentState!.validate()) {
      final savedEmail = _selectedUser!['userEmail']?.toString();
      final savedPassword = _selectedUser!['userPassword']?.toString() ?? '';
      final enteredEmail = _emailController.text;
      final enteredPassword = _passwordController.text;

      if (enteredEmail == savedEmail) {
        bool isLoginSuccess = false;

        // 1. Firebase Auth ile Online Giriş Denemesi
        try {
          final fbUser = await FirebaseService.instance.signIn(enteredEmail, enteredPassword);
          if (fbUser != null) {
            isLoginSuccess = true;
            debugPrint("Firebase login başarılı.");
            
            // Şifre senkronizasyonu
            if (savedPassword != enteredPassword) {
               debugPrint("Local şifre güncelleniyor...");
               
               // PIN Üretimi: Sadece rakamları al, yoksa 000000 yap.
               String newPin = enteredPassword.replaceAll(RegExp(r'[^0-9]'), '');
               if (newPin.length < 6) {
                 newPin = newPin.padRight(6, '0');
               } else {
                 newPin = newPin.substring(0, 6);
               }
               
               if (_selectedUser != null) {
                 _selectedUser!['userPassword'] = enteredPassword;
                 _selectedUser!['quickLoginPin'] = newPin;

                 if (_selectedUser!['userRole'] == 'Yönetici') {
                   await _dbService.updatePassword(enteredPassword, newPin);
                 } else if (_selectedUser!['id'] is int) {
                   await _dbService.updateStaffById(
                     _selectedUser!['id'] as int,
                     {'userPassword': enteredPassword, 'quickLoginPin': newPin},
                   );
                 }
               }
            }
          }
        } catch (e) {
          debugPrint("Firebase login hatası: $e");
        }

        // 2. Local Doğrulama (Fallback)
        if (!isLoginSuccess) {
          if (enteredPassword == savedPassword) {
            isLoginSuccess = true;
            debugPrint("Local login başarılı.");
          } else {
            debugPrint("Local şifre uyuşmuyor. Girilen: $enteredPassword, Kayıtlı: $savedPassword");
          }
        }

        if (isLoginSuccess) {
           if (mounted) {
            // Lisans Kontrolü
            final bool isLicenseValid = await _checkLicense(_selectedUser!);
            if (!isLicenseValid) return;

            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) =>
                    MainScreen(loggedInUser: _selectedUser!)));
          }
        } else {
            _showError('Şifre hatalı!');
        }
      } else {
        _showError('E-posta adresi uyuşmuyor!');
      }
    }
  }

  Future<void> _handlePasswordlessLogin(Map<String, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _isVerifyingPin = true;
    });

    await Future.delayed(const Duration(milliseconds: 250));
    
    // Lisans Kontrolü (Atlanmamalı!)
    final bool isLicenseValid = await _checkLicense(user);
    if (!isLicenseValid) {
      if (mounted) {
        setState(() {
          _isVerifyingPin = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoginSuccess = true;
      });
    }

    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted && _selectedUser != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) =>
              MainScreen(loggedInUser: _selectedUser!)));
    }
  }

  Future<void> _handlePasswordResetEmailRequest() async {
    final enteredEmail = _emailController.text.trim();
    if (enteredEmail.isEmpty) {
      _showNotification('Lütfen e-posta adresinizi girin.', bgColor: Colors.orange.shade800);
      return;
    }
    if (!enteredEmail.contains('@') || !enteredEmail.contains('.')) {
      _showNotification('Lütfen geçerli bir e-posta adresi girin.', bgColor: Colors.orange.shade800);
      return;
    }

    setState(() => _isSendingResetEmail = true);

    try {
      // Eğer kullanıcının Firebase Auth hesabı henüz yoksa yerel listedeki şifre ile oluşturalım
      final matchingUser = _allUsers.firstWhere(
        (u) => (u['userEmail']?.toString().toLowerCase() ?? '') == enteredEmail.toLowerCase(),
        orElse: () => _selectedUser != null ? _selectedUser! : {},
      );
      final savedPassword = matchingUser['userPassword']?.toString();
      if (savedPassword != null && savedPassword.isNotEmpty) {
        await FirebaseService.instance.createAuthUser(enteredEmail, savedPassword);
      }

      // Firebase Authentication üzerinden resmi şifre sıfırlama bağlantısı gönder
      final result = await FirebaseService.instance.sendPasswordResetEmail(enteredEmail);

      if (mounted) {
        setState(() => _isSendingResetEmail = false);

        if (result == "SUCCESS") {
          setState(() {
            _showPasswordResetEmailForm = false;
          });

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.mark_email_read_rounded, color: Colors.teal, size: 28),
                  SizedBox(width: 10),
                  Text('Bağlantı Gönderildi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Şifre sıfırlama bağlantısı başarıyla gönderildi:\n$enteredEmail',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. E-posta kutunuzu (ve gerekiyorsa Spam klasörünü) kontrol edin.\n'
                    '2. Gelen bağlantıya tıklayarak yeni şifrenizi belirleyin.\n'
                    '3. Ardından Gastrofy ekranında yeni şifrenizle giriş yapın (Yeni şifreniz bu cihaza da otomatik eşitlenecektir).',
                    style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Anladım, Giriş Yap',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          _showError(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingResetEmail = false);
        _showError('Beklenmeyen bir hata oluştu: $e');
      }
    }
  }

  Future<void> _promptForAdminReset() async {
    // Check if this is a Terminal setup
    final Map<String, String> allData = await _dbService.readAllUserData();
    final bool isTerminal = allData['companyName'] == 'Bağlı Terminal';

    final adminUser = _allUsers.firstWhere(
      (user) => user['userRole'] == 'Yönetici',
      orElse: () => <String, dynamic>{},
    );

    if (adminUser.isEmpty && !isTerminal) {
      _showSnackBar('Hata: Yönetici hesabı bulunamadı. Sıfırlama yapılamıyor.',
          isSuccess: false);
      return;
    }

    final String? adminPassword = adminUser['userPassword']?.toString();

    if (!isTerminal && (adminPassword == null || adminPassword.isEmpty)) {
      _showSnackBar(
          'Hata: Yöneticinin bir şifresi ayarlı değil. Güvenlik nedeniyle sıfırlama engellendi.',
          isSuccess: false);
      return;
    }

    final confirmController = TextEditingController();
    bool obscureText = true;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(isTerminal ? 'Bağlantıyı Sıfırla' : 'Yönetici Doğrulaması',
                  style: const TextStyle(color: Colors.teal)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isTerminal 
                        ? 'Bu cihazın ana kasa ile olan bağlantısını kesmek ve ayarları sıfırlamak için lütfen "SIFIRLA" yazın.'
                        : 'Tüm hesapları sıfırlamak için lütfen yönetici şifresini girin.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmController,
                      obscureText: !isTerminal && obscureText,
                      decoration: InputDecoration(
                        labelText: isTerminal ? 'Onay Metni' : 'Yönetici Şifresi',
                        hintText: isTerminal ? 'SIFIRLA' : '',
                        prefixIcon:
                            Icon(isTerminal ? Icons.refresh : Icons.shield, color: Colors.teal),
                        suffixIcon: isTerminal ? null : IconButton(
                          icon: Icon(obscureText
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setDialogState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child:
                      const Text('İptal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isTerminal ? Colors.orange : Colors.teal),
                  onPressed: () {
                    if (isTerminal) {
                      if (confirmController.text.toUpperCase() == 'SIFIRLA') {
                        Navigator.of(context).pop(true);
                      } else {
                         _showSnackBar('Lütfen geçerli onay metnini girin (SIFIRLA)',
                          isSuccess: false);
                      }
                    } else {
                      if (confirmController.text == adminPassword) {
                        Navigator.of(context).pop(true);
                      } else {
                        Navigator.of(context).pop(false);
                        _showSnackBar('Hatalı yönetici şifresi!',
                            isSuccess: false);
                      }
                    }
                  },
                  child: Text(isTerminal ? 'Bağlantıyı Kes' : 'Onayla',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      _showSnackBar(isTerminal ? 'Bağlantı kesiliyor...' : 'Yönetici doğrulandı. Tüm veriler sıfırlanıyor...',
          isSuccess: true);

      await Future.delayed(const Duration(seconds: 1));
      await _dbService.clearAllData();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const NewBusinessRegistrationScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NewBusinessRegistrationScreen())
    ).then((_) {
      // Kayıttan sonra geri gelirse (veya kayıt başarılı olursa) datayı tazele
      _initializeDataFromWidget();
    });
  }

  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: const TextStyle(color: Colors.teal)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Text(content),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat', style: TextStyle(color: Colors.teal)),
            )
          ],
        );
      },
    );
  }

  void _showNotification(String message, {bool isError = true, Color? bgColor}) {
    if (!mounted) return;
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
        backgroundColor: bgColor ?? (isError ? Colors.red.shade800 : Colors.teal.shade700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  // Backward compatibility
  void _showSnackBar(String message, {bool isSuccess = false}) {
    _showNotification(message, isError: !isSuccess);
  }

  void _showError(String message) => _showNotification(message, isError: true);
  void _showSuccess(String message) => _showNotification(message, isError: false);


  void _showSocialLinkDialog(
      IconData icon, Color color, String title, String link) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          actionsPadding:
              const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          title: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 22),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      size: 200.0,
                      embeddedImage: Image.asset('assets/gastromind512.png').image,
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: const Size(40, 40),
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    link,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_browser,
                          color: Colors.white),
                      label: const Text('Bağlantıyı Uygulamada Aç',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _launchInAppBrowser(link);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Kopyala'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                _copyToClipboard(link);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Bağlantı panoya kopyalandı!', isSuccess: true);
  }

  Future<void> _launchInAppBrowser(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      _showSnackBar('Bağlantı açılamadı: $url', isSuccess: false);
      return;
    }
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
    } catch (e) {
      _showSnackBar('Bağlantı açılırken bir hata oluştu: $e', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Content (Logo + Form)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 800),
            opacity: _isLoginUIVisible ? 1.0 : 0.0,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // FORM ALANI
                    _buildAnimatedForm(),
                  ],
                ),
              ),
            ),
          ),
          // Registration button
          if (!_isRegistered &&
              !_showPasswordResetEmailForm &&
              _isLoginUIVisible)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              bottom: 40,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: 1.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.5),
                  ),
                  onPressed: _handleRegistration,
                  child: const Text('Kayıt Ol',
                      style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedForm() {
    if (_showPasswordResetEmailForm) return _buildPasswordResetEmailForm();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _isRegistered
          ? (_selectedUser == null
              ? _buildUserSelectionGrid()
              : _buildUserLoginForm())
          : const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
    );
  }

  Widget _buildUserSelectionGrid() {
    return Container(
      key: const ValueKey('user-selection'),
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Giriş Yap',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal)),
          const SizedBox(height: 8),
          const Text('Lütfen profilinizi seçin',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          if (_isFastLoginEnabled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: Colors.teal.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Hızlı Giriş Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: _allUsers.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> user = entry.value;

              final userName = user['userName']?.toString() ?? '?';
              final userFaceImage = user['userFaceImage'] as String?;

              final heroTag =
                  user['userEmail']?.toString() ?? 'user-profile-$index';

              final bool isSelectedForTransition = _selectedUser != null &&
                  (_selectedUser!['userEmail'] == user['userEmail'] ||
                      _allUsers.indexOf(_selectedUser!) == index);

              return GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final bool isFastLogin = prefs.getBool('fast_login_enabled') ?? false;
                  final String? savedPassword =
                      user['userPassword']?.toString();
                  final bool hasPassword =
                      savedPassword != null && savedPassword.isNotEmpty;

                  if (!hasPassword || isFastLogin) {
                    _handlePasswordlessLogin(user);
                  } else {
                    setState(() {
                      _selectedUser = user;
                      _emailController.text =
                          user['userEmail']?.toString() ?? '';
                      _passwordController.clear();
                      _quickLoginPinController.clear();
                    });
                  }
                },
                child: Opacity(
                  opacity: isSelectedForTransition ? 0.0 : 1.0,
                  child: Hero(
                    tag: heroTag,
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.teal.shade100,
                                backgroundImage: userFaceImage != null
                                    ? MemoryImage(base64Decode(userFaceImage))
                                    : null,
                                child: userFaceImage == null
                                    ? Text(
                                        userName.isNotEmpty
                                            ? userName[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            fontSize: 32,
                                            color: Colors.teal.shade800,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              if (_isFastLoginEnabled)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 4,
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.bolt_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(userName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _buildSocialIcons(user),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Terminal Olarak Bağlan butonu gizlendi
          const SizedBox(height: 12),
          TextButton(
            onPressed: _promptForAdminReset,
            child: const Text('Bu cihazdaki hesapları sıfırla', 
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalConnectButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Terminal Olarak Bağlan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.teal,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.teal, width: 2),
          ),
          elevation: 0,
        ),
        onPressed: _showQRScanner,
      ),
    );
  }

  void _showQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('Terminal Bağlantı Kodu Tara', 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                   IconButton(
                     icon: const Icon(Icons.close, color: Colors.white),
                     onPressed: () => Navigator.pop(context),
                   ),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final String? code = barcode.rawValue;
                    if (code != null && code.startsWith('SYNCCLIENT:')) {
                      final ip = code.split(':').last;
                      Navigator.pop(context);
                      _handleTerminalConnect(ip);
                      break;
                    }
                  }
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Kasa cihazındaki QR kodu taratın', 
                style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTerminalConnect(String ip) async {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    
    _showSnackBar('Sunucuya bağlanılıyor: $ip', isSuccess: true);
    
    await tableProvider.setSyncMode(
      enabled: true, 
      ip: ip, 
      role: SyncRole.client
    );

    // Otomatik olarak "Garson" olarak giriş yapmış gibi davranabiliriz 
    // veya sadece sync modunu aktif edip kullanıcı seçmesini bekleyebiliriz.
    // Burada sadece sync modunu aktif ediyoruz.
    setState(() {
      _initializeDataFromWidget();
    });
  }

  Widget _buildSocialIcons(Map<String, dynamic> user) {
    final List<Widget> icons = [];

    // Instagram
    final bool instagramEnabled = _parseBool(user['social_instagram_enabled']);
    final String? instagramLink = user['social_instagram_link']?.toString();
    if (instagramEnabled && instagramLink != null && instagramLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.instagram,
        Colors.orange.shade800,
        'Instagram',
        instagramLink,
      ));
    }

    // WhatsApp
    final bool whatsappEnabled = _parseBool(user['social_whatsapp_enabled']);
    final String? whatsappLink = user['social_whatsapp_link']?.toString();
    if (whatsappEnabled && whatsappLink != null && whatsappLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.whatsapp,
        Colors.green,
        'WhatsApp',
        whatsappLink,
      ));
    }

    // Web Sitesi
    final bool websiteEnabled = _parseBool(user['social_website_enabled']);
    final String? websiteLink = user['social_website_link']?.toString();
    if (websiteEnabled && websiteLink != null && websiteLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.web,
        Colors.blue,
        'Web Sitesi',
        websiteLink,
      ));
    }

    // X (Twitter)
    final bool twitterEnabled = _parseBool(user['social_twitter_enabled']);
    final String? twitterLink = user['social_twitter_link']?.toString();
    if (twitterEnabled && twitterLink != null && twitterLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.twitter,
        Colors.black,
        'X (Twitter)',
        twitterLink,
      ));
    }

    // Facebook
    final bool facebookEnabled = _parseBool(user['social_facebook_enabled']);
    final String? facebookLink = user['social_facebook_link']?.toString();
    if (facebookEnabled && facebookLink != null && facebookLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.facebook,
        Colors.indigo,
        'Facebook',
        facebookLink,
      ));
    }

    // Google Maps
    final bool mapsEnabled = _parseBool(user['social_maps_enabled']);
    final String? mapsLink = user['social_maps_link']?.toString();
    if (mapsEnabled && mapsLink != null && mapsLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.googleMaps,
        Colors.red,
        'Google Maps',
        mapsLink,
      ));
    }

    if (icons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      children: icons,
    );
  }

  Widget _buildSocialIcon(
      IconData icon, Color color, String title, String link) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: 22,
        padding: EdgeInsets.zero,
        onPressed: () {
          _showSocialLinkDialog(icon, color, title, link);
        },
        tooltip: title,
      ),
    );
  }

  Widget _buildUserLoginForm() {
    final userName = _selectedUser?['userName']?.toString() ?? '?';
    final userFaceImage = _selectedUser?['userFaceImage'] as String?;
    final userEmail = _selectedUser?['userEmail']?.toString();

    final String? savedPin = _selectedUser?['quickLoginPin']?.toString();
    final bool hasPin = savedPin != null && savedPin.isNotEmpty;

    return Container(
      key: ValueKey(userEmail ?? userName),
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5)
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _isVerifyingPin
            ? _buildLoginTransitionView(userName)
            : (hasPin && !_showLoginForm)
                ? _buildPinLoginView(userName, userFaceImage)
                : _buildFullLoginFormForSelectedUser(
                    userName, userFaceImage, hasPin),
      ),
    );
  }

  Widget _buildPinLoginView(String userName, String? userFaceImage) {
    final heroTag = _selectedUser?['userEmail'] as String? ??
        'user-profile-${_allUsers.indexOf(_selectedUser!)}';

    return Column(
      key: const ValueKey('pin-login'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.teal.shade100,
              backgroundImage: userFaceImage != null
                  ? MemoryImage(base64Decode(userFaceImage))
                  : null,
              child: userFaceImage == null
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 32,
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Hoş Geldin, $userName',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 4),
        Text(_selectedUser?['userEmail'] ?? '',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        const Text('Giriş Yazısı / PIN Kodu',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 200),
          child: TextFormField(
            controller: _quickLoginPinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 16,
                color: Colors.teal),
            maxLength: 6,
            decoration: InputDecoration(
              counterText: "",
              hintText: "••••••",
              hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 16),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.teal.shade200, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.teal, width: 3),
              ),
            ),
            onChanged: (value) {
              final String? savedPin = _selectedUser?['quickLoginPin']?.toString();
              if (savedPin != null && value.length == savedPin.length) {
                _handleQuickLogin();
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
                onPressed: () => setState(() => _showLoginForm = true),
                child: const Text('Şifre ile giriş yap')),
            TextButton(
                onPressed: () => setState(() {
                      _selectedUser = null;
                      _isVerifyingPin = false;
                      _isLoginSuccess = false;
                      _quickLoginPinController.clear();
                    }),
                child: const Text('Kullanıcı Değiştir')),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginTransitionView(String userName) {
    return Container(
      key: const ValueKey('verifying-login'),
      height: 350,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isLoginSuccess
                ? const Icon(
                    key: ValueKey('success-icon'),
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  )
                : const CircularProgressIndicator(
                    key: ValueKey('progress-indicator'),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _isLoginSuccess
                ? Text(
                    key: ValueKey('welcome-text-$userName'),
                    'Hoş Geldin, $userName',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal))
                : Text(
                    key: const ValueKey('verifying-text'),
                    'Doğrulanıyor...',
                    style:
                        TextStyle(fontSize: 18, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeviceUnbind() async {
    if (_selectedUser == null) return;
    
    final adminUser = _allUsers.firstWhere(
      (user) => user['userRole'] == 'Yönetici',
      orElse: () => <String, dynamic>{},
    );

    if (adminUser.isEmpty) {
      _showSnackBar('Hata: Yönetici hesabı bulunamadı.', isSuccess: false);
      return;
    }

    final String? adminPassword = adminUser['userPassword']?.toString();
    final passwordController = TextEditingController();
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lisansı Bu Cihazdan Kaldır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu işlem için yönetici şifresi gereklidir. Cihaz bağı kaldırıldıktan sonra lisans boşa çıkacaktır.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yönetici Şifresi', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == adminPassword) {
                Navigator.pop(context, true);
              } else {
                _showSnackBar('Hatalı şifre!', isSuccess: false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Lisansı Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isVerifyingPin = true);
      final email = _selectedUser!['userEmail'];
      final success = await FirebaseService.instance.updateDeviceId(email, null);
      
      setState(() => _isVerifyingPin = false);
      if (success) {
        _showSnackBar('Lisans bağı başarıyla kaldırıldı. Yeni cihazınızdan giriş yapabilirsiniz.', isSuccess: true);
      } else {
        _showSnackBar('İşlem başarısız! İnternet bağlantınızı kontrol edin.', isSuccess: false);
      }
    }
  }

  Widget _buildFullLoginFormForSelectedUser(
      String userName, String? userFaceImage, bool hasPin) {
    final heroTag = _selectedUser?['userEmail'] as String? ??
        'user-profile-${_allUsers.indexOf(_selectedUser!)}';

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Hero(
            tag: heroTag,
            child: Material(
              color: Colors.transparent,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.teal.shade100,
                backgroundImage: userFaceImage != null
                    ? MemoryImage(base64Decode(userFaceImage))
                    : null,
                child: userFaceImage == null
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontSize: 32,
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Hoş Geldin, $userName',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            readOnly: true,
            decoration: InputDecoration(
                labelText: 'E-posta',
                prefixIcon: const Icon(Icons.email, color: Colors.teal),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Şifre (Rakam)',
              prefixIcon: const Icon(Icons.lock, color: Colors.teal),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.teal),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
            validator: (v) {
              final String savedPassword =
                  _selectedUser?['userPassword']?.toString() ?? '';
              if (savedPassword.isNotEmpty && (v ?? '').isEmpty) {
                return 'Lütfen şifrenizi girin';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              onPressed: _handleFullLogin,
              child: const Text('Giriş Yap',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
                onPressed: () {
                  if (_selectedUser != null && (_selectedUser!['userEmail'] ?? '').isNotEmpty) {
                    _emailController.text = _selectedUser!['userEmail'];
                  }
                  setState(() {
                    _showPasswordResetEmailForm = true;
                  });
                },
                child: const Text('Şifremi unuttum',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal))),
          ),
          if (hasPin)
            Center(
              child: TextButton(
                  onPressed: () => setState(() => _showLoginForm = false),
                  child: const Text('Hızlı girişe dön',
                      style: TextStyle(color: Colors.black54))),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordResetEmailForm() {
    return FadeTransition(
      opacity: _formAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, size: 48, color: Colors.teal),
              ),
              const SizedBox(height: 16),
              const Text(
                'Şifre Sıfırlama',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gastrofy hesabınıza bağlı e-posta adresinizi girin. E-posta kutunuza güvenli bir şifre sıfırlama bağlantısı göndereceğiz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, color: Colors.teal, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gelen bağlantıya tıklayarak yeni şifrenizi belirledikten sonra uygulamaya yeni şifrenizle giriş yapabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Colors.teal, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Kayıtlı E-posta Adresi',
                  hintText: 'ornek@restoran.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) return 'Lütfen e-posta adresinizi girin';
                  if (!trimmed.contains('@') || !trimmed.contains('.')) {
                    return 'Geçerli bir e-posta adresi girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isSendingResetEmail ? null : _handlePasswordResetEmailRequest,
                  child: _isSendingResetEmail
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Sıfırlama Bağlantısı Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSendingResetEmail
                    ? null
                    : () => setState(() {
                          _showPasswordResetEmailForm = false;
                        }),
                child: const Text('Giriş ekranına dön', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }


}


const String _privacyPolicyText = """
**Gizlilik Politikası**

Son Güncelleme: 14 Ekim 2025  
© 2025 Developer by MET. Tüm hakları saklıdır.

Developer by MET ("biz", "bize" veya "bizim") olarak gizliliğinizi korumayı taahhüt ediyoruz. Bu Gizlilik Politikası, uygulamamızı ("Uygulama") kullandığınızda bilgilerinizi nasıl topladığımızı, kullandığımızı, ifşa ettiğimizi ve koruduğumuzu açıklamaktadır.

**1. Topladığımız Bilgiler** Kayıt veya kullanım sırasında sağlayabileceğiniz bilgiler:
- Firma Adı  
- Yetkili Adı Soyadı  
- İletişim Bilgileri (Telefon/E-posta)  
- Giriş için E-posta Adresi  
- Yüz Tanıma için Biyometrik Veri (şifrelenmiş ve **yalnızca cihazınızda** saklanır)  
- Kullanıcı Rolü (Yönetici, Müdür, vb.)

**2. Bilgilerinizin Kullanımı** Topladığımız bilgileri şu amaçlarla kullanırız:
- Hesabınızı oluşturmak ve yönetmek  
- Giriş işlemlerini (PIN, şifre veya yüz tanıma) gerçekleştirmek  
- Müşteri desteği sağlamak  
- Uygulama deneyimini iyileştirmek ve kişiselleştirmek  

**3. Bilgilerinizin Paylaşımı** Kişisel bilgilerinizi **izin vermediğiniz sürece** üçüncü taraflarla paylaşmayız, satmayız veya aktarmayız.  
Yüz verileriniz dahil tüm kişisel veriler **sadece cihazınızda güvenli şekilde saklanır**, sunucularımıza veya dış sistemlere gönderilmez.

**4. Veri Güvenliği** Verileriniz güvenli depolama alanlarında şifrelenmiş biçimde tutulur. Uygulama, Apple/Google güvenlik standartlarına uygun şekilde çalışır.  
Güvenlik ihlallerine karşı düzenli kontroller yapılmaktadır.

**5. Politikamızdaki Değişiklikler** Gizlilik politikamız zaman zaman güncellenebilir.  
Politika güncellendiğinde, uygulamayı kullanmaya devam edebilmeniz için **yenilenen metni yeniden okumanız ve onaylamanız gerekecektir.**

**6. Telif Hakkı ve Koruma** Bu uygulama ve içeriği, tasarımı, kod yapısı ve metinleri Metsoft Yazılım’a aittir.  
İzinsiz kopyalama, çoğaltma, dağıtım veya tersine mühendislik yasaktır.  
İhlal durumunda yasal işlem başlatılabilir.

**7. Bize Ulaşın** Bu Gizlilik Politikası ile ilgili herhangi bir sorunuz varsa, bizimle iletişime geçin:  
📧 destek@metsoft.com
""";

const String _termsOfUseText = """
**Kullanım Şartları**

Son Güncelleme: 14 Ekim 2025  
© 2025 Developer by MET. Tüm hakları saklıdır.

Lütfen bu uygulamayı kullanmadan önce bu Kullanım Şartları’nı ("Şartlar") dikkatlice okuyun.

**1. Şartların Kabulü** Uygulamamıza erişerek veya onu kullanarak, bu Şartlara bağlı kalmayı kabul edersiniz.  
Bu Şartları kabul etmiyorsanız, Uygulamayı kullanamazsınız.

**2. Hesap Sorumluluğu** Hesabınızın ve şifrenizin gizliliğini korumak sizin sorumluluğunuzdadır.  
Herhangi bir yetkisiz kullanımı derhal bize bildirmeniz gerekir.

**3. Kullanım Kısıtlamaları** Uygulamayı yasa dışı veya yetkisiz bir amaçla kullanamazsınız.  
Uygulamanın güvenliğini ihlal etmeye veya kaynak kodunu kopyalamaya çalışmak yasaktır.

**4. Fikri Mülkiyet Hakları** Uygulama, içeriği, kullanıcı arayüzü, yazılım yapısı ve tüm bileşenleri MET’e aittir.  
İzinsiz kopyalama, paylaşma veya yeniden dağıtım yasaktır.

**5. Sorumluluğun Sınırlandırılması** MET, uygulamanın kullanımından doğan dolaylı veya arızi zararlardan sorumlu değildir.  
Uygulama "olduğu gibi" sağlanır, kesintisiz veya hatasız çalışacağı garanti edilmez.

**6. Fesih** Bu Şartların ihlali durumunda hesabınız önceden bildirim yapılmaksızın askıya alınabilir veya feshedilebilir.

**7. Gizlilik ve Veri Koruma** Tüm kullanıcı verileri **yalnızca cihazınızda güvenli şekilde işlenir ve saklanır.** Veriler, üçüncü taraf sunuculara veya bulut sistemlerine gönderilmez.

**8. Bize Ulaşın** Bu Şartlar hakkında herhangi bir sorunuz olursa, bizimle iletişime geçin:  
📧 destek@metsoft.com
""";
