import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/firebase_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> loggedInUser;
  final Function(Map<String, dynamic>) onUserUpdated;

  const EditProfileScreen({
    super.key,
    required this.loggedInUser,
    required this.onUserUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _dbService = DatabaseService();
  final _updateFormKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _companyNameController;
  late TextEditingController _taxNumberController;
  late TextEditingController _addressController;
  late TextEditingController _companyPhoneController;
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _emailController;
  late TextEditingController _newPasswordController;
  late TextEditingController _currentPasswordController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.loggedInUser;
    _companyNameController = TextEditingController(text: user['companyName'] ?? '');
    _taxNumberController = TextEditingController(text: user['taxNumber'] ?? '');
    _addressController = TextEditingController(text: user['address'] ?? '');
    _companyPhoneController = TextEditingController(text: user['companyPhone'] ?? '');
    _nameController = TextEditingController(text: user['userName'] ?? '');
    _contactController = TextEditingController(text: user['userContact'] ?? '');
    _emailController = TextEditingController(text: user['userEmail'] ?? '');
    _newPasswordController = TextEditingController();
    _currentPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    _companyPhoneController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_updateFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedUserData = Map<String, dynamic>.from(widget.loggedInUser);
      
      updatedUserData.addAll({
        'companyName': _companyNameController.text.trim(),
        'taxNumber': _taxNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'companyPhone': _companyPhoneController.text.trim(),
        'userName': _nameController.text.trim(),
        'userContact': _contactController.text.trim(),
        'userEmail': _emailController.text.trim(),
      });

      // Şifre değişikliği varsa
      if (_newPasswordController.text.isNotEmpty) {
        final currentPass = widget.loggedInUser['userPassword'];
        
        // Mevcut şifre kontrolü
        if (currentPass != null && 
            currentPass.toString().isNotEmpty && 
            _currentPasswordController.text != currentPass) {
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mevcut şifre hatalı!'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        updatedUserData['userPassword'] = _newPasswordController.text;
        // Standardize PIN to 6 digits
        // Standardize PIN to 6 digits (Numeric only)
        String newPin = _newPasswordController.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (newPin.length < 6) {
          newPin = newPin.padRight(6, '0');
        } else {
          newPin = newPin.substring(0, 6);
        }
        updatedUserData['quickLoginPin'] = newPin;
      }

      // Veritabanı Güncelleme
      await _dbService.updateUserData(updatedUserData);
      await FirebaseService.instance.updateCompanyProfile(updatedUserData);
      
      // Callback ve çıkış
      widget.onUserUpdated(updatedUserData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Profili Düzenle', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _updateFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader("İşletme Bilgileri", Icons.store_mall_directory_rounded),
              const SizedBox(height: 16),
              _buildCard([
                _buildTextField(
                  controller: _companyNameController,
                  label: 'İşletme Adı',
                  icon: Icons.business_rounded,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _taxNumberController,
                  label: 'Vergi Numarası',
                  icon: Icons.confirmation_number_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'İşletme Adresi',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _companyPhoneController,
                  label: 'İşletme Telefonu',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
              ]),

              const SizedBox(height: 32),
              _buildSectionHeader("Yönetici Bilgileri", Icons.person_rounded),
              const SizedBox(height: 16),
              
              _buildCard([
                _buildTextField(
                  controller: _nameController,
                  label: 'Ad Soyad',
                  icon: Icons.badge_rounded,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _contactController,
                  label: 'Yönetici Telefon',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'E-posta Adresi',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Boş bırakılamaz' : null,
                ),
              ]),

              const SizedBox(height: 32),
              _buildSectionHeader("Güvenlik & Şifre", Icons.security_rounded),
              const SizedBox(height: 16),

              _buildCard([
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Şifrenizi değiştirmek istemiyorsanız bu alanı boş bırakın.",
                          style: TextStyle(color: Colors.black87, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.loggedInUser['userPassword'] != null && 
                    widget.loggedInUser['userPassword'].toString().isNotEmpty) ...[
                  _buildTextField(
                    controller: _currentPasswordController,
                    label: 'Mevcut Şifre',
                    icon: Icons.lock_open_rounded,
                    obscureText: true,
                    helperText: "Şifre değiştirmek için gereklidir",
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(
                  controller: _newPasswordController,
                  label: 'Yeni Şifre Belirle',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
              ]),

              const SizedBox(height: 40),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded),
                          SizedBox(width: 12),
                          Text('Değişiklikleri Kaydet', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal.shade700, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
