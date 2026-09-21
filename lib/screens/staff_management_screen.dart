import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/database_service.dart';
import '../services/local_sync_service.dart';
import '../providers/table_provider.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _dbService = DatabaseService();
  List<Map<String, dynamic>> _allStaff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final staff = await _dbService.getAllStaff();
      setState(() {
        _allStaff = staff;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Personel yüklenirken hata: $e");
      setState(() => _isLoading = false);
    }
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
                    
                    // Create Firebase Auth user for staff
                    await FirebaseService.instance.createAuthUser(
                      data['userEmail'], 
                      data['userPassword']
                    );
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
      keyboardType: isPin ? TextInputType.number : TextInputType.text,
      obscureText: isPin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Personel Yönetimi', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: _showSyncQR,
            tooltip: 'Terminal Bağlantı QR',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allStaff.isEmpty
                    ? _buildEmptyState()
                    : _buildStaffList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffDialog(),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Yeni Ekle'),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final waiterCount = _allStaff.where((s) => s['userRole'] == 'Garson').length;
    final cashierCount = _allStaff.where((s) => s['userRole'] == 'Kasiyer').length;
    final managerCount = _allStaff.where((s) => s['userRole'] == 'Şube Müdürü').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Garson', waiterCount, Colors.blue),
          _buildSummaryItem('Kasiyer', cashierCount, Colors.orange),
          _buildSummaryItem('Müdür', managerCount, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), 
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)
              ],
            ),
            child: Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          Text('Henüz Personel Yok', 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 8),
          Text('Ekibinizi büyütmek için "+" butonuna basın.', 
            style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      itemCount: _allStaff.length,
      itemBuilder: (context, index) {
        final staff = _allStaff[index];
        final role = staff['userRole'] ?? 'Garson';
        final color = _getRoleColor(role);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getRoleIcon(role), color: color, size: 28),
            ),
            title: Text(staff['userName'] ?? 'İsimsiz', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(role, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('PIN: ****', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  onPressed: () => _showSyncQR(staff: staff),
                  tooltip: 'Cihazı Bağla',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.teal.withOpacity(0.05),
                    foregroundColor: Colors.teal,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showStaffDialog(staff: staff);
                    } else if (val == 'delete') {
                      _showDeleteConfirmation(staff);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Düzenle')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
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

  void _showSyncQR({Map<String, dynamic>? staff}) async {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    
    // Sunucuyu başlat ve IP al
    String? ip = await tableProvider.syncServerIp;
    if (ip == null || tableProvider.syncRole != SyncRole.server) {
      // Eğer henüz ayarlanmamışsa sunucu moduna al
      await tableProvider.setSyncMode(enabled: true, role: SyncRole.server);
      ip = tableProvider.syncServerIp;
    }

    if (!mounted) return;

    if (ip == null) {
      _showSnackBar('Yerel IP adresi alınamadı. WiFi bağlantınızı kontrol edin.', isSuccess: false);
      return;
    }

    String qrData = 'SYNCCLIENT:$ip';
    String title = 'Terminal Bağlantı Kodu';
    
    if (staff != null) {
      final name = staff['userName'] ?? 'Personel';
      qrData += '|${staff['userEmail'] ?? ''}|${staff['userPassword'] ?? ''}|${staff['quickLoginPin'] ?? ''}|${staff['userRole'] ?? ''}|$name';
      title = '$name - Bağlantı Kodu';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Column(
          children: [
            const Icon(Icons.wifi_tethering_rounded, color: Colors.teal, size: 48),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Diğer cihazları bu ana cihaza bağlamak için aşağıdaki kodu taratın.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                foregroundColor: Colors.teal.shade900,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('IP: $ip', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
            const SizedBox(height: 16),
            const Text('Not: Tüm cihazların aynı WiFi ağına bağlı olduğundan emin olun.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isSuccess ? Colors.green : Colors.red,
    ));
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Şube Müdürü': return Colors.purple;
      case 'Kasiyer': return Colors.orange;
      case 'Garson': return Colors.blue;
      default: return Colors.grey;
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
}
