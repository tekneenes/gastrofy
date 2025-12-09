import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'login_screen.dart';
import 'update_screen.dart';
import 'home_screen.dart';
import 'login_settings_screen.dart';
import '../services/database_service.dart';

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
  final _updateFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();

  final _staffFormKey = GlobalKey<FormState>();
  final _staffNameController = TextEditingController();
  final _staffPasswordController = TextEditingController();

  final _socialLinksFormKey = GlobalKey<FormState>();
  final _instagramLinkController = TextEditingController();
  final _whatsappLinkController = TextEditingController();
  final _websiteLinkController = TextEditingController();
  final _twitterLinkController = TextEditingController();
  final _facebookLinkController = TextEditingController();
  final _mapsLinkController = TextEditingController();

  // --- Değişkenler ---
  String _userName = 'Kullanıcı';
  String _userRole = '';
  bool _isAdmin = false;
  List<Map<String, dynamic>> _staffList = [];
  String currentVersion = "3.3.0";
  late bool _isAutoLogoutEnabled;
  late int _autoLogoutMinutes;

  // Sosyal Medya Durumları
  bool _instagramEnabled = false;
  bool _whatsappEnabled = false;
  bool _websiteEnabled = false;
  bool _twitterEnabled = false;
  bool _facebookEnabled = false;
  bool _mapsEnabled = false;

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
    _loadUserData();
    if (widget.loggedInUser['userRole'] == 'Yönetici') {
      _loadAllStaff();
      _loadStaffPermissions();
    }
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
    _newPasswordController.dispose();
    _staffNameController.dispose();
    _staffPasswordController.dispose();
    _instagramLinkController.dispose();
    _whatsappLinkController.dispose();
    _websiteLinkController.dispose();
    _twitterLinkController.dispose();
    _facebookLinkController.dispose();
    _mapsLinkController.dispose();
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

        _instagramEnabled = _parseBool(userData['social_instagram_enabled']);
        _instagramLinkController.text = userData['social_instagram_link'] ?? '';
        _whatsappEnabled = _parseBool(userData['social_whatsapp_enabled']);
        _whatsappLinkController.text = userData['social_whatsapp_link'] ?? '';
        _websiteEnabled = _parseBool(userData['social_website_enabled']);
        _websiteLinkController.text = userData['social_website_link'] ?? '';
        _twitterEnabled = _parseBool(userData['social_twitter_enabled']);
        _twitterLinkController.text = userData['social_twitter_link'] ?? '';
        _facebookEnabled = _parseBool(userData['social_facebook_enabled']);
        _facebookLinkController.text = userData['social_facebook_link'] ?? '';
        _mapsEnabled = _parseBool(userData['social_maps_enabled']);
        _mapsLinkController.text = userData['social_maps_link'] ?? '';
      });
    }
  }

  Future<void> _loadAllStaff() async {
    try {
      final staff = await _dbService.getAllStaff();
      if (mounted) {
        setState(() {
          _staffList = staff;
        });
      }
    } catch (e) {
      debugPrint("Personel listesi yüklenemedi: $e");
    }
  }

  Future<void> _loadStaffPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _permProducts = prefs.getBool('perm_products') ?? false;
        _permReports = prefs.getBool('perm_reports') ?? false;
        _permRecords = prefs.getBool('perm_records') ?? false;
        _permVeresiye = prefs.getBool('perm_veresiye') ?? false;
        // _permCameras = prefs.getBool('perm_cameras') ?? false; // KALDIRILDI
        _permAI = prefs.getBool('perm_ai') ?? false;
      });
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
    _showSnackBar('Hesabınız kalıcı olarak silindi.', isSuccess: true);
    await _secureLogout();
  }

  Future<void> _deleteStaff(int id) async {
    await _dbService.deleteUser(id);
    await _loadAllStaff();
    if (mounted) {
      Navigator.pop(context);
      _showSnackBar('Personel hesabı silindi.', isSuccess: true);
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

  void _attemptSwitchToStaffProfile() {
    if (_staffList.isEmpty) {
      _showSnackBar('Sistemde kayıtlı personel bulunamadı.', isSuccess: false);
      return;
    }
    final targetStaff = _staffList.first;
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        icon: Icons.swap_horiz,
        iconColor: Colors.teal,
        title: 'Personele Geçiş',
        content: [
          Text(
            '${targetStaff['userName']} hesabına geçiş yapılacak. Onaylıyor musunuz?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            '(Tekrar yönetici olmak için çıkış yapıp şifre girmelisiniz.)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              style: _getButtonStyle(Colors.teal),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(loggedInUser: targetStaff),
                  ),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Geçiş Yap'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveSocialLinks() async {
    if (!_socialLinksFormKey.currentState!.validate()) {
      _showSnackBar('Lütfen hatalı alanları düzeltin.', isSuccess: false);
      return;
    }
    final updatedUserData = Map<String, dynamic>.from(widget.loggedInUser);
    updatedUserData.addAll({
      'social_instagram_enabled': _instagramEnabled ? 1 : 0,
      'social_instagram_link': _instagramLinkController.text.trim(),
      'social_whatsapp_enabled': _whatsappEnabled ? 1 : 0,
      'social_whatsapp_link': _whatsappLinkController.text.trim(),
      'social_website_enabled': _websiteEnabled ? 1 : 0,
      'social_website_link': _websiteLinkController.text.trim(),
      'social_twitter_enabled': _twitterEnabled ? 1 : 0,
      'social_twitter_link': _twitterLinkController.text.trim(),
      'social_facebook_enabled': _facebookEnabled ? 1 : 0,
      'social_facebook_link': _facebookLinkController.text.trim(),
      'social_maps_enabled': _mapsEnabled ? 1 : 0,
      'social_maps_link': _mapsLinkController.text.trim(),
    });

    try {
      if (_isAdmin) {
        await _dbService.updateUserData(updatedUserData,
            userContact: null, companyName: '', userName: '', userEmail: '');
      } else {
        await _dbService.updateStaffUser(updatedUserData);
      }
      widget.onUserUpdated(updatedUserData);
      setState(() {
        widget.loggedInUser.clear();
        widget.loggedInUser.addAll(updatedUserData);
      });
      _showSnackBar('Bağlantılar kaydedildi!', isSuccess: true);
    } catch (e) {
      _showSnackBar('Hata: $e', isSuccess: false);
    }
  }

  void _handleProfileEditAttempt() {
    final currentPass = widget.loggedInUser['userPassword'];
    if (currentPass == null || currentPass.toString().isEmpty) {
      _showUpdateUserInfoDialog(showPasswordField: true);
    } else {
      _showPasswordVerificationDialog();
    }
  }

  Future<void> _checkForUpdate() async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                UpdateScreen(currentVersion: currentVersion)));
  }

  Future<void> _exportDatabaseAsJson() async {
    _showSnackBar('Bu özellik şu anda geliştirme aşamasındadır.',
        isSuccess: true);
  }

  // --- Dialog Göstericiler ---

  void _showStaffPermissionsDialog() {
    bool tempProducts = _permProducts;
    bool tempReports = _permReports;
    bool tempRecords = _permRecords;
    bool tempVeresiye = _permVeresiye;
    // bool tempCameras = _permCameras; // KALDIRILDI
    bool tempAI = _permAI;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _buildCustomDialog(
              icon: Icons.shield_rounded,
              iconColor: Colors.deepOrange,
              title: 'Personel Yetkileri',
              content: [
                const Text(
                  'Bu ayarlar tüm personel hesapları için geçerlidir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildPermissionSwitch(
                    'Ürünler',
                    MdiIcons.shoppingOutline,
                    tempProducts,
                    (v) => setStateDialog(() => tempProducts = v)),
                _buildPermissionSwitch('Raporlar', Icons.bar_chart, tempReports,
                    (v) => setStateDialog(() => tempReports = v)),
                _buildPermissionSwitch('Kayıtlar', Icons.receipt_long,
                    tempRecords, (v) => setStateDialog(() => tempRecords = v)),
                _buildPermissionSwitch(
                    'Veresiye',
                    Icons.article_outlined,
                    tempVeresiye,
                    (v) => setStateDialog(() => tempVeresiye = v)),
                // KAMERA SWITCH KALDIRILDI
                _buildPermissionSwitch('AI Asistan', MdiIcons.brain, tempAI,
                    (v) => setStateDialog(() => tempAI = v)),
              ],
              actions: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    style: _getButtonStyle(Colors.deepOrange),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('perm_products', tempProducts);
                      await prefs.setBool('perm_reports', tempReports);
                      await prefs.setBool('perm_records', tempRecords);
                      await prefs.setBool('perm_veresiye', tempVeresiye);
                      // await prefs.setBool('perm_cameras', tempCameras); // KALDIRILDI
                      await prefs.setBool('perm_ai', tempAI);

                      setState(() {
                        _permProducts = tempProducts;
                        _permReports = tempReports;
                        _permRecords = tempRecords;
                        _permVeresiye = tempVeresiye;
                        // _permCameras = tempCameras; // KALDIRILDI
                        _permAI = tempAI;
                      });
                      Navigator.pop(context);
                      _showSnackBar('Personel yetkileri güncellendi.',
                          isSuccess: true);
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStaffDialog({Map<String, dynamic>? staff}) {
    final bool isEditing = staff != null;
    _staffNameController.text = isEditing ? (staff['userName'] ?? '') : '';
    _staffPasswordController.text =
        isEditing ? (staff['userPassword'] ?? '') : '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
        iconColor: Colors.purple,
        title: isEditing ? 'Personeli Düzenle' : 'Yeni Personel',
        content: [
          Text(
            isEditing
                ? 'Personel bilgilerini güncelleyin.'
                : 'Yeni bir personel hesabı oluşturun.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Form(
            key: _staffFormKey,
            child: Column(
              children: [
                _buildStyledTextField(
                  controller: _staffNameController,
                  labelText: 'Personel Adı',
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? 'İsim boş olamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _staffPasswordController,
                  labelText: 'Şifre (İsteğe bağlı)',
                  icon: Icons.lock_outline,
                  obscureText: false,
                  validator: null,
                ),
              ],
            ),
          )
        ],
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Personeli Sil'),
                    content: const Text('Silmek istediğinize emin misiniz?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('İptal')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteStaff(staff['id']);
                        },
                        child: const Text('Sil',
                            style: TextStyle(color: Colors.red)),
                      )
                    ],
                  ),
                );
              },
            ),
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: _getButtonStyle(Colors.purple),
              onPressed: () async {
                if (_staffFormKey.currentState!.validate()) {
                  final staffData = {
                    'userName': _staffNameController.text,
                    'userRole': 'Personel',
                    'userEmail': 'personel@sistem',
                    'userPassword': _staffPasswordController.text,
                    'companyName': widget.loggedInUser['companyName'] ?? '',
                    'createdAt': DateTime.now().toIso8601String(),
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

                  if (isEditing) {
                    await _dbService.updateStaffById(staff['id'], staffData);
                    _showSnackBar('Personel güncellendi.', isSuccess: true);
                  } else {
                    await _dbService.addStaffUser(staffData);
                    _showSnackBar('Personel eklendi.', isSuccess: true);
                  }
                  await _loadAllStaff();
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Güncelle' : 'Oluştur'),
            ),
          ),
        ],
      ),
    );
  }

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
                  _showUpdateUserInfoDialog();
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

  void _showUpdateUserInfoDialog({bool showPasswordField = false}) {
    final bool isReadOnly = !_isAdmin;
    if (showPasswordField) _newPasswordController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: isReadOnly ? Icons.info_outline_rounded : Icons.edit_note_rounded,
        iconColor: Colors.blue,
        title: isReadOnly ? 'Kullanıcı Bilgileri' : 'Bilgileri Düzenle',
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
                _buildStyledTextField(
                  controller: _companyNameController,
                  labelText: 'Firma Adı',
                  icon: Icons.business_rounded,
                  readOnly: isReadOnly,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildStyledTextField(
                  controller: _nameController,
                  labelText: 'Ad Soyad',
                  icon: Icons.person_rounded,
                  readOnly: isReadOnly,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _contactController,
                    labelText: 'İletişim',
                    icon: Icons.phone_rounded,
                    validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _emailController,
                    labelText: 'E-posta',
                    icon: Icons.email_rounded,
                    validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                  ),
                  if (showPasswordField) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text("Yeni Şifre Belirle",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    _buildStyledTextField(
                      controller: _newPasswordController,
                      labelText: 'Yeni Şifre',
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
                    });

                    if (showPasswordField &&
                        _newPasswordController.text.isNotEmpty) {
                      updatedUserData['userPassword'] =
                          _newPasswordController.text;
                    }

                    await _dbService.updateUserData(updatedUserData,
                        userContact: null,
                        companyName: '',
                        userName: '',
                        userEmail: '');
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
                  _buildSettingsTile(
                    icon: Icons.lock_person_rounded,
                    color: Colors.indigo.shade600,
                    title: 'Giriş Yöntemleri',
                    subtitle: 'PIN ve Biyometrik ayarları',
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const LoginSettingsScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Personel Yönetimi ---
              _buildSettingsCard(
                title: 'Personel Yönetimi',
                children: [
                  _buildSettingsTile(
                    icon: Icons.swap_horiz,
                    color: Colors.teal.shade700,
                    title: 'Personele Geçiş',
                    subtitle: 'Hızlıca personel olarak giriş yap',
                    onTap: _attemptSwitchToStaffProfile,
                  ),
                  _buildSettingsTile(
                    icon: Icons.shield_rounded,
                    color: Colors.deepOrange,
                    title: 'Personel Yetkileri',
                    subtitle: 'Hangi sayfaların görüneceğini seçin',
                    onTap: _showStaffPermissionsDialog,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Divider(height: 1),
                  ),

                  // Personel Listesi Başlığı
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      "KAYITLI PERSONELLER",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  if (_staffList.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            "Henüz personel eklenmemiş.",
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._staffList.map((staff) {
                      return Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showStaffDialog(staff: staff),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Personel Avatarı
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                          197, 0, 124, 218),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (staff['userName'] ?? 'P')[0]
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: const Color.fromARGB(
                                              255, 255, 255, 255),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // İsim ve Şifre Bilgisi
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          staff['userName'] ?? 'Personel',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.key,
                                                size: 14,
                                                color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(
                                              staff['userPassword'] ?? '******',
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                  fontFamily: 'Monospace'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Düzenle İkonu
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                  // Yeni Personel Ekle Butonu
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54, // Standart yükseklik
                      child: ElevatedButton.icon(
                        onPressed: () => _showStaffDialog(),
                        icon: const Icon(Icons.person_add_rounded, size: 22),
                        label: const Text(
                          "Yeni Personel Ekle",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                              255, 0, 128, 163), // Açık mor arka plan
                          foregroundColor: const Color.fromARGB(
                              255, 255, 255, 255), // Koyu mor yazı/ikon
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          // Butona basıldığındaki efekt rengi
                          overlayColor: const Color.fromARGB(255, 0, 194, 81),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
            _buildSettingsCard(
              title: 'Sosyal Medya ve Web',
              children: [
                Form(
                  key: _socialLinksFormKey,
                  child: Column(
                    children: [
                      _buildSocialLinkTile(
                          MdiIcons.instagram,
                          Colors.pink,
                          'Instagram',
                          _instagramEnabled,
                          _instagramLinkController,
                          (v) => setState(() => _instagramEnabled = v)),
                      _buildSocialLinkTile(
                          MdiIcons.whatsapp,
                          Colors.green,
                          'WhatsApp',
                          _whatsappEnabled,
                          _whatsappLinkController,
                          (v) => setState(() => _whatsappEnabled = v)),
                      _buildSocialLinkTile(
                          MdiIcons.web,
                          Colors.blue,
                          'Web Sitesi',
                          _websiteEnabled,
                          _websiteLinkController,
                          (v) => setState(() => _websiteEnabled = v)),
                      _buildSocialLinkTile(
                          MdiIcons.twitter,
                          Colors.black,
                          'X (Twitter)',
                          _twitterEnabled,
                          _twitterLinkController,
                          (v) => setState(() => _twitterEnabled = v)),
                      _buildSocialLinkTile(
                          MdiIcons.facebook,
                          Colors.indigo,
                          'Facebook',
                          _facebookEnabled,
                          _facebookLinkController,
                          (v) => setState(() => _facebookEnabled = v)),
                      _buildSocialLinkTile(
                          MdiIcons.googleMaps,
                          Colors.red,
                          'Google Maps',
                          _mapsEnabled,
                          _mapsLinkController,
                          (v) => setState(() => _mapsEnabled = v)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text('Bağlantıları Kaydet'),
                            style: _getButtonStyle(Colors.teal),
                            onPressed: _handleSaveSocialLinks,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              title: 'Güvenlik',
              children: [
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
              title: 'Veri ve Güncellemeler',
              children: [
                _buildSettingsTile(
                  icon: MdiIcons.databaseArrowDownOutline,
                  color: Colors.indigo.shade600,
                  title: 'Veritabanını Dışa Aktar',
                  subtitle: 'Yedekle',
                  onTap: _exportDatabaseAsJson,
                ),
                _buildSettingsTile(
                  icon: Icons.system_update_alt_rounded,
                  color: Colors.orange.shade800,
                  title: 'Yazılım Güncellemesi',
                  subtitle: "v$currentVersion (Kontrol et)",
                  onTap: _checkForUpdate,
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
              color: Colors.teal.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.teal.shade50,
            child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 32, color: Colors.teal.shade800)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userName,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    maxLines: 1),
                const SizedBox(height: 4),
                Text(_userRole,
                    style: TextStyle(
                        fontSize: 15, color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
        ],
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

  Widget _buildSocialLinkTile(
    IconData icon,
    Color color,
    String title,
    bool isEnabled,
    TextEditingController controller,
    ValueChanged<bool> onToggle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Column(
        children: [
          _buildSettingsTile(
              icon: icon,
              color: color,
              title: title,
              trailing: Switch(
                  value: isEnabled, onChanged: onToggle, activeColor: color)),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                      hintText: 'Link girin...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
            ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
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
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor:
            isSuccess ? Colors.teal.shade600 : Colors.redAccent.shade700,
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
}
