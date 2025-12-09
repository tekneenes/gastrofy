import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'dart:convert'; // jsonDecode için
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

// Sürüm bilgilerini tutmak için bir model
class UpdateInfo {
  final String version;
  final String title;
  final List<String> releaseNotes;
  final DateTime releaseDate;
  final bool isMajorUpdate;

  // YENİ: İndirme URL'sini burada tutacağız
  final String downloadUrl;

  UpdateInfo({
    required this.version,
    required this.title,
    required this.releaseNotes,
    required this.releaseDate,
    required this.downloadUrl, // Eklendi
    this.isMajorUpdate = false,
  });
}

class UpdateScreen extends StatefulWidget {
  final String currentVersion;
  const UpdateScreen({super.key, required this.currentVersion});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<UpdateInfo> _availableUpdates = [];

  // İndirme durumu
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = "";
  bool _updateComplete = false;
  Timer? _downloadTimer;
  UpdateInfo? _currentUpdate;

  // Uyarı ikonu animasyonu
  late AnimationController _warningIconController;

  @override
  void initState() {
    super.initState();
    _warningIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _fetchGitHubUpdates();
  }

  @override
  void dispose() {
    _downloadTimer?.cancel();
    _warningIconController.dispose();
    super.dispose();
  }

  // Sahte güncelleme verilerini çeken fonksiyon
  // Sahte güncelleme verilerini çeken fonksiyon
  Future<void> _fetchGitHubUpdates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Mevcut yüklü sürümü al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;
      final currentVersion = Version.parse(currentVersionStr);

      // 2. GitHub API URL (Doğru API adresi)
      const String githubOwner = "tekneenes";
      const String githubRepo = "masatakip";

      // LİSTE olarak çekmek için 'releases' kullanıyoruz
      final url = Uri.parse(
          'https://api.github.com/repos/$githubOwner/$githubRepo/releases');

