import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../services/database_service.dart';
import 'main_screen.dart';

class QrJoiningScreen extends StatefulWidget {
  const QrJoiningScreen({super.key});

  @override
  State<QrJoiningScreen> createState() => _QrJoiningScreenState();
}

class _QrJoiningScreenState extends State<QrJoiningScreen> {
  bool _isProcessing = false;

  void _handleTerminalConnect(
    String ip, 
    BuildContext context, {
    String? email,
    String? password,
    String? pin,
    String? role,
    String? name,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final tableProvider = Provider.of<TableProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sunucuya bağlanılıyor: $ip'),
      backgroundColor: Colors.teal,
    ));

    await tableProvider.setSyncMode(
      enabled: true,
      ip: ip,
      role: SyncRole.client,
    );

    // Başarıyla bağlandıktan sonra taranan veya geçici profil ile ana ekrana aktar
    final Map<String, dynamic> terminalUser = {
      'userName': name ?? 'Terminal Cihazı',
      'userRole': role ?? 'Garson',
      'userEmail': email ?? 'terminal@gastrofy.local',
      'userPassword': password ?? 'terminal_password',
      'quickLoginPin': pin ?? '000000',
    };

    // Bilgileri yerel veritabanına kaydet ki çıkış yapıldığında tekrar kayıt ekranına dönmesin
    final dbService = DatabaseService();
    await dbService.saveUserData(
      companyName: name != null ? 'Personel Terminali' : 'Bağlı Terminal',
      userName: terminalUser['userName']!,
      userContact: 'terminal',
      userEmail: terminalUser['userEmail']!,
      userPassword: terminalUser['userPassword']!,
      quickLoginPin: terminalUser['quickLoginPin']!,
      userRole: terminalUser['userRole']!,
      termsAcceptedOn: DateTime.now().toIso8601String(),
    );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainScreen(loggedInUser: terminalUser),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.startsWith('SYNCCLIENT:')) {
                  final data = code.substring(12); // SYNCCLIENT: sonrasını al
                  
                  if (data.contains('|')) {
                    // Yeni format: ip|email|password|pin|role|name
                    final parts = data.split('|');
                    if (parts.length >= 6) {
                      _handleTerminalConnect(
                        parts[0].trim(), // IP'yi temizle (whitespace vb.)
                        context,
                        email: parts[1],
                        password: parts[2],
                        pin: parts[3],
                        role: parts[4],
                        name: parts[5],
                      );
                      break;
                    }
                  }
                  
                  // Eski format veya hatalı yeni format: Sadece IP
                  _handleTerminalConnect(data.trim(), context);
                  break;
                }
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Terminal Bağlantı Kodu Tara',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 48), // Denge
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  color: Colors.black54,
                  child: Column(
                    children: [
                      if (_isProcessing)
                        const CircularProgressIndicator(color: Colors.teal)
                      else
                        const Icon(Icons.qr_code_scanner, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Kasa veya Ana cihazdaki Ayarlar bölümünden "Terminal Bağlantı Kodu"nu açın ve buraya okutun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
