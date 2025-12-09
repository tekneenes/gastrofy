import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

enum CameraViewMode { fullScreenSwipe, grid2x2, grid3x3 }

class _CamerasScreenState extends State<CamerasScreen> {
  static const int _maxCameras = 9;
  List<String?> _cameraUrls = List.filled(_maxCameras, null);
  List<VideoPlayerController?> _videoControllers =
      List.filled(_maxCameras, null);

  List<bool> _isInitializing = List.filled(_maxCameras, false);
  List<bool> _hasError = List.filled(_maxCameras, false);
  List<String?> _errorMessages = List.filled(_maxCameras, null);

  CameraViewMode _currentViewMode = CameraViewMode.grid2x2;
  bool _isFullScreenTile = false;
  int? _fullScreenIndex;

  final PageController _pageController = PageController();
  final TextEditingController _cameraUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _disposeControllers();
    _pageController.dispose();
    _cameraUrlController.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (int i = 0; i < _videoControllers.length; i++) {
      _videoControllers[i]?.dispose();
    }
  }

  // --- AYAR VE VERİ YÖNETİMİ ---

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewModeString = prefs.getString('cameraViewMode') ??
          CameraViewMode.grid2x2.toString();

      final loadedMode = CameraViewMode.values.firstWhere(
        (e) => e.toString() == viewModeString,
        orElse: () => CameraViewMode.grid2x2,
      );

      if (mounted) {
        setState(() {
          _currentViewMode = loadedMode;
        });
      }

      // Kameraları yükle
      for (int i = 0; i < _maxCameras; i++) {
        final url = prefs.getString('camera_$i');
        if (url != null && url.isNotEmpty) {
          _cameraUrls[i] = url;
          // Her kamera arasında küçük gecikme
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await _initializeCamera(i, url);
          }
        }
      }
    } catch (e) {
      debugPrint('🚨 Ayarlar yükleme hatası: $e');
    }
  }

  Future<void> _saveCameraUrl(int index, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camera_$index', url);

    if (mounted) {
      setState(() {
        _cameraUrls[index] = url;
      });
      await _initializeCamera(index, url);
    }
  }

  Future<void> _saveViewMode(CameraViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cameraViewMode', mode.toString());
    if (mounted) {
      setState(() {
        _currentViewMode = mode;
        _isFullScreenTile = false;
        _fullScreenIndex = null;
      });
    }
  }

  // --- KAMERA BAŞLATMA ---

  Future<void> _initializeCamera(int index, String url) async {
    if (!mounted) return;

    if (_isInitializing[index]) {
      debugPrint('⚠️ Kamera $index zaten başlatılıyor...');
      return;
    }

    debugPrint(
        '🎥 Kamera $index başlatılıyor: ${url.length > 30 ? url.substring(0, 30) : url}...');

    if (mounted) {
      setState(() {
        _isInitializing[index] = true;
        _hasError[index] = false;
        _errorMessages[index] = null;
      });
    }

    // Eski controller'ı temizle
    final oldController = _videoControllers[index];
    if (oldController != null) {
      try {
        if (mounted) {
          setState(() => _videoControllers[index] = null);
        }
        await Future.delayed(const Duration(milliseconds: 200));
        await oldController.dispose();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('⚠️ Eski controller temizleme hatası: $e');
      }
    }

    if (!mounted) return;

    try {
      // VideoPlayerController oluştur
      VideoPlayerController controller;

      if (url.startsWith('rtsp://')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        throw Exception('Geçersiz URL formatı. RTSP veya HTTP(S) kullanın.');
      }

      // Initialize et
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // Otomatik tekrar oynat
      controller.setLooping(true);

      // Volume ayarla
      controller.setVolume(0.0);

      // Başarılı olduysa widget'a ver
      setState(() {
        _videoControllers[index] = controller;
        _isInitializing[index] = false;
        _hasError[index] = false;
      });

      // Oynat
      await controller.play();

      // Hata dinleyicisi ekle
      controller.addListener(() {
        if (controller.value.hasError && mounted) {
          setState(() {
            _hasError[index] = true;
            _errorMessages[index] =
                controller.value.errorDescription ?? 'Bilinmeyen hata';
          });
          debugPrint(
              '🚨 Kamera $index oynatma hatası: ${controller.value.errorDescription}');
        }
      });

      debugPrint('✅ Kamera $index başarıyla başlatıldı');
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('🚨 Kamera $index başlatma hatası: $errorMsg');

      if (mounted) {
        setState(() {
          _videoControllers[index] = null;
          _isInitializing[index] = false;
          _hasError[index] = true;
          _errorMessages[index] = _getErrorMessage(errorMsg);
        });

        _showSnackBar(
          'Kamera ${index + 1}: ${_getErrorMessage(errorMsg)}',
          isSuccess: false,
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Geçersiz URL')) {
      return 'Geçersiz URL formatı';
    } else if (error.contains('timeout') || error.contains('timed out')) {
      return 'Zaman aşımı. URL ve ağı kontrol edin.';
    } else if (error.contains('connection') ||
        error.contains('failed to connect')) {
      return 'Bağlantı kurulamadı.';
    } else if (error.contains('unauthorized') || error.contains('401')) {
      return 'Kimlik doğrulama hatası. Kullanıcı adı/şifre kontrol edin.';
    } else if (error.contains('not found') || error.contains('404')) {
      return 'Yayın bulunamadı.';
    } else {
      return 'Bağlantı hatası';
    }
  }

  // --- KULLANICI ETKİLEŞİMLERİ ---

  void _onCameraTap(int index) {
    if (_cameraUrls[index] == null) {
      _showAddCameraDialog(index);
      return;
    }
    if (_currentViewMode != CameraViewMode.fullScreenSwipe) {
      setState(() {
        if (_isFullScreenTile && _fullScreenIndex == index) {
          _isFullScreenTile = false;
          _fullScreenIndex = null;
        } else {
          _isFullScreenTile = true;
          _fullScreenIndex = index;
        }
      });
    }
  }

  void _cycleViewMode() {
    CameraViewMode newMode;
    switch (_currentViewMode) {
      case CameraViewMode.fullScreenSwipe:
        newMode = CameraViewMode.grid2x2;
        break;
      case CameraViewMode.grid2x2:
        newMode = CameraViewMode.grid3x3;
        break;
      case CameraViewMode.grid3x3:
        newMode = CameraViewMode.fullScreenSwipe;
        break;
    }
    _saveViewMode(newMode);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
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
                    fontSize: 15, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor:
          isSuccess ? Colors.teal.shade600 : Colors.redAccent.shade700,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ));
  }

  void _showAddCameraDialog(int index) {
    _cameraUrlController.text = _cameraUrls[index] ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCustomDialog(
        icon: Icons.videocam_rounded,
        iconColor: Colors.teal,
        title: 'Kamera ${index + 1} Ayarları',
        content: [
          const Text(
              'Lütfen kameranın RTSP veya HTTP yayın URL adresini girin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Örnek URL Formatları:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'rtsp://kullanici:sifre@192.168.1.100:554/stream1',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                Text(
                  'http://192.168.1.100:8080/video',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStyledTextField(
            controller: _cameraUrlController,
            labelText: 'Kamera URL',
            icon: Icons.link_rounded,
          ),
        ],
        actions: [
          Expanded(
            child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                child: const Text('İptal')),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final url = _cameraUrlController.text.trim();
                if (url.isNotEmpty) {
                  _saveCameraUrl(index, url);
                  _showSnackBar(
                      'Kamera ${index + 1} kaydedildi. Başlatılıyor...',
                      isSuccess: true);
                }
                Navigator.pop(context);
              },
              style: _getButtonStyle(Colors.teal),
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI WIDGET'LARI ---

  @override
  Widget build(BuildContext context) {
    if (_isFullScreenTile && _fullScreenIndex != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onDoubleTap: () => _onCameraTap(_fullScreenIndex!),
          child: Center(child: _buildCameraTile(_fullScreenIndex!)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text('Kameralar',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24)),
        toolbarHeight: 70,
        backgroundColor: Colors.teal,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [_buildViewModeButton(), const SizedBox(width: 8)],
      ),
      body: _buildCameraView(),
    );
  }

  Widget _buildCameraView() {
    int crossAxisCount;
    switch (_currentViewMode) {
      case CameraViewMode.fullScreenSwipe:
        return PageView.builder(
            controller: _pageController,
            itemCount: _maxCameras,
            itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.all(4),
                child: _buildCameraTile(index)));
      case CameraViewMode.grid2x2:
        crossAxisCount = 2;
        break;
      case CameraViewMode.grid3x3:
        crossAxisCount = 3;
        break;
    }

    final int itemsPerPage = crossAxisCount * crossAxisCount;
    final int pageCount = (_maxCameras / itemsPerPage).ceil();

    return PageView.builder(
      controller: _pageController,
      itemCount: pageCount,
      itemBuilder: (context, pageIndex) {
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: (pageIndex == pageCount - 1)
              ? _maxCameras - (pageIndex * itemsPerPage)
              : itemsPerPage,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder: (context, gridItemIndex) {
            final cameraIndex = (pageIndex * itemsPerPage) + gridItemIndex;
            return _buildCameraTile(cameraIndex);
          },
        );
      },
    );
  }

  Widget _buildCameraTile(int index) {
    final hasUrl = _cameraUrls[index] != null;
    final videoCtrl = _videoControllers[index];
    final isLoading = _isInitializing[index];
    final hasError = _hasError[index];

    Widget content;

    if (!hasUrl) {
      content = _buildPlaceholder(index);
    } else if (hasError) {
      content = _buildError(index);
    } else if (isLoading || videoCtrl == null) {
      content = _buildLoading(index);
    } else if (!videoCtrl.value.isInitialized) {
      content = _buildLoading(index);
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoCtrl.value.size.width,
            height: videoCtrl.value.size.height,
            child: VideoPlayer(videoCtrl),
          ),
        ),
      );
    }

    return Card(
      key: ValueKey('camera_tile_$index'),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showAddCameraDialog(index),
        onDoubleTap: hasUrl ? () => _onCameraTap(index) : null,
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: Stack(
            children: [
              content,
              // Canlı gösterge
              if (hasUrl &&
                  !hasError &&
                  !isLoading &&
                  videoCtrl != null &&
                  videoCtrl.value.isInitialized)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'CANLI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildLoading(int index) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.teal),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text('Kamera ${index + 1}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Bağlanıyor...',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError(int index) {
    final errorMsg = _errorMessages[index] ?? 'Bağlantı hatası';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 42),
            const SizedBox(height: 12),
            Text('Kamera ${index + 1}',
                style: TextStyle(
                    color: Colors.red.shade200,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final url = _cameraUrls[index];
                    if (url != null) {
                      _initializeCamera(index, url);
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tekrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddCameraDialog(index),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Ayarlar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(int index) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(MdiIcons.cctvOff, color: Colors.teal.shade200, size: 48),
          const SizedBox(height: 12),
          Text('Kamera ${index + 1}',
              style: TextStyle(
                  color: Colors.teal.shade100,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('URL Eklemek İçin Dokunun',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildViewModeButton() {
    IconData icon;
    String tooltip;
    switch (_currentViewMode) {
      case CameraViewMode.fullScreenSwipe:
        icon = MdiIcons.gridOff;
        tooltip = 'Tam Ekran Kaydırmalı Görünüm';
        break;
      case CameraViewMode.grid2x2:
        icon = MdiIcons.gridLarge;
        tooltip = '2x2 Izgara Görünüm';
        break;
      case CameraViewMode.grid3x3:
        icon = MdiIcons.grid;
        tooltip = '3x3 Izgara Görünüm';
        break;
    }
    return _buildAppBarAction(icon, tooltip, Colors.white, _cycleViewMode);
  }

  Widget _buildAppBarAction(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 26, color: color),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
      ),
    );
  }

  // --- STİLİZE EDİLMİŞ DİYALOG WIDGET'LARI ---

  Widget _buildStyledTextField(
      {required TextEditingController controller,
      required String labelText,
      required IconData icon}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
            color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 26, color: Colors.grey[700]),
        border: _getTextFieldBorder(),
        enabledBorder: _getTextFieldBorder(),
        focusedBorder: _getTextFieldBorder(color: Colors.teal.shade600),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  OutlineInputBorder _getTextFieldBorder({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color ?? Colors.grey[300]!, width: 2),
    );
  }

  ButtonStyle _getButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      elevation: 4,
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
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.8), iconColor]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(icon, size: 58, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 20),
            ...content,
            const SizedBox(height: 28),
            Row(children: actions),
          ]),
        ),
      ),
    );
  }
}