      // 3. İSTEK (Headers güncellendi)
      final response = await http.get(
        url,
        headers: {
          // GitHub'ın zorunlu kıldığı başlıklar:
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'MasaTakip-App', // Burası boş olamaz
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );

      if (response.statusCode == 200) {
        final releases = jsonDecode(response.body) as List;
        final List<UpdateInfo> updates = [];

        for (var release in releases) {
          if (release['draft'] == true || release['prerelease'] == true) {
            continue;
          }

          final tagName = (release['tag_name'] as String).replaceAll('v', '');

          // Tag isimlendirmesinde hata olursa uygulamayı çökertmesin diye try-catch
          try {
            final releaseVersion = Version.parse(tagName);

            if (releaseVersion > currentVersion) {
              final assets = release['assets'] as List;
              // APK dosyasını bul (büyük/küçük harf duyarlılığını kaldırıyoruz)
              final apkAsset = assets.firstWhere(
                (asset) =>
                    (asset['name'] as String).toLowerCase().endsWith('.apk'),
                orElse: () => null,
              );

              if (apkAsset == null) continue;

              final String downloadUrl = apkAsset['browser_download_url'];
              final String body = release['body'] ?? "Sürüm notu bulunmuyor.";
              final List<String> releaseNotes = body
                  .split('\n')
                  .where((line) => line.trim().isNotEmpty)
                  .map((line) => line.replaceAll('* ', '').trim())
                  .toList();

              updates.add(UpdateInfo(
                version: tagName,
                title: release['name'] ?? 'Yeni Sürüm',
                releaseNotes: releaseNotes,
                releaseDate: DateTime.parse(release['published_at']),
                downloadUrl: downloadUrl,
                isMajorUpdate: releaseVersion.major > currentVersion.major,
              ));
            }
          } catch (e) {
            print("Versiyon parse hatası ($tagName): $e");
            continue; // Bu sürümü atla, diğerine geç
          }
        }

        setState(() {
          _availableUpdates = updates;
          _isLoading = false;
        });
      } else {
        // Hata detayını konsola basalım
        print('GitHub API Hatası Body: ${response.body}');
        throw Exception('GitHub API Hatası. Kod: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print("Genel Hata: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme hatası: $e')),
        );
      }
    }
  }

  // Güncellemeyi başlatma (Uyarı gösterme)
  void _startUpdate(UpdateInfo update) {
    _showUpdateWarningDialog(update);
  }

  // İsteğiniz üzerine animasyonlu uyarı diyalogu
  void _showUpdateWarningDialog(UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animasyonlu Uyarı İkonu
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0)
                      .animate(_warningIconController),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade600,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Dikkat!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Şu an güncellemek istediğinize emin misiniz? Kaydedilmemiş değişiklikler kaybolabilir.\n\nBu güncelleme, kaydedilmemiş değişiklikleri korumayı taahhüt etmez.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("İptal",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadUpdate(update);
                        },
                        child: const Text("Devam Et"),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // İndirme ve yükleme (GERÇEK)
  void _downloadUpdate(UpdateInfo update) async {
    setState(() {
      _isDownloading = true;
      _updateComplete = false;
      _downloadProgress = 0.0; // Başlangıçta null (belirsiz) yapabiliriz
      _downloadStatus = "Güncelleme indiriliyor: v${update.version}";
      _currentUpdate = update;
    });

    // 1. Dosyanın kaydedileceği yeri bul
    // getTemporaryDirectory() veya getApplicationSupportDirectory() kullanabilirsiniz
    final Directory tempDir = await getTemporaryDirectory();
    final String savePath =
        '${tempDir.path}/app-release-v${update.version}.apk';

    // Dio'yu oluştur
    final Dio dio = Dio();

    try {
      // 2. 'dio.download' ile dosyayı indir
      await dio.download(
        update.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Gerçek indirme yüzdesini ayarla
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      // 3. İndirme bitti, yüklemeye geç
      _installUpdate(savePath);
    } catch (e) {
      // İndirme hatası
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        print("İndirme hatası: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme indirilemedi: $e')),
        );
      }
    }
  }

  // Yükleme (GERÇEK)
  void _installUpdate(String apkPath) async {
    setState(() {
      _downloadStatus = "Güncelleme doğrulanıyor ve yükleniyor...";
      // Yükleme aslında anlık tetiklenir, bekleme süresi simülasyonunu kaldırıyoruz
    });

    // 'open_file' paketi ile Android Yükleyici'yi tetikle
    final result = await OpenFile.open(apkPath);

    if (result.type == ResultType.done) {
      // Yükleyici açıldı
      setState(() {
        _updateComplete = true;
        _downloadStatus =
            "Güncelleme başarıyla yüklendi: v${_currentUpdate!.version}";
      });
      // Kullanıcı yüklemeyi tamamladıktan sonra buradaki
      // "Uygulamayı Kapat" butonu anlamlı hale gelir.
    } else {
      // Hata: Dosya açılamadı veya izin yok
      if (mounted) {
        setState(() {
          _isDownloading = false; // İndirme ekranına geri dön
        });
        print("Yükleyici açılamadı: ${result.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleyici başlatılamadı: ${result.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Yazılım Güncelleme"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentVersionCard(),
            const SizedBox(height: 24),
            Text(
              "Mevcut Güncellemeler",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildBodyContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentVersionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.security_update_good_rounded,
                color: Colors.teal.shade600, size: 30),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mevcut Sürüm",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "v${widget.currentVersion}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Güncellemeler kontrol ediliyor..."),
            ],
          ),
        ),
      );
    }

    if (_isDownloading) {
      return _buildDownloadProgress();
    }

    if (_availableUpdates.isEmpty) {
      return _buildNoUpdatesCard();
    }

    // Güncellemeleri listele (önce büyük olan)
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _availableUpdates.length,
      itemBuilder: (context, index) {
        // Listeyi tersine çevirerek en yeni sürümü (3.0.0) üste al
        final update = _availableUpdates.reversed.toList()[index];
        return _buildUpdateCard(update);
      },
    );
  }

  Widget _buildNoUpdatesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: Colors.green.shade600, size: 56),
          const SizedBox(height: 16),
          const Text(
            "Sisteminiz Güncel",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni bir güncelleme bulunmamaktadır.",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard(UpdateInfo update) {
    Color themeColor =
        update.isMajorUpdate ? Colors.blue.shade700 : Colors.orange.shade800;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  update.isMajorUpdate
                      ? Icons.rocket_launch_rounded
                      : Icons.new_releases_rounded,
                  color: themeColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: themeColor.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Sürüm v${update.version}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sürüm Notları
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Sürüm Notları:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                ...update.releaseNotes.map((note) => _buildReleaseNote(note)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_for_offline_rounded,
                        color: Colors.white),
                    label: const Text("İndir ve Yükle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _startUpdate(update),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseNote(String note) {
    IconData icon;
    Color color;

    if (note.toLowerCase().startsWith("yeni:")) {
      icon = Icons.add_circle_outline_rounded;
      color = Colors.green.shade600;
    } else if (note.toLowerCase().startsWith("düzeltme:")) {
      icon = Icons.bug_report_outlined;
      color = Colors.red.shade600;
    } else if (note.toLowerCase().startsWith("iyileştirme:")) {
      icon = Icons.auto_awesome_rounded;
      color = Colors.blue.shade600;
    } else {
      icon = Icons.arrow_right_rounded;
      color = Colors.grey.shade700;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF333333), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    Color themeColor = _currentUpdate?.isMajorUpdate == true
        ? Colors.blue.shade700
        : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (!_updateComplete)
            CircularProgressIndicator(
              value: _downloadProgress < 0.02 ? null : _downloadProgress,
              strokeWidth: 6,
              backgroundColor: themeColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            )
          else
            Icon(Icons.check_circle_rounded,
                color: Colors.green.shade600, size: 56),
          const SizedBox(height: 20),
          Text(
            _downloadStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          if (!_updateComplete)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 12,
                    backgroundColor: themeColor.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "%${(_downloadProgress * 100).toStringAsFixed(0)}",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeColor),
                ),
              ],
            )
          else
            _buildRestartMessage(),
        ],
      ),
    );
  }

  Widget _buildRestartMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade600),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.yellow.shade800, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Yeniden Başlatma Gerekli",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Güncellemenin tamamlanması için lütfen uygulamadan çıkın, arka plandan silin ve uygulamayı yeniden başlatın.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.yellow.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
              label: const Text("Uygulamayı Kapat"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Bu komut uygulamayı tamamen kapatır.
                SystemNavigator.pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
