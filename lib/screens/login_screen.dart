import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_screen.dart';
import '../services/database_service.dart';

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
  bool _isProcessingPython = false;

  // PIN Girişi animasyonu için state'ler
  bool _isVerifyingPin = false;
  bool _isLoginSuccess = false;

  bool _showPasswordResetEmailForm = false;
  bool _showVerificationCodeForm = false;
  bool _showNewPasswordForm = false;
  String _emailForPasswordReset = '';

  bool _privacyPolicyAccepted = false;
  bool _termsOfUseAccepted = false;
  bool _acceptNoPasswordRisk = false;

  bool _adminExists = false;
  String? _selectedRole;
  final List<String> _roles = ['Müdür', 'Şube Müdürü', 'Garson', 'Kasiyer'];

  List<Map<String, dynamic>> _allUsers = [];
  Map<String, dynamic>? _selectedUser;

  late AnimationController _formAnimationController;
  late Animation<double> _formAnimation;

  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _quickLoginPinController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _obscurePassword = true;
  String? _registeredFaceImageBase64;
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
    setState(() {
      _allUsers = widget.allUsers;
      _isRegistered = widget.allUsers.isNotEmpty;
      _adminExists = widget.adminExists;
      _isLoginUIVisible = true;
    });

    _formAnimationController.forward();
  }

  @override
  void dispose() {
    _formAnimationController.dispose();
    _companyNameController.dispose();
    _contactController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _quickLoginPinController.dispose();
    _verificationCodeController.dispose();
    _newPasswordController.dispose();
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

  Future<void> _saveFaceToPython() async {
    setState(() => _isProcessingPython = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Fotoğraf seçiliyor...')));

    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 50);
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('İşlem iptal edildi.'),
              backgroundColor: Colors.orange));
        }
        setState(() => _isProcessingPython = false);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Yüz Python\'da işleniyor, lütfen bekleyin...'),
            backgroundColor: Colors.blue));
      }
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final bool success =
          await platform.invokeMethod('saveFace', {'image': base64Image});

      if (mounted) {
        if (success) {
          setState(() {
            _registeredFaceImageBase64 = base64Image;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Referans yüz başarıyla kaydedildi!'),
              backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Bu fotoğrafta yüz bulunamadı. Lütfen başka bir fotoğraf deneyin.'),
              backgroundColor: Colors.red));
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Python Hatası: ${e.message}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPython = false);
    }
  }

  Future<void> _compareFaceWithPython() async {
    if (_selectedUser == null || _selectedUser!['userFaceImage'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu kullanıcı için kayıtlı bir yüz bulunmuyor.'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isProcessingPython = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama için fotoğraf seçiliyor...')));

    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 50);
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('İşlem iptal edildi.'),
              backgroundColor: Colors.orange));
        }
        setState(() => _isProcessingPython = false);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Yüzler karşılaştırılıyor, lütfen bekleyin...'),
            backgroundColor: Colors.blue));
      }
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final Map? result = await platform
          .invokeMethod<Map>('compareFace', {'image': base64Image});

      if (mounted) {
        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Bilinmeyen bir hata oluştu."),
              backgroundColor: Colors.red));
        } else if (result.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Hata: ${result['error']}"),
              backgroundColor: Colors.red));
        } else {
          final bool isMatch = result['match'] as bool;
          final double distance = result['distance'] as double;

          if (isMatch) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Yüzler Eşleşti! Giriş yapılıyor... (Mesafe: ${distance.toStringAsFixed(2)})'),
                backgroundColor: Colors.green));
            await Future.delayed(const Duration(seconds: 1));
            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) =>
                    MainScreen(loggedInUser: _selectedUser!)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Yüzler Farklı! (Mesafe: ${distance.toStringAsFixed(2)})'),
                backgroundColor: Colors.red));
          }
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Python Hatası: ${e.message}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPython = false);
    }
  }

  Future<void> _handleRegistration() async {
    if (!_privacyPolicyAccepted || !_termsOfUseAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Lütfen devam etmek için Gizlilik Politikası ve Kullanım Şartları\'nı kabul edin.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      String userRole;
      if (_adminExists) {
        if (_selectedRole == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Lütfen bir rol seçin.'),
                backgroundColor: Colors.red),
          );
          return;
        }
        userRole = _selectedRole!;
      } else {
        userRole = 'Yönetici';
      }

      final String password = _passwordController.text;

      if (password.isEmpty && !_acceptNoPasswordRisk) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Lütfen bir şifre belirleyin veya şifresiz kayıt riskini kabul edin.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      if (_registeredFaceImageBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Uyarı: Yüz eklemeden kayıt oluyorsunuz.'),
              backgroundColor: Colors.orange),
        );
      }

      final String pin = password.length >= 4 ? password.substring(0, 4) : '';

      await _dbService.saveUserData(
        companyName: _companyNameController.text,
        userName: _nameController.text,
        userContact: _contactController.text,
        userEmail: _emailController.text,
        userPassword: password,
        quickLoginPin: pin,
        userFaceImage: _registeredFaceImageBase64,
        termsAcceptedOn: DateTime.now().toIso8601String(),
        userRole: userRole,
      );

      final newUser = {
        'companyName': _companyNameController.text,
        'userName': _nameController.text,
        'userContact': _contactController.text,
        'userEmail': _emailController.text,
        'userPassword': password,
        'quickLoginPin': pin,
        'userFaceImage': _registeredFaceImageBase64,
        'termsAcceptedOn': DateTime.now().toIso8601String(),
        'userRole': userRole,
        'social_instagram_enabled': 0,
        'social_instagram_link': '',
        'social_whatsapp_enabled': 0,
        'social_whatsapp_link': '',
        'social_website_enabled': 0,
        'social_website_link': '',
        'social_twitter_enabled': 0,
        'social_twitter_link': '',
        'social_facebook_enabled': 0,
        'social_facebook_link': '',
        'social_maps_enabled': 0,
        'social_maps_link': '',
      };

      if (mounted) {
        if (userRole != 'Yönetici') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Yönetici onayı olmadan kayıt oldunuz.'),
                backgroundColor: Colors.blueAccent),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Yönetici olarak kayıt başarılı! Ana ekrana yönlendiriliyorsunuz.'),
                backgroundColor: Colors.green),
          );
        }

        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (context) => MainScreen(loggedInUser: newUser)));
      }
    }
  }

  Future<void> _handleQuickLogin() async {
    if (_selectedUser == null || _quickLoginPinController.text.length < 4)
      return;
    final String? savedPin = _selectedUser!['quickLoginPin']?.toString();

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
        setState(() {
          _isLoginSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 2000));

        if (_selectedUser != null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => MainScreen(loggedInUser: _selectedUser!)));
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

      if (_emailController.text == savedEmail &&
          _passwordController.text == savedPassword) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => MainScreen(loggedInUser: _selectedUser!)));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('E-posta veya şifre hatalı!'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handlePasswordlessLogin(Map<String, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _isVerifyingPin = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoginSuccess = true;
      });
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted && _selectedUser != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => MainScreen(loggedInUser: _selectedUser!)));
    }
  }

  Future<void> _handlePasswordResetEmailRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lütfen önce bir kullanıcı seçin.'),
            backgroundColor: Colors.orange));
        return;
      }
      final savedEmail = _selectedUser!['userEmail']?.toString();

      if (_emailController.text == savedEmail) {
        final String code = (Random().nextInt(900000) + 100000).toString();
        await _dbService.setVerificationCode(code);

        if (mounted) {
          setState(() {
            _emailForPasswordReset = _emailController.text;
            _showPasswordResetEmailForm = false;
            _showVerificationCodeForm = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Simülasyon: ${_emailController.text} adresine gönderilen kod: $code'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 6)));
          _emailController.clear();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Girilen e-posta adresi seçili kullanıcıya ait değil!'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleVerifyCode() async {
    if (_formKey.currentState!.validate()) {
      final savedCode = await _dbService.getVerificationCode();
      if (_verificationCodeController.text == savedCode) {
        setState(() {
          _showVerificationCodeForm = false;
          _showNewPasswordForm = true;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Doğrulama kodu hatalı!'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleUpdatePassword() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hata: Güncellenecek kullanıcı seçili değil.'),
            backgroundColor: Colors.red));
        return;
      }

      final newPassword = _newPasswordController.text;
      final newPin = newPassword.length >= 4 ? newPassword.substring(0, 4) : '';

      final updatedUser = Map<String, dynamic>.from(_selectedUser!);
      updatedUser['userPassword'] = newPassword;
      updatedUser['quickLoginPin'] = newPin;

      await _dbService.updateUserData(updatedUser,
          companyName: '', userName: '', userContact: '', userEmail: '');

      final index = _allUsers
          .indexWhere((u) => u['userEmail'] == updatedUser['userEmail']);
      if (index != -1) {
        _allUsers[index] = updatedUser;
      }

      setState(() {
        _showNewPasswordForm = false;
        _selectedUser = null;
        _showLoginForm = false;
        _passwordController.clear();
        _newPasswordController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Şifreniz başarıyla güncellendi. Lütfen tekrar giriş yapın.'),
            backgroundColor: Colors.green));
      }
    }
  }

  Future<void> _promptForAdminReset() async {
    final adminUser = _allUsers.firstWhere(
      (user) => user['userRole'] == 'Yönetici',
      orElse: () => <String, dynamic>{},
    );

    if (adminUser.isEmpty) {
      _showSnackBar('Hata: Yönetici hesabı bulunamadı. Sıfırlama yapılamıyor.',
          isSuccess: false);
      return;
    }

    final String? adminPassword = adminUser['userPassword']?.toString();

    if (adminPassword == null || adminPassword.isEmpty) {
      _showSnackBar(
          'Hata: Yöneticinin bir şifresi ayarlı değil. Güvenlik nedeniyle sıfırlama engellendi.',
          isSuccess: false);
      return;
    }

    final passwordController = TextEditingController();
    bool obscureText = true;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Yönetici Doğrulaması',
                  style: TextStyle(color: Colors.teal)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Tüm hesapları sıfırlamak için lütfen yönetici şifresini girin.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        labelText: 'Yönetici Şifresi',
                        prefixIcon:
                            const Icon(Icons.shield, color: Colors.teal),
                        suffixIcon: IconButton(
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    if (passwordController.text == adminPassword) {
                      Navigator.of(context).pop(true);
                    } else {
                      Navigator.of(context).pop(false);
                      _showSnackBar('Hatalı yönetici şifresi!',
                          isSuccess: false);
                    }
                  },
                  child: const Text('Onayla',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      _showSnackBar('Yönetici doğrulandı. Tüm veriler sıfırlanıyor...',
          isSuccess: true);
      await Future.delayed(const Duration(seconds: 1));
      await _resetToRegistration();
    }
  }

  Future<void> _resetToRegistration() async {
    await _dbService.clearAllData();
    setState(() {
      _isRegistered = false;
      _showLoginForm = false;
      _showPasswordResetEmailForm = false;
      _showVerificationCodeForm = false;
      _showNewPasswordForm = false;
      _allUsers = [];
      _selectedUser = null;
      _companyNameController.clear();
      _nameController.clear();
      _contactController.clear();
      _emailController.clear();
      _passwordController.clear();
      _quickLoginPinController.clear();
      _registeredFaceImageBase64 = null;
      _privacyPolicyAccepted = false;
      _termsOfUseAccepted = false;
      _acceptNoPasswordRisk = false;
      _adminExists = false;
      _selectedRole = null;
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

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor:
            isSuccess ? Colors.teal.shade600 : Colors.redAccent.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  void _onKeyPressed(String value) {
    final controller = _quickLoginPinController;
    if (value == 'del') {
      if (controller.text.isNotEmpty) {
        controller.text =
            controller.text.substring(0, controller.text.length - 1);
      }
    } else {
      if (controller.text.length < 4) {
        controller.text += value;
      }
    }
    if (controller.text.length == 4) {
      _handleQuickLogin();
    }
    setState(() {});
  }

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
                      embeddedImage: Image.asset('assets/logo2.png').image,
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
                    // LOGO ALANI
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: _isVerifyingPin ? 0.0 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        height: 180, // Yükseklik ayarı
                        width: 300, // Elips genişliği
                        child: CustomPaint(
                          painter: _EllipseBackgroundPainter(),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                  25.0), // Elips içi padding
                              child: Image.asset(
                                'assets/logo2.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.table_bar,
                                        size: 80, color: Colors.teal),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // FORM ALANI
                    _buildAnimatedForm(),
                  ],
                ),
              ),
            ),
          ),
          // Developer Info
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isVerifyingPin ? 0.0 : 1.0,
                child: _buildDeveloperInfo(),
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
    if (_showNewPasswordForm) return _buildNewPasswordForm();
    if (_showVerificationCodeForm) return _buildVerificationCodeForm();
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
          : _buildRegistrationForm(),
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
                onTap: () {
                  final String? savedPassword =
                      user['userPassword']?.toString();
                  final bool hasPassword =
                      savedPassword != null && savedPassword.isNotEmpty;

                  if (!hasPassword) {
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
          const SizedBox(height: 24),
          TextButton(
            onPressed: _promptForAdminReset,
            child: const Text('Bu cihazdaki hesapları sıfırla'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcons(Map<String, dynamic> user) {
    final List<Widget> icons = [];

    // Instagram
    final bool instagramEnabled = _parseBool(user['social_instagram_enabled']);
    final String? instagramLink = user['social_instagram_link']?.toString();
    if (instagramEnabled && instagramLink != null && instagramLink.isNotEmpty) {
      icons.add(_buildSocialIcon(
        MdiIcons.instagram,
        Colors.pink,
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
        const SizedBox(height: 16),
        _buildPinDisplay(),
        const SizedBox(height: 16),
        _buildNumericKeypad(),
        const SizedBox(height: 8),
        if (userFaceImage != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isProcessingPython
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.face_retouching_natural),
              label: Text(_isProcessingPython
                  ? 'Karşılaştırılıyor...'
                  : 'Yüz Tanıma ile Giriş'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              onPressed: _isProcessingPython ? null : _compareFaceWithPython,
            ),
          ),
        ],
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
                    }),
                child: const Text('Kullanıcı Değiştir')),
          ],
        ),
      ],
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _quickLoginPinController.text.length
                ? Colors.teal
                : Colors.grey.shade200,
            border: Border.all(color: Colors.grey.shade300),
          ),
        );
      }),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 68, height: 68),
            _buildKeypadButton('0'),
            _buildKeypadButton('del', isIcon: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String value, {bool isIcon = false}) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: Colors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(34),
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: () => _onKeyPressed(value),
          child: Center(
            child: isIcon
                ? const Icon(Icons.backspace_outlined, color: Colors.teal)
                : Text(
                    value,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
          ),
        ),
      ),
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
            decoration: InputDecoration(
              labelText: 'Şifre',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasPin)
                TextButton(
                    onPressed: () => setState(() => _showLoginForm = false),
                    child: const Text('Hızlı girişe dön')),
              TextButton(
                  onPressed: () => setState(() {
                        _showPasswordResetEmailForm = true;
                      }),
                  child: const Text('Şifremi unuttum')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return FadeTransition(
      opacity: _formAnimation,
      child: Container(
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_adminExists ? 'Yeni Kullanıcı Kaydı' : 'Yönetici Kaydı',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal)),
              const SizedBox(height: 8),
              const Text('Devam etmek için bilgileri doldurun',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isProcessingPython ? null : _saveFaceToPython,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.teal.shade50,
                  backgroundImage: _registeredFaceImageBase64 != null
                      ? MemoryImage(base64Decode(_registeredFaceImageBase64!))
                      : null,
                  child: _isProcessingPython
                      ? const CircularProgressIndicator()
                      : (_registeredFaceImageBase64 == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    color: Colors.teal.shade200, size: 24),
                                const SizedBox(height: 4),
                                Text('Yüz Ekle',
                                    style: TextStyle(
                                        color: Colors.teal.shade300,
                                        fontSize: 10))
                              ],
                            )
                          : null),
                ),
              ),
              const SizedBox(height: 16),
              if (_adminExists) ...[
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                      labelText: 'Rol Seçin',
                      prefixIcon: const Icon(Icons.person_pin_circle,
                          color: Colors.teal),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15))),
                  items: _roles.map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedRole = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Lütfen bir rol seçin' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _companyNameController,
                decoration: InputDecoration(
                    labelText: 'Firma Adı',
                    prefixIcon: const Icon(Icons.business, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15))),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Lütfen firma adını girin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                    labelText: 'Ad Soyad',
                    prefixIcon: const Icon(Icons.person, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15))),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Lütfen adınızı girin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: InputDecoration(
                    labelText: 'Telefon / E-posta',
                    prefixIcon:
                        const Icon(Icons.contact_phone, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15))),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Lütfen iletişim bilgisi girin'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                    labelText: 'Giriş için E-posta',
                    prefixIcon: const Icon(Icons.email, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15))),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Lütfen e-posta girin';
                  if (!(value ?? '').contains('@'))
                    return 'Geçerli bir e-posta girin';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Şifre (min. 4 karakter)',
                  prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.teal),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) {
                  if (_acceptNoPasswordRisk) {
                    if (value != null && value.isNotEmpty && value.length < 4) {
                      return 'Şifre en az 4 karakter olmalı';
                    }
                    return null;
                  }

                  if ((value ?? '').isEmpty) return 'Lütfen şifre girin';
                  if ((value?.length ?? 0) < 4)
                    return 'Şifre en az 4 karakter olmalı';
                  return null;
                },
              ),
              if (!_acceptNoPasswordRisk) ...[
                const SizedBox(height: 12),
                Text('İlk 4 karakter hızlı giriş PIN\'i olacaktır',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              _buildTermsAndPolicyCheckbox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsAndPolicyCheckbox() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _privacyPolicyAccepted,
              onChanged: (value) {
                setState(() => _privacyPolicyAccepted = value ?? false);
              },
              activeColor: Colors.teal,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Okudum, anladım ve ',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  children: [
                    TextSpan(
                      text: 'Gizlilik Politikası\'nı',
                      style: const TextStyle(
                        color: Colors.teal,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          _showPolicyDialog(
                              'Gizlilik Politikası', _privacyPolicyText);
                        },
                    ),
                    const TextSpan(text: ' kabul ediyorum.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _termsOfUseAccepted,
              onChanged: (value) {
                setState(() => _termsOfUseAccepted = value ?? false);
              },
              activeColor: Colors.teal,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Okudum, anladım ve ',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  children: [
                    TextSpan(
                      text: 'Kullanım Şartları\'nı',
                      style: const TextStyle(
                        color: Colors.teal,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          _showPolicyDialog(
                              'Kullanım Şartları', _termsOfUseText);
                        },
                    ),
                    const TextSpan(text: ' kabul ediyorum.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _acceptNoPasswordRisk,
              onChanged: (value) {
                setState(() {
                  _acceptNoPasswordRisk = value ?? false;
                  if (_acceptNoPasswordRisk) {
                    _passwordController.clear();
                    _formKey.currentState?.validate();
                  }
                });
              },
              activeColor: Colors.red.shade700,
              checkColor: Colors.white,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Şifre olmadan kaydol ',
                  style: TextStyle(
                    fontSize: 12,
                    color: _acceptNoPasswordRisk
                        ? Colors.red.shade700
                        : Colors.black54,
                  ),
                  children: [
                    TextSpan(
                      text: '(Büyük güvenlik açığı!)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _acceptNoPasswordRisk
                            ? Colors.red.shade900
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPasswordResetEmailForm() {
    return FadeTransition(
      opacity: _formAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Şifre Sıfırlama',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kod göndermek için kayıtlı e-posta adresinizi girin',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: const Icon(Icons.email, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Lütfen e-posta girin';
                  if (!(value ?? '').contains('@'))
                    return 'Geçerli bir e-posta girin';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: _handlePasswordResetEmailRequest,
                  child: const Text('Doğrulama Kodu Gönder',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _showPasswordResetEmailForm = false;
                  _emailController.clear();
                }),
                child: const Text('Giriş ekranına dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCodeForm() {
    return FadeTransition(
      opacity: _formAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kodu Doğrula',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
              const SizedBox(height: 8),
              Text(
                '$_emailForPasswordReset adresine gönderilen 6 haneli kodu girin.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _verificationCodeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 12),
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Doğrulama Kodu',
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Lütfen 6 haneli kodu girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: _handleVerifyCode,
                  child: const Text('Doğrula',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewPasswordForm() {
    return FadeTransition(
      opacity: _formAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Yeni Şifre Belirle',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre (min. 4 karakter)',
                  prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.teal),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) {
                  if ((value ?? '').length < 4) {
                    return 'Şifre en az 4 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: _handleUpdatePassword,
                  child: const Text('Şifreyi Güncelle',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeveloperInfo() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Metsoft Yazılım',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Developed by MET • Powered by MetSoft',
              style: TextStyle(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 11,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _EllipseBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Elips çizimi
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
