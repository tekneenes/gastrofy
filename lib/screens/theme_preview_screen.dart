import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../services/database_service.dart';

enum ViewMode { mobile, tablet, desktop }

class ThemePreviewScreen extends StatefulWidget {
  final String slug;
  final String themeId;
  final String themeName;

  const ThemePreviewScreen({
    super.key,
    required this.slug,
    required this.themeId,
    required this.themeName,
  });

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  late final WebViewController controller;
  bool _isLoading = true;
  ViewMode _currentMode = ViewMode.desktop; // Default to full screen (desktop) per user request
  bool _isLandscape = false;
  String _currentThemeId = '';
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _websiteController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _twitterController = TextEditingController();
  final _googleMapsController = TextEditingController();
  final _mapEmbedController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentThemeId = widget.themeId;
    _loadInitialData();
    _initWebView();
  }

  void _loadInitialData() async {
    final db = DatabaseService();
    final userData = await db.readAllUserData();
    if (userData.isNotEmpty) {
      debugPrint("Önizleme Verisi Yüklendi: ${userData.keys.join(', ')}");
      setState(() {
        // Business Info Fallbacks
        _nameController.text = userData['companyName'] ?? userData['name'] ?? '';
        _addressController.text = userData['address'] ?? '';
        _phoneController.text = userData['companyPhone'] ?? userData['userContact'] ?? userData['phone'] ?? '';
        
        // Social Media & Description Fallbacks (Handle both new and legacy keys)
        _instagramController.text = userData['instagramUrl'] ?? userData['social_instagram_link'] ?? '';
        _facebookController.text = userData['facebookUrl'] ?? userData['social_facebook_link'] ?? '';
        _websiteController.text = userData['websiteUrl'] ?? userData['social_website_link'] ?? '';
        _tiktokController.text = userData['tiktokUrl'] ?? userData['social_tiktok_link'] ?? '';
        _twitterController.text = userData['twitterUrl'] ?? userData['social_twitter_link'] ?? '';
        _googleMapsController.text = userData['googleMapsUrl'] ?? userData['location_link'] ?? '';
        _mapEmbedController.text = userData['mapEmbedCode'] ?? '';
        _descriptionController.text = userData['description'] ?? userData['desc'] ?? '';
      });
    } else {
      debugPrint("Önizleme Verisi BOŞ!");
    }
  }

  void _initWebView() {
    final url =
        'https://gastroqr-5dcdb.web.app/${widget.slug}?theme=$_currentThemeId';
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _updateTheme(String newId) {
    setState(() {
      _currentThemeId = newId;
    });
    final url =
        'https://gastroqr-5dcdb.web.app/${widget.slug}?theme=$newId';
    controller.loadRequest(Uri.parse(url));
  }

  Future<void> _savePanelData() async {
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      final userData = await db.readAllUserData();
      if (userData.isNotEmpty) {
        final Map<String, dynamic> updatedData = Map.from(userData);
        updatedData['instagramUrl'] = _instagramController.text;
        updatedData['facebookUrl'] = _facebookController.text;
        updatedData['websiteUrl'] = _websiteController.text;
        updatedData['tiktokUrl'] = _tiktokController.text;
        updatedData['twitterUrl'] = _twitterController.text;
        updatedData['googleMapsUrl'] = _googleMapsController.text;
        updatedData['mapEmbedCode'] = _mapEmbedController.text;
        
        // Legacy keys for backward compatibility
        updatedData['social_instagram_link'] = _instagramController.text;
        updatedData['social_facebook_link'] = _facebookController.text;
        updatedData['social_website_link'] = _websiteController.text;
        updatedData['social_tiktok_link'] = _tiktokController.text;
        updatedData['social_twitter_link'] = _twitterController.text;
        updatedData['social_maps_link'] = _googleMapsController.text;
        
        updatedData['description'] = _descriptionController.text;
        
        await db.updateUserData(updatedData);
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        await productProvider.updateGastroQRMetadata(updatedData);
        
        // Reload WebView to see changes
        controller.reload();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _websiteController.dispose();
    _tiktokController.dispose();
    _twitterController.dispose();
    _googleMapsController.dispose();
    _mapEmbedController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _showWarning = true;

  Widget _buildPreviewWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(
          top: BorderSide(color: Colors.amber.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined,
              color: Colors.amber.shade800, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "📢 Küçük Bir Hatırlatma",
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ölçeklemeden dolayı tuşlar tam yerinde olmayabilir, bu normaldir. Tam test için lütfen 'Tam Ekran' moduna geçin!",
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: Colors.amber.shade900,
            onPressed: () => setState(() => _showWarning = false),
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    Widget content = Stack(
      children: [
        WebViewWidget(controller: controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.teal),
          ),
      ],
    );

    if (_currentMode == ViewMode.desktop) {
      return content;
    }

    final isMobile = _currentMode == ViewMode.mobile;
    double logicalWidth = isMobile ? 375.0 : 768.0;
    double logicalHeight = isMobile ? 812.0 : 1024.0;

    if (_isLandscape) {
      final temp = logicalWidth;
      logicalWidth = logicalHeight;
      logicalHeight = temp;
    }

    return Container(
      color: Colors.grey.shade200, // Background around the device
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Subtract padding for available space
          final double availableWidth = constraints.maxWidth - 64.0;
          final double availableHeight = constraints.maxHeight - 64.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: availableWidth,
                maxHeight: availableHeight,
              ),
              child: FittedBox(
                fit: BoxFit.contain, // Scales down the entire container to fit within the screen uniformly
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubicEmphasized,
                  width: logicalWidth,
                  height: logicalHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 44 : 24),
                    border: Border.all(color: Colors.grey.shade900, width: 12), // Bezel
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 40,
                        spreadRadius: 5,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isMobile ? 32 : 12),
                    child: content,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.themeName} Önizleme'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              if (await controller.canGoBack()) {
                await controller.goBack();
              }
            },
            tooltip: 'Geri',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
            onPressed: () async {
              if (await controller.canGoForward()) {
                await controller.goForward();
              }
            },
            tooltip: 'İleri',
          ),
          GestureDetector(
            onLongPress: () async {
              // Clear cache and cookies on long press for a "clean refresh"
              final manager = WebViewCookieManager();
              await manager.clearCookies();
              await controller.clearCache();
              await controller.reload();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Önbellek temizlendi ve sayfa yenilendi.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => controller.reload(),
              tooltip: 'Yenile (Uzun Bas: Önbelleği Temizle)',
            ),
          ),
          const VerticalDivider(width: 20, indent: 15, endIndent: 15),
          IconButton(
            icon: Icon(Icons.phone_iphone,
                color: _currentMode == ViewMode.mobile ? Colors.teal : Colors.grey),
            onPressed: () => setState(() => _currentMode = ViewMode.mobile),
            tooltip: 'Mobil Görünüm',
          ),
          IconButton(
            icon: Icon(Icons.tablet_mac,
                color: _currentMode == ViewMode.tablet ? Colors.teal : Colors.grey),
            onPressed: () => setState(() => _currentMode = ViewMode.tablet),
            tooltip: 'Tablet Görünüm',
          ),
          IconButton(
            icon: Icon(Icons.desktop_windows,
                color: _currentMode == ViewMode.desktop ? Colors.teal : Colors.grey),
            onPressed: () => setState(() => _currentMode = ViewMode.desktop),
            tooltip: 'Tam Ekran',
          ),
          if (_currentMode != ViewMode.desktop)
            IconButton(
              icon: Icon(_isLandscape ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_landscape_rounded,
                  color: _isLandscape ? Colors.teal : Colors.grey),
              onPressed: () => setState(() => _isLandscape = !_isLandscape),
              tooltip: _isLandscape ? 'Dikey Görünüm' : 'Yatay Görünüm',
            ),
          const VerticalDivider(width: 20, thickness: 1, indent: 12, endIndent: 12),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.teal),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Görünüm Ayarları',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: _buildControlPanel(),
      body: Column(
        children: [
          Expanded(child: _buildPreviewContent()),
          if (_currentMode != ViewMode.desktop && _showWarning)
            _buildPreviewWarning(),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Drawer(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal.shade700),
            margin: EdgeInsets.zero,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune_rounded, color: Colors.white, size: 40),
                SizedBox(height: 12),
                Text(
                  'Önizleme Ayarları',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader('İŞLETME BİLGİLERİ'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.store_rounded, 'İşletme Adı', _nameController.text),
                _buildInfoRow(Icons.location_on_rounded, 'Adres', _addressController.text),
                _buildInfoRow(Icons.phone_rounded, 'Telefon', _phoneController.text),
                const SizedBox(height: 32),
                _buildSectionHeader('İÇERİK DÜZENLEME'),
                const SizedBox(height: 12),
                _buildDrawerTextField(_descriptionController, 'İşletme Açıklaması', Icons.description_outlined, maxLines: 3),
                const SizedBox(height: 16),
                _buildDrawerTextField(_instagramController, 'Instagram URL', Icons.camera_alt_outlined),
                const SizedBox(height: 12),
                _buildDrawerTextField(_facebookController, 'Facebook URL', Icons.facebook_rounded),
                const SizedBox(height: 12),
                _buildDrawerTextField(_websiteController, 'Web Sitesi URL', Icons.language_rounded),
                const SizedBox(height: 12),
                _buildDrawerTextField(_tiktokController, 'TikTok URL', Icons.music_note_rounded),
                const SizedBox(height: 12),
                _buildDrawerTextField(_twitterController, 'X (Twitter) URL', Icons.alternate_email_rounded),
                const SizedBox(height: 12),
                _buildDrawerTextField(_googleMapsController, 'Google Maps (Konum) Linki', Icons.map_rounded),
                const SizedBox(height: 12),
                _buildDrawerTextField(_mapEmbedController, 'Harita Embed Kodu (Iframe)', Icons.code_rounded, maxLines: 3),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePanelData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Bilgileri Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'İşletme bilgileri ana ayarlar ekranından değiştirilmelidir.',
                    style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w900, color: Colors.teal.shade900, letterSpacing: 1.2),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.teal.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Girilmemiş' : value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.teal.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

