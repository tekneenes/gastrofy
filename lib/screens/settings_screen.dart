import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // Dosya işlemleri için
import 'package:path_provider/path_provider.dart'; // Temp dizin için
import 'package:share_plus/share_plus.dart'; // Paylaşım için
import 'package:file_picker/file_picker.dart'; // Dosya seçimi için
import 'dart:convert'; // JSON encode/decode
import 'login_screen.dart';
import 'splash_screen.dart';

import 'theme_selection_screen.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';
import '../providers/table_provider.dart';
import '../services/database_helper.dart'; // DatabaseHelper eklendi 
import 'edit_profile_screen.dart';
import 'subscription_plans_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> loggedInUser;
  final bool initialAutoLogoutEnabled;
  final int initialAutoLogoutMinutes;
  final Function(bool, int) onAutoLogoutChanged;
  final Function(Map<String, dynamic>) onUserUpdated;

  const SettingsScreen({
    super.key,
    required this.loggedInUser,
    required this.initialAutoLogoutEnabled,
    required this.initialAutoLogoutMinutes,
    required this.onAutoLogoutChanged,
    required this.onUserUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dbService = DatabaseService();

  // --- Controller'lar ---
  final _passwordVerificationController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _websiteController = TextEditingController();
  final _updateFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();



  // --- Değişkenler ---
  bool _isLoading = false; // EKLENDİ
  String _userName = 'Kullanıcı';
  String _userRole = '';
  bool _isAdmin = false;
  late bool _isAutoLogoutEnabled;
  late int _autoLogoutMinutes;

  // Personel Yönetimi Değişkenleri
  List<Map<String, dynamic>> _allStaff = [];
  bool _isStaffLoading = false;

  // Abonelik Planı Değişkenleri
  String _currentPlan = 'Ücretsiz Deneme';
  String? _planExpiryFormatted;
  bool _isPlanActive = false;

  // Hızlı Giriş Değişkeni
  bool _isFastLoginEnabled = false;

  // Personel İzinleri
  bool _permProducts = false;
  bool _permReports = false;
  bool _permRecords = false;
  bool _permVeresiye = false;
  // bool _permCameras = false; // KALDIRILDI
  bool _permAI = false;

  @override
  void initState() {
    super.initState();
    // İlk değerleri widget'tan alarak senkronize şekilde ayarla
    final userData = widget.loggedInUser;
    _userName = userData['userName'] ?? 'Kullanıcı';
    _userRole = userData['userRole'] ?? 'Kullanıcı';
    _isAdmin = _userRole == 'Yönetici' || _userRole == 'Müdür';
    
    _loadUserData();
    _loadSubscriptionPlan();
    _loadFastLoginSetting();
    _loadStaff();
    _isAutoLogoutEnabled = widget.initialAutoLogoutEnabled;
    _autoLogoutMinutes = widget.initialAutoLogoutMinutes;
  }

  @override
  void dispose() {
    _passwordVerificationController.dispose();
    _companyNameController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _companyPhoneController.dispose();
    _taxNumberController.dispose();
    _newPasswordController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  // --- Veri Yükleme ---

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  Future<void> _loadUserData() async {
    final userData = widget.loggedInUser;
    if (mounted) {
      setState(() {
        _userName = userData['userName'] ?? 'Kullanıcı';
        _userRole = userData['userRole'] ?? 'Kullanıcı';
        _isAdmin = _userRole == 'Yönetici' || _userRole == 'Müdür';

        _companyNameController.text = userData['companyName'] ?? '';
        _nameController.text = userData['userName'] ?? '';
        _contactController.text = userData['userContact'] ?? '';
        _emailController.text = userData['userEmail'] ?? '';
        _addressController.text = userData['address'] ?? '';
        _companyPhoneController.text = userData['companyPhone'] ?? '';
        _taxNumberController.text = userData['taxNumber'] ?? '';
        _instagramController.text = userData['instagramUrl'] ?? userData['social_instagram_link'] ?? '';
        _facebookController.text = userData['facebookUrl'] ?? userData['social_facebook_link'] ?? '';
        _websiteController.text = userData['websiteUrl'] ?? userData['social_website_link'] ?? '';

      });
    }
  }

  Future<void> _loadSubscriptionPlan() async {
    try {
      final info = await _dbService.getLicenseRemainingInfo();
      String plan = info['planName'] ?? widget.loggedInUser['plan']?.toString() ?? '';
      if (plan.isEmpty || plan == 'Trial') {
        plan = 'Ücretsiz Deneme';
      }

      final bool isExpired = info['isExpired'] == true;
      final String formatted = info['formatted'] ?? '';

      if (mounted) {
        setState(() {
          _currentPlan = plan;
          _isPlanActive = !isExpired && (info['status'] == 'active' || info['status'] == 'trial');
          _planExpiryFormatted = formatted;
        });
      }
    } catch (e) {
      debugPrint("Abonelik planı yükleme hatası: $e");
    }
  }

  Future<void> _loadStaff() async {
    if (!_isAdmin) return;
    setState(() => _isStaffLoading = true);
    try {
      final staff = await _dbService.getAllStaff();
      if (mounted) {
        setState(() {
          _allStaff = staff;
          _isStaffLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Personel yüklenirken hata: $e");
      if (mounted) setState(() => _isStaffLoading = false);
    }
  }


  // --- İşlemler ---

  Future<void> _secureLogout() async {
    try {
      final List<Map<String, dynamic>> allUsers =
          await _dbService.getAllUsers();
      final bool adminExists =
          allUsers.any((user) => user['userRole'] == 'Yönetici');

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            allUsers: allUsers,
            adminExists: adminExists,
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) _showSnackBar('Hata: $e', isSuccess: false);
    }
  }

  Future<void> _deleteAccount() async {
    _passwordVerificationController.clear();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return _buildCustomDialog(
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
            title: 'Hesabı Sil',
            content: [
              const Text(
                'DİKKAT: Hesabınızı silmek üzeresiniz. Bu işlem geri alınamaz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tüm verileriniz (masalar, siparişler, personel, lisans) sunucularımızdan kalıcı olarak silinecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Devam etmek için şifrenizi girin:',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordVerificationController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mevcut Şifre',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
            actions: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : () async {
                    if (_passwordVerificationController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lütfen şifrenizi girin.')),
                      );
                      return;
                    }

                    // 1. Yerel Şifre Kontrolü
                    final savedPassword = widget.loggedInUser['userPassword'];
                    if (_passwordVerificationController.text != savedPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hatalı şifre!')),
                      );
                      return;
                    }

                    setState(() => _isLoading = true);

                    // 2. Firebase Silme İşlemi
                    final result = await FirebaseService.instance.deleteCompanyAccount(
                      widget.loggedInUser, 
                      _passwordVerificationController.text
                    );
                    
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    Navigator.pop(context); // Dialogu kapat

                    if (result['success'] == true) {
                      _showSnackBar(result['message'], isSuccess: true);
                      // 3. Yerel Veriyi TAMAMEN Temizle ve Uygulamayı Yeniden Başlat (Splash'e dön)
                      await _dbService.clearAllData();
                      
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => SplashScreen()),
                        (route) => false,
                      );
                    } else {
                      _showSnackBar(result['message'], isSuccess: false);
                    }
                  },
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Hesabı Kalıcı Sil'),
                ),
              ),
            ],
          );
        }
      ),
    );
  }


  Future<void> _loadFastLoginSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isFastLoginEnabled = prefs.getBool('fast_login_enabled') ?? false;
      });
    }
  }

  Future<void> _handleFastLoginSwitch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fast_login_enabled', value);
    if (mounted) {
      setState(() {
        _isFastLoginEnabled = value;
      });
      _showSnackBar(
        value
            ? 'Hızlı Giriş etkinleştirildi. Artık profilinize dokunulduğunda şifresiz geçiş yapılacak.'
            : 'Hızlı Giriş kapatıldı. Girişte şifre/PIN sorulacak.',
        isSuccess: true,
      );
    }
  }

  void _handleAutoLogoutSwitch(bool enabled) {
    setState(() => _isAutoLogoutEnabled = enabled);
    if (enabled) {
      _showAutoLogoutDurationDialog();
    } else {
      widget.onAutoLogoutChanged(false, _autoLogoutMinutes);
      _showSnackBar('Otomatik oturum kapatma devre dışı bırakıldı.');
    }
  }



  void _handleProfileEditAttempt() {
    final currentPass = widget.loggedInUser['userPassword'];
    if (currentPass == null || currentPass.toString().isEmpty) {
      _navigateToEditProfile();
    } else {
      _showPasswordVerificationDialog();
    }
  }


  Future<void> _exportDatabaseAsJson() async {
    setState(() => _isLoading = true);
    try {
      // 1. Tüm verileri topla
      final secureData = await _dbService.readAllUserData();
      final db = await DatabaseHelper.instance.database;
      final sqliteData = await DatabaseHelper.instance.exportDatabaseToJson(db);

      final fullData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'secure_storage': secureData,
        'sqlite': sqliteData,
      };

      // 2. JSON'a çevir
      final jsonString = jsonEncode(fullData);
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'yedek_$dateStr.json';

      // 3. Platform Kontrolü
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Masaüstü: Dosyayı Kaydet
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Yedeği Kaydet',
          fileName: fileName,
          allowedExtensions: ['json'],
          type: FileType.custom,
        );

        if (outputFile != null) {
           final file = File(outputFile);
           await file.writeAsString(jsonString);
           _showSnackBar('Yedek başarıyla kaydedildi: $outputFile', isSuccess: true);
        } else {
           // Kullanıcı iptal etti
        }
      } else {
        // Mobil: Geçici Dizin -> Paylaş
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(jsonString);

        final result = await Share.shareXFiles([XFile(file.path)], 
            text: 'Restoran Yedek Dosyası ($dateStr)');

        if (result.status == ShareResultStatus.success) {
          _showSnackBar('Yedekleme başarılı!', isSuccess: true);
        }
      }
    } catch (e) {
      debugPrint('Export Error: $e');
      _showSnackBar('Hata: $e (Uygulamayı tamamen kapatıp açmayı deneyin)', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importDatabaseFromJson() async {
    try {
      // 1. Dosya Seç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        
        // 2. Onay İste
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => _buildCustomDialog(
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
            title: 'Verileri Geri Yükle',
            content: [
              const Text(
                'DİKKAT: Bu işlem mevcut tüm verilerinizi (masalar, siparişler, ayarlar) silecektir ve yedekten geri yükleyecektir.\n\nDevam etmek istiyor musunuz?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
            actions: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal'),
                ),
              ),
               Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: _getButtonStyle(Colors.red),
                  child: const Text('Geri Yükle'),
                ),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        setState(() => _isLoading = true);

        // 3. Veriyi İşle ve Yükle
        final Map<String, dynamic> fullData = jsonDecode(jsonString);
        
        if (fullData['secure_storage'] != null) {
           final secureMap = Map<String, String>.from(fullData['secure_storage']);
           await _dbService.restoreAllData(secureMap);
        }

        if (fullData['sqlite'] != null) {
           final sqliteMap = Map<String, dynamic>.from(fullData['sqlite']);
           await DatabaseHelper.instance.restoreDatabaseFromJson(sqliteMap);
        }

        // 4. Başarılı -> Çıkış Yap
        _showSnackBar('Geri yükleme başarılı! Uygulama yeniden başlatılıyor...', isSuccess: true);
        await Future.delayed(const Duration(seconds: 2));
        
        // Uygulamayı yeniden başlatmak yerine login ekranına atalım
        if (!mounted) return;
        // Provider'ları güncellemek gerekebilir ama en temiz yöntem restart/re-login
        await _secureLogout();

      }
    } catch (e) {
      _showSnackBar('Geri yükleme hatası: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Dialog Göstericiler ---



  void _showStaffCredentialsDialog() {
    final username = widget.loggedInUser['userName'] ?? '';
    final password = widget.loggedInUser['userPassword'] ?? '';
    final hasPassword = password.toString().isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.lock_open_rounded,
        iconColor: Colors.blue.shade600,
        title: 'Giriş Bilgilerim',
        content: [
          const Text('Bu bilgilerle sisteme giriş yapıyorsunuz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kullanıcı Adı:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(username, style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Şifre:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(hasPassword ? password : '(Şifre Yok)',
                        style: TextStyle(
                            fontSize: 16,
                            color: hasPassword ? Colors.black : Colors.grey,
                            fontStyle: hasPassword
                                ? FontStyle.normal
                                : FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ],
        actions: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: _getButtonStyle(Colors.blue.shade600),
              child: const Text('Tamam'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordVerificationDialog() {
    _passwordVerificationController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: Icons.password_rounded,
        iconColor: Colors.orange,
        title: 'Güvenlik',
        content: [
          const Text('Bilgileri düzenlemek için mevcut şifrenizi girin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          _buildStyledTextField(
            controller: _passwordVerificationController,
            labelText: 'Şifreniz',
            icon: Icons.key_rounded,
            obscureText: true,
          ),
        ],
        actions: [
          Expanded(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'))),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final savedPassword = widget.loggedInUser['userPassword'];
                if (_passwordVerificationController.text == savedPassword) {
                  Navigator.pop(context);
                  _navigateToEditProfile();
                } else {
                  _showSnackBar('Hatalı şifre!', isSuccess: false);
                }
              },
              style: _getButtonStyle(Colors.orange),
              child: const Text('Doğrula'),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          loggedInUser: widget.loggedInUser,
          onUserUpdated: (updatedData) {
            setState(() {
              widget.loggedInUser.clear();
              widget.loggedInUser.addAll(updatedData);
            });
            widget.onUserUpdated(updatedData);
            _loadUserData();
          },
        ),
      ),
    );
  }

  void _showUpdateUserInfoDialog({bool showPasswordField = false}) {
    final bool isReadOnly = !_isAdmin;
    if (showPasswordField) {
      _newPasswordController.clear();
      _passwordVerificationController.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: isReadOnly ? Icons.info_outline_rounded : Icons.edit_note_rounded,
        iconColor: Colors.blue,
        title: isReadOnly ? 'Profil Bilgileri' : 'Profili Düzenle',
        content: [
          if (isReadOnly)
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                  "Bu bilgiler sadece yönetici tarafından değiştirilebilir.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
          Form(
            key: _updateFormKey,
            child: Column(
              children: [
                // --- İŞLETME BİLGİLERİ ---
                _buildSectionLabel("İşletme Bilgileri"),
                _buildStyledTextField(
                  controller: _companyNameController,
                  labelText: 'İşletme Adı',
                  icon: Icons.business_rounded,
                  readOnly: isReadOnly,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _taxNumberController,
                  labelText: 'Vergi Numarası',
                  icon: Icons.confirmation_number_outlined,
                  readOnly: isReadOnly,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _addressController,
                  labelText: 'İşletme Adresi',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                  readOnly: isReadOnly,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _companyPhoneController,
                  labelText: 'İşletme Telefonu',
                  icon: Icons.phone_android_rounded,
                  readOnly: isReadOnly,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _instagramController,
                  labelText: 'Instagram Adresi',
                  icon: Icons.camera_alt_outlined,
                  readOnly: isReadOnly,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _facebookController,
                  labelText: 'Facebook Adresi',
                  icon: Icons.facebook_rounded,
                  readOnly: isReadOnly,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _websiteController,
                  labelText: 'Web Sitesi',
                  icon: Icons.language_rounded,
                  readOnly: isReadOnly,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // --- YÖNETİCİ BİLGİLERİ ---
                _buildSectionLabel("Yönetici Bilgileri"),
                _buildStyledTextField(
                  controller: _nameController,
                  labelText: 'Ad Soyad',
                  icon: Icons.person_rounded,
                  readOnly: isReadOnly,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                if (_isAdmin) ...[
                  _buildStyledTextField(
                    controller: _contactController,
                    labelText: 'Yönetici Telefon',
                    icon: Icons.phone_rounded,
                    readOnly: isReadOnly,
                    validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _emailController,
                    labelText: 'E-posta Adresi',
                    icon: Icons.email_rounded,
                    readOnly: isReadOnly,
                    validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                  ),
                  if (showPasswordField) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildSectionLabel("Güvenlik"),
                    if (widget.loggedInUser['userPassword'] != null && 
                        widget.loggedInUser['userPassword'].toString().isNotEmpty) ...[
                      _buildStyledTextField(
                        controller: _passwordVerificationController,
                        labelText: 'Mevcut Şifre',
                        icon: Icons.lock_open_rounded,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildStyledTextField(
                      controller: _newPasswordController,
                      labelText: 'Yeni Şifre Belirle',
                      icon: Icons.lock_outline,
                      obscureText: false,
                    ),
                  ]
                ],
              ],
            ),
          ),
        ],
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isReadOnly ? 'Kapat' : 'İptal'),
            ),
          ),
          if (!isReadOnly) ...[
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (_updateFormKey.currentState!.validate()) {
                    final updatedUserData =
                        Map<String, dynamic>.from(widget.loggedInUser);
                    updatedUserData.addAll({
                      'companyName': _companyNameController.text,
                      'userName': _nameController.text,
                      'userContact': _contactController.text,
                      'userEmail': _emailController.text,
                      'address': _addressController.text,
                      'companyPhone': _companyPhoneController.text,
                      'taxNumber': _taxNumberController.text,
                      'instagramUrl': _instagramController.text,
                      'facebookUrl': _facebookController.text,
                      'websiteUrl': _websiteController.text,
                      'social_instagram_link': _instagramController.text,
                      'social_facebook_link': _facebookController.text,
                      'social_website_link': _websiteController.text,
                    });

                    if (showPasswordField &&
                        _newPasswordController.text.isNotEmpty) {
                      
                      final currentPass = widget.loggedInUser['userPassword'];
                      // Eğer mevcut şifre varsa, doğrula
                      if (currentPass != null && 
                          currentPass.toString().isNotEmpty && 
                          _passwordVerificationController.text != currentPass) {
                        _showSnackBar('Mevcut şifre hatalı!', isSuccess: false);
                        return;
                      }

                      updatedUserData['userPassword'] =
                          _newPasswordController.text;
                    }

                     await _dbService.updateUserData(updatedUserData);
                    await FirebaseService.instance.updateCompanyProfile(updatedUserData);
                    
                    // GastroQR Sync
                    final productProvider = Provider.of<ProductProvider>(context, listen: false);
                    await productProvider.updateGastroQRMetadata(updatedUserData);

                    widget.onUserUpdated(updatedUserData);
                    Navigator.pop(context);
                    setState(() {
                      widget.loggedInUser.clear();
                      widget.loggedInUser.addAll(updatedUserData);
                    });
                    await _loadUserData();
                    _showSnackBar('Bilgiler güncellendi!', isSuccess: true);
                  }
                },
                style: _getButtonStyle(Colors.blue),
                child: const Text('Kaydet'),
              ),
            ),
          ]
        ],
      ),
    );
  }

  void _showDeleteAccountWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red.shade700,
        title: 'Hesabı Sil?',
        content: const [
          Text(
            'Bu işlem geri alınamaz. Tüm veriler silinecektir. Emin misiniz?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
        actions: [
          Expanded(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'))),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteAccountPasswordDialog();
              },
              style: _getButtonStyle(Colors.red.shade700),
              child: const Text('Devam Et'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountPasswordDialog() {
    _passwordVerificationController.clear();
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.shield_rounded,
        iconColor: Colors.red.shade800,
        title: 'Son Onay',
        content: [
          const Text('Hesabı silmek için şifrenizi girin.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _passwordVerificationController,
            labelText: 'Şifre',
            icon: Icons.key_rounded,
            obscureText: true,
          ),
        ],
        actions: [
          Expanded(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç'))),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final savedPassword = widget.loggedInUser['userPassword'];
                if (_passwordVerificationController.text == savedPassword) {
                  Navigator.pop(context);
                  _deleteAccount();
                } else {
                  Navigator.pop(context);
                  _showSnackBar('Hatalı şifre.', isSuccess: false);
                }
              },
              style: _getButtonStyle(Colors.red.shade800),
              child: const Text('Sil'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAutoLogoutDurationDialog() {
    int selectedMinutes = _autoLogoutMinutes;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildCustomDialog(
              icon: Icons.timer_outlined,
              iconColor: Colors.teal,
              title: 'Süre Ayarla',
              content: [
                Text('Uygulama kaç dakika sonra kapansın?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 24),
                Text('$selectedMinutes Dakika',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700)),
                Slider(
                  value: selectedMinutes.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: Colors.teal,
                  onChanged: (value) =>
                      setDialogState(() => selectedMinutes = value.round()),
                ),
              ],
              actions: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _isAutoLogoutEnabled = false);
                      widget.onAutoLogoutChanged(false, _autoLogoutMinutes);
                    },
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _autoLogoutMinutes = selectedMinutes);
                      widget.onAutoLogoutChanged(true, _autoLogoutMinutes);
                      Navigator.pop(context);
                      _showSnackBar('Ayarlandı: $selectedMinutes dk',
                          isSuccess: true);
                    },
                    style: _getButtonStyle(Colors.teal),
                    child: const Text('Ayarla'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- BUILD METHODU ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Ayarlar',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            if (_isAdmin) ...[
              _buildSettingsCard(
                title: 'Hesap Yönetimi',
                children: [
                  _buildSettingsTile(
                    icon: Icons.admin_panel_settings_rounded,
                    color: Colors.blue.shade800,
                    title: 'Yönetici Profili',
                    subtitle: 'Kendi bilgilerinizi düzenleyin',
                    onTap: _handleProfileEditAttempt,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSettingsCard(
                title: 'Abonelik & Lisans Planları',
                children: [
                  _buildSettingsTile(
                    icon: Icons.workspace_premium_rounded,
                    color: Colors.amber.shade700,
                    title: 'Gastrofy Premium & Abonelik Planları',
                    subtitle: 'Mevcut Plan: $_currentPlan • Planları incele',
                    onTap: () async {
                      final email = widget.loggedInUser['userEmail']?.toString() ?? 'isletme@gastrofy.com';
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionPlansScreen(
                            email: email,
                            currentPlan: _currentPlan,
                            loggedInUser: widget.loggedInUser,
                          ),
                        ),
                      );
                      if (res == true || mounted) {
                        _loadSubscriptionPlan();
                      }
                    },
                  ),
                ],
              ),

            ] else ...[
              _buildSettingsCard(
                title: 'Hesap Bilgileri',
                children: [
                  _buildSettingsTile(
                    icon: Icons.person_outline_rounded,
                    color: Colors.blue.shade600,
                    title: 'Kullanıcı Bilgileri',
                    subtitle: 'Firma ve isim bilgilerini görüntüle',
                    onTap: _showUpdateUserInfoDialog,
                  ),
                  _buildSettingsTile(
                    icon: Icons.key_rounded,
                    color: Colors.indigo.shade600,
                    title: 'Giriş Bilgilerim',
                    subtitle: 'Kullanıcı adı ve şifreni gör',
                    onTap: _showStaffCredentialsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Güvenlik',
              children: [
                _buildSettingsTile(
                  icon: Icons.bolt_rounded,
                  color: Colors.teal.shade600,
                  title: 'Hızlı Giriş (Şifresiz)',
                  subtitle: _isFastLoginEnabled
                      ? 'Açık: Şifre sormadan doğrudan ana sayfaya geçer'
                      : 'Kapalı: Girişte şifre/PIN sorulur',
                  trailing: Switch(
                    value: _isFastLoginEnabled,
                    onChanged: _handleFastLoginSwitch,
                    activeColor: Colors.teal.shade600,
                  ),
                ),
                if (_isAdmin)
                  _buildSettingsTile(
                    icon: Icons.timer_off_outlined,
                    color: Colors.orange.shade700,
                    title: 'Otomatik Oturum Kapatma',
                    subtitle: _isAutoLogoutEnabled
                        ? 'Aktif: $_autoLogoutMinutes dk'
                        : 'Kapalı',
                    trailing: Switch(
                        value: _isAutoLogoutEnabled,
                        onChanged: _handleAutoLogoutSwitch,
                        activeColor: Colors.orange.shade700),
                  ),
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  color: Colors.blueGrey.shade600,
                  title: 'Güvenli Çıkış',
                  subtitle: 'Oturumu sonlandır',
                  onTap: _secureLogout,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Destek ve İletişim',
              children: [
                _buildSettingsTile(
                  icon: Icons.support_agent_rounded,
                  color: Colors.purple.shade700,
                  title: 'Öneri, Şikayet ve Hata Bildirimi',
                  subtitle: 'Geliştirici ekibimize mesaj gönderin',
                  onTap: _showSupportDialog,
                ),
                _buildSettingsTile(
                  icon: Icons.school_rounded,
                  color: Colors.indigo.shade600,
                  title: 'Uygulama Rehberini (Eğitimi) Sıfırla',
                  subtitle: 'Tanıtım turunu ana sayfada yeniden göster',
                  onTap: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('seen_main_tutorial', false);
                      if (mounted) {
                        _showSnackBar('Eğitim turu sıfırlandı. Ana sayfaya döndüğünüzde tekrar gösterilecektir.');
                      }
                    } catch (e) {
                      if (mounted) _showSnackBar('Hata: $e', isSuccess: false);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Bilgi ve Yasal',
              children: [
                _buildSettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  color: Colors.teal.shade700,
                  title: 'Gizlilik Politikası',
                  subtitle: 'Verilerinizin nasıl işlendiğini görün',
                  onTap: () => _showContractDialog('privacy'),
                ),
                _buildSettingsTile(
                  icon: Icons.description_rounded,
                  color: Colors.orange.shade800,
                  title: 'Kullanım Koşulları',
                  subtitle: 'Hizmet kullanım şartları',
                  onTap: () => _showContractDialog('terms'),
                ),
              ],
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              _buildSettingsCard(
                title: 'Tehlikeli Bölge',
                children: [
                  _buildSettingsTile(
                    icon: Icons.delete_forever_rounded,
                    color: Colors.red.shade700,
                    title: 'Hesabı Sil',
                    subtitle: 'Tüm sistemi sıfırla',
                    onTap: _showDeleteAccountWarningDialog,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- Yardımcı Widget'lar ---

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.teal.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 460;

          final profileInfo = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_userRole,
                        style: TextStyle(
                            fontSize: 15, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
            ],
          );

          final planBadge = InkWell(
            onTap: () async {
              final email = widget.loggedInUser['userEmail']?.toString() ?? 'isletme@gastrofy.com';
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionPlansScreen(
                    email: email,
                    currentPlan: _currentPlan,
                    loggedInUser: widget.loggedInUser,
                  ),
                ),
              );
              if (res == true || mounted) {
                _loadSubscriptionPlan();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentPlan.contains('Yıllık')
                        ? Icons.workspace_premium_rounded
                        : (_currentPlan.contains('Aylık')
                            ? Icons.verified_rounded
                            : Icons.card_membership_rounded),
                    color: _currentPlan.contains('Yıllık')
                        ? const Color(0xFFFEF08A)
                        : Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPlan,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _planExpiryFormatted ?? (_isPlanActive ? 'Aktif Abonelik' : 'Planı Değiştir'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profileInfo,
                const SizedBox(height: 16),
                planBadge,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: profileInfo),
              const SizedBox(width: 16),
              planBadge,
            ],
          );
        },
      ),
    );
  }



  Widget _buildSettingsCard(
      {required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.grey.shade800))),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF1A1A2E))),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14))
                      ],
                    ]),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      validator: validator,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.grey.shade50,
      ),
    );
  }

  // --- Ortak Metodlar ---

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isError
                    ? Icons.error_outline_rounded
                    : (isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded),
                color: Colors.white,
                size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : (isSuccess ? Colors.teal.shade600 : Colors.grey.shade800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCustomDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> content,
    required List<Widget> actions,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 16),
              ...content,
              const SizedBox(height: 24),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: actions),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _getButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)));
  }

  Widget _buildPermissionSwitch(
      String title, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: SwitchListTile(
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          secondary: Icon(icon, color: Colors.deepOrange.shade400),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.deepOrange,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          dense: true,
        ),
      ),
    );
  }

  // --- Personel Yönetimi Widget'ları ---

  // ignore: unused_element
  Widget _buildStaffManagementSection() {
    return _buildSettingsCard(
      title: 'Personel Yönetimi',
      children: [
        if (_isStaffLoading)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _buildStaffList(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showStaffDialog(),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Yeni Personel Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildStaffList() {
    if (_allStaff.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text('Henüz personel eklenmedi.', 
            style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allStaff.length,
      itemBuilder: (context, index) {
        final staff = _allStaff[index];
        final role = staff['userRole'] ?? 'Garson';
        final color = _getRoleColor(role);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 18,
              child: Icon(_getRoleIcon(role), color: color, size: 20),
            ),
            title: Text(staff['userName'] ?? 'İsimsiz', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(role, style: TextStyle(color: color, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  onPressed: () => _showSyncQR(staff),
                  tooltip: 'Cihazı Bağla',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.teal.withOpacity(0.05),
                    foregroundColor: Colors.teal,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showStaffDialog(staff: staff);
                    if (val == 'delete') _showDeleteConfirmation(staff);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Düzenle')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
                  ],
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStaffDialog({Map<String, dynamic>? staff}) {
    final nameController = TextEditingController(text: staff?['userName']);
    final pinController = TextEditingController(text: staff?['quickLoginPin']);
    final emailController = TextEditingController(text: staff?['userEmail']);
    String selectedRole = staff?['userRole'] ?? 'Garson';
    final roles = ['Garson', 'Kasiyer', 'Şube Müdürü'];
    final isEditing = staff != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Personel Düzenle' : 'Yeni Personel Ekle',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: nameController,
                  label: 'Ad Soyad',
                  icon: Icons.person_outline,
                ),
                _buildDialogTextField(
                  controller: pinController,
                  label: 'Giriş PIN',
                  icon: Icons.lock_outline,
                  isPin: true,
                ),
                const SizedBox(height: 16),
                _buildDialogTextField(
                  controller: emailController,
                  label: 'E-posta (Şifre Sıfırlama İçin)',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(_getRoleIcon(selectedRole), color: Colors.teal),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && pinController.text.isNotEmpty) {
                  final data = {
                    'userName': nameController.text,
                    'quickLoginPin': pinController.text,
                    'userRole': selectedRole,
                    'userEmail': emailController.text.isNotEmpty 
                        ? emailController.text 
                        : (staff?['userEmail'] ?? '${nameController.text.toLowerCase().replaceAll(' ', '')}@gastrofy.com'),
                    'userPassword': staff?['userPassword'] ?? '',
                  };

                  if (isEditing) {
                    await _dbService.updateStaffById(staff!['id'], data);
                  } else {
                    await _dbService.addStaffUser(data);
                  }
                  
                  if (mounted) Navigator.pop(context);
                  _loadStaff();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isEditing ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPin = false,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: isPin ? TextInputType.number : TextInputType.text,
      obscureText: isPin,
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text('${staff['userName']} isimli personeli silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await _dbService.deleteUser(staff['id']);
              if (mounted) Navigator.pop(context);
              _loadStaff();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  // ignore: unused_element
  Widget _buildGastroQRSection() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        // provider.isGastroQREnabled is bool
        // we need to make sure provider is casting and used as ProductProvider
        final prodProvider = provider;
        final isEnabled = prodProvider.isGastroQREnabled;
        final companyEmail = widget.loggedInUser['userEmail'] ?? '';
        final publicMenuUrl = "https://gastroqr.com/menu/${companyEmail.replaceAll('.', '_')}";

        return _buildSettingsCard(
          title: 'GastroQR Menü Yönetimi',
          children: [
            _buildSettingsTile(
              icon: Icons.qr_code_scanner_rounded,
              color: Colors.purple.shade700,
              title: 'GastroQR Menü Özelliği',
              subtitle: isEnabled 
                ? 'Aktif: Ürünler buluta senkronize ediliyor.' 
                : 'Kapalı: Dijital menü devre dışı.',
              trailing: Switch(
                value: isEnabled,
                onChanged: (val) async {
                  await prodProvider.toggleGastroQR(val);
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Ürün Fotoğraflarını Göster', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Menüde ürün görsellerini açar/kapatır.'),
              value: prodProvider.showProductPhotos,
              activeColor: Colors.teal,
              onChanged: (val) async {
                await prodProvider.toggleProductPhotos(val);
                _showSnackBar(val ? 'Fotoğraflar Aktifleştirildi' : 'Fotoğraflar Gizlendi', isSuccess: true);
              },
            ),
            if (isEnabled) ...[
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.palette_rounded,
                color: Colors.orange.shade700,
                title: 'Menü Tasarımı',
                subtitle: 'Siteniz için modern bir tema seçin.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ThemeSelectionScreen()),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    prodProvider.themeId == 'midnight' ? 'Midnight' : 
                    prodProvider.themeId == 'earth' ? 'Earth' : 
                    prodProvider.themeId == 'glass' ? 'Glass' : 
                    prodProvider.themeId == 'zen' ? 'Zen' : 
                    prodProvider.themeId == 'nordic' ? 'Nordic' : 
                    prodProvider.themeId == 'flame' ? 'Flame' : 'Retro',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.link_rounded,
                color: Colors.indigo.shade700,
                title: 'Özel Menü Linki',
                subtitle: prodProvider.companySlug != null 
                  ? 'Aktif: gastroqr.com/${prodProvider.companySlug}' 
                  : 'Henüz özel link tanımlanmadı.',
                onTap: () => _showSlugDialog(prodProvider),
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.cloud_upload_rounded,
                color: Colors.blue.shade700,
                title: 'Tüm Ürünleri Senkronize Et',
                subtitle: 'Mevcut ürün listesini GastroQR\'a gönderir.',
                onTap: () async {
                  setState(() => _isLoading = true);
                  await prodProvider.syncAllToGastroQR(metadata: {
                    'companyName': widget.loggedInUser['companyName'],
                    'companyPhone': widget.loggedInUser['companyPhone'],
                    'address': widget.loggedInUser['address'],
                  });
                  setState(() => _isLoading = false);
                  _showSnackBar('Tüm ürünler başarıyla senkronize edildi.', isSuccess: true);
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildSettingsTile(
                icon: Icons.share_rounded,
                color: Colors.teal.shade700,
                title: 'QR Menü Kodu ve Link',
                subtitle: 'Müşterileriniz için QR kod oluşturun.',
                onTap: () {
                  final finalUrl = prodProvider.companySlug != null
                      ? "https://gastroqr-5dcdb.web.app/${prodProvider.companySlug}"
                      : "https://gastroqr-5dcdb.web.app/menu/${companyEmail.replaceAll('.', '_')}";
                  _showGastroQRDialog(finalUrl);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  void _showGastroQRDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.qr_code_2_rounded,
        iconColor: Colors.purple.shade700,
        title: 'Dijital Menü (GastroQR)',
        content: [
          const Text('Aşağıdaki QR kodu masalarınıza yerleştirerek müşterilerinizin dijital menüye erişmesini sağlayabilirsiniz.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
                foregroundColor: const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          ),
        ],
        actions: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: _getButtonStyle(Colors.purple.shade700),
              child: const Text('Kapat'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSlugDialog(ProductProvider provider) {
    final slugController = TextEditingController(text: provider.companySlug);
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _buildCustomDialog(
          icon: Icons.link_rounded,
          iconColor: Colors.indigo.shade700,
          title: 'Özel Menü Linki',
          content: [
            const Text('İşletmenize özel, akılda kalıcı bir link belirleyin. Sadece küçük harf, sayı ve tire kullanabilirsiniz.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 20),
            _buildStyledTextField(
              controller: slugController,
              labelText: 'Örnek: altin-tepsi',
              icon: Icons.edit_rounded,
            ),
            const SizedBox(height: 10),
            Text('Linkiniz şöyle görünecek:\ngastroqr-5dcdb.web.app/${slugController.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ],
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isChecking ? null : () async {
                final newSlug = slugController.text.trim().toLowerCase();
                if (newSlug.isEmpty) return;
                
                setDialogState(() => isChecking = true);
                final success = await provider.updateSlug(newSlug);
                setDialogState(() => isChecking = false);

                if (success) {
                  if (mounted) Navigator.pop(context);
                  _showSnackBar('Özel link başarıyla güncellendi!', isSuccess: true);
                } else {
                  _showSnackBar('Bu link kullanımda veya geçersiz karakter içeriyor.', isSuccess: false);
                }
              },
              style: _getButtonStyle(Colors.indigo.shade700),
              child: isChecking 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog() {
    final messageController = TextEditingController();
    final emailController = TextEditingController(text: widget.loggedInUser['userEmail']);
    String selectedCategory = 'Öneri';
    final categories = ['Öneri', 'Şikayet', 'Hata Bildirimi'];
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _buildCustomDialog(
          icon: Icons.contact_support_rounded,
          iconColor: Colors.purple,
          title: 'Destek ve İletişim',
          content: [
            const Text('Görüşleriniz bizim için değerlidir. Lütfen kategoriyi seçip mesajınızı yazın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Mesajınıza en geç 7 gün içinde geri dönüş yapılacaktır.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 20),
            _buildStyledTextField(
              controller: emailController,
              labelText: 'İletişim E-postası',
              icon: Icons.email_rounded,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setDialogState(() => selectedCategory = val!),
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.category_rounded, color: Colors.purple),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Mesajınız',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.message_rounded, color: Colors.purple),
                ),
              ),
            ),
          ],
          actions: [
            Expanded(
              child: TextButton(
                onPressed: isSending ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                onPressed: isSending ? null : () async {
                  if (messageController.text.trim().isEmpty) {
                    _showSnackBar('Lütfen bir mesaj yazın.', isSuccess: false);
                    return;
                  }
                  if (emailController.text.trim().isEmpty) {
                    _showSnackBar('Lütfen geçerli bir e-posta adresi girin.', isSuccess: false);
                    return;
                  }
                  
                  setDialogState(() => isSending = true);
                  
                  // Güncel email bilgisini de içeren bir kopya oluştur
                  final updatedUser = Map<String, dynamic>.from(widget.loggedInUser);
                  updatedUser['userEmail'] = emailController.text.trim();

                  final success = await FirebaseService.instance.sendSupportMessage(
                    category: selectedCategory,
                    message: messageController.text.trim(),
                    user: updatedUser,
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    if (success) {
                      _showSnackBar('Mesajınız başarıyla gönderildi.', isSuccess: true);
                    } else {
                      _showSnackBar('Mesaj gönderilemedi. Lütfen daha sonra tekrar deneyin.', isSuccess: false);
                    }
                  }
                },
                style: _getButtonStyle(Colors.purple),
                child: isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Color _getRoleColor(String role) {
    switch (role) {
      case 'Şube Müdürü': return Colors.purple;
      case 'Kasiyer': return Colors.orange;
      case 'Garson': return Colors.blue;
      default: return Colors.grey;
    }
  }

  // Assuming this is a new function or a modification to an existing one
  // that maps theme identifiers to display names, as the provided snippet
  // was syntactically incorrect for _getRoleColor and mixed roles with themes.
  // This function is added to fulfill the "display logic" part of the request
  // while maintaining syntactic correctness.
  String _getThemeDisplayName(String themeIdentifier) {
    switch (themeIdentifier) {
      case 'flame':
        return 'Flame Rush';
      case 'bamboo':
        return 'Bamboo Whisper';
      default:
        return 'Retro Diner';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Şube Müdürü': return Icons.verified_user_rounded;
      case 'Kasiyer': return Icons.point_of_sale_rounded;
      case 'Garson': return Icons.restaurant_rounded;
      default: return Icons.person_rounded;
    }
  }

  void _showContractDialog(String type) {
    String title = type == 'privacy' ? 'Gizlilik Politikası' : 'Kullanım Koşulları';
    String content = type == 'privacy' 
        ? FirebaseService.defaultPrivacyText 
        : FirebaseService.defaultTermsText;
    String updateDate = '2026';

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  if (updateDate.isNotEmpty)
                    Text('Son Güncelleme: $updateDate', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.teal,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              elevation: 0,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncQR(Map<String, dynamic> staff) async {
    final String staffName = staff['userName'] ?? 'Personel';
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    String? ip = await tableProvider.syncServerIp;
    if (ip == null || tableProvider.syncRole != SyncRole.server) {
      await tableProvider.setSyncMode(enabled: true, role: SyncRole.server);
      ip = tableProvider.syncServerIp;
    }
    if (!mounted) return;
    if (ip == null) {
      _showSnackBar('Yerel IP adresi alınamadı.', isSuccess: false);
      return;
    }

    final String qrData = 'SYNCCLIENT:$ip|${staff['userEmail'] ?? ''}|${staff['userPassword'] ?? ''}|${staff['quickLoginPin'] ?? ''}|${staff['userRole'] ?? ''}|$staffName';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Column(
          children: [
            const Icon(Icons.wifi_tethering_rounded, color: Colors.teal, size: 48),
            const SizedBox(height: 16),
            Text('$staffName - Terminal Bağlantısı', 
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Personelin cihazından bu kodu taratarak ana terminale bağlanmasını sağlayın.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                foregroundColor: Colors.teal.shade900,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Sunucu IP: $ip', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }
}
