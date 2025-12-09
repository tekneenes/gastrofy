import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback için eklendi
// import 'package:camera/camera.dart'; // KAMERA KAPATILDI
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'dart:ui'; // BackdropFilter için

// FaceMatcher sınıfı - Orijinal haliyle bırakıldı, ancak çağrılmıyor.
class FaceMatcher {
  static const _storageKey = 'face_hashes_v1';

  Future<Map<String, List<String>>> _readStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};
    final Map parsed = jsonDecode(raw);
    return parsed.map((k, v) => MapEntry(k as String, List<String>.from(v)));
  }

  Future<void> _writeStorage(Map<String, List<String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Uint8List _cropAndResizeFace(Uint8List imageBytes, Rect box,
      {int size = 64}) {
    final img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Image decode failed');

    int x = box.left.toInt().clamp(0, image.width - 1);
    int y = box.top.toInt().clamp(0, image.height - 1);
    int w = box.width.toInt().clamp(1, image.width - x);
    int h = box.height.toInt().clamp(1, image.height - y);

    final face = img.copyCrop(image, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(face, width: size, height: size);
    final gray = img.grayscale(resized);

    return Uint8List.fromList(img.encodePng(gray));
  }

  String _aHashFromGrayImage(img.Image gray) {
    final small = img.copyResize(gray,
        width: 8, height: 8, interpolation: img.Interpolation.average);

    int sum = 0;
    List<int> pixels = [];

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final pixel = small.getPixel(x, y);
        final int r = pixel.r.toInt();
        pixels.add(r);
        sum += r;
      }
    }

    final int avg = (sum / pixels.length).round();
    int hash = 0;
    for (int i = 0; i < pixels.length; i++) {
      if (pixels[i] >= avg) hash |= (1 << i);
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  int _hammingDistance(String hex1, String hex2) {
    final a = BigInt.parse(hex1, radix: 16);
    final b = BigInt.parse(hex2, radix: 16);
    final x = a ^ b;
    final bits = x.toRadixString(2);
    return bits.replaceAll('0', '').length;
  }

  Future<bool> registerFaceFromImage(
      Uint8List imageBytes, Face face, String name) async {
    // Fonksiyonlar devre dışı bırakıldığı için bu metodun içi artık çağrılmayacak.
    // Ancak mantığı ileride kullanmak üzere saklıyoruz.
    try {
      final cropped = _cropAndResizeFace(imageBytes, face.boundingBox);
      final img.Image gray = img.decodePng(cropped)!;
      final hash = _aHashFromGrayImage(gray);

      final storage = await _readStorage();
      final list = storage[name] ?? [];
      list.add(hash);
      storage[name] = list;
      await _writeStorage(storage);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> matchFaceFromImage(Uint8List imageBytes, Face face,
      {int threshold = 12}) async {
    // Fonksiyonlar devre dışı bırakıldığı için bu metodun içi artık çağrılmayacak.
    try {
      final cropped = _cropAndResizeFace(imageBytes, face.boundingBox);
      final img.Image gray = img.decodePng(cropped)!;
      final hash = _aHashFromGrayImage(gray);

      final storage = await _readStorage();
      String? bestName;
      int bestScore = 999;
      storage.forEach((name, hashes) {
        for (var h in hashes) {
          final d = _hammingDistance(hash, h);
          if (d < bestScore) {
            bestScore = d;
            bestName = name;
          }
        }
      });

      if (bestName != null && bestScore <= threshold) return bestName;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeUser(String name) async {
    final storage = await _readStorage();
    if (storage.containsKey(name)) {
      storage.remove(name);
      await _writeStorage(storage);
    }
  }

  Future<List<String>> listUsers() async {
    final storage = await _readStorage();
    return storage.keys.toList();
  }
}

class LoginSettingsScreen extends StatefulWidget {
  const LoginSettingsScreen({Key? key}) : super(key: key);

  @override
  State<LoginSettingsScreen> createState() => _LoginSettingsScreenState();
}

class _LoginSettingsScreenState extends State<LoginSettingsScreen> {
  // Orijinal değişkenler saklanıyor ancak UI'da aktif olarak kullanılmıyor.
  // final FaceMatcher _faceMatcher = FaceMatcher();
  // String _status = "Henüz işlem yapılmadı";
  // Uint8List? _imageBytes;
  // Face? _face;

  // Hiçbir fonksiyonun bir şey yapmasına gerek yok.
  // Butonlarda onPressed: null kullanılacak.

  // Future<void> _captureAndDetectFace() async {}
  // Future<void> _registerFace() async {}
  // Future<void> _matchFace() async {}
  // Future<void> _listUsers() async {}
  // Future<void> _removeUser() async {}

  @override
  Widget build(BuildContext context) {
    // Cihazın temasını al (açık/koyu)
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      // Arka plana yumuşak bir gradyan ekleyelim
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[850]!]
                : [Colors.blue.shade50, Colors.grey.shade50],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              centerTitle: true,
              // Geri dönme butonu için ikon rengini ayarla
              iconTheme: IconThemeData(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              title: Text(
                "Yüz Tanıma Ayarları",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // 1. Kamera Alanı Placeholder'ı
                    AspectRatio(
                      aspectRatio: 1.0, // Kare bir alan
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24.0),
                        child: Container(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.05),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.face_retouching_off_outlined,
                                  size: 100,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.black.withOpacity(0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Kamera Önizlemesi",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.black.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Bilgilendirme Kartı
                    _buildInfoCard(context, theme, isDarkMode),

                    const SizedBox(height: 24),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    const SizedBox(height: 24),

                    // 3. Devre Dışı Bırakılmış Butonlar
                    _buildDisabledButton(
                      context: context,
                      theme: theme,
                      isDarkMode: isDarkMode,
                      icon: Icons.camera_alt_outlined,
                      text: "Yüz Yakala",
                    ),
                    const SizedBox(height: 12),
                    _buildDisabledButton(
                      context: context,
                      theme: theme,
                      isDarkMode: isDarkMode,
                      icon: Icons.app_registration_rounded,
                      text: "Yüz Kaydet",
                    ),
                    const SizedBox(height: 12),
                    _buildDisabledButton(
                      context: context,
                      theme: theme,
                      isDarkMode: isDarkMode,
                      icon: Icons.login_rounded,
                      text: "Yüz Eşleştir (Giriş Yap)",
                    ),
                    const SizedBox(height: 12),
                    _buildDisabledButton(
                      context: context,
                      theme: theme,
                      isDarkMode: isDarkMode,
                      icon: Icons.list_alt_rounded,
                      text: "Kayıtlı Kullanıcılar",
                    ),
                    const SizedBox(height: 12),
                    _buildDisabledButton(
                      context: context,
                      theme: theme,
                      isDarkMode: isDarkMode,
                      icon: Icons.delete_outline_rounded,
                      text: "Kullanıcıyı Sil",
                      isDestructive: true, // Silme butonu için farklı renk
                    ),
                    const SizedBox(height: 20), // Ekstra boşluk
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bilgilendirme kartı için yardımcı widget
  Widget _buildInfoCard(
      BuildContext context, ThemeData theme, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.construction_rounded,
              color: isDarkMode ? Colors.amber.shade300 : Colors.amber.shade700,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Çok Yakında...",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Bu özellik şu anda aktif değil. Yüz tanıma ile giriş sistemimizi geliştirmeye devam ediyoruz.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Devre dışı butonlar için yardımcı widget
  Widget _buildDisabledButton({
    required BuildContext context,
    required ThemeData theme,
    required bool isDarkMode,
    required IconData icon,
    required String text,
    bool isDestructive = false,
  }) {
    // Devre dışı buton stili
    final style = ElevatedButton.styleFrom(
      foregroundColor: isDestructive
          ? (isDarkMode ? Colors.red.shade300 : Colors.red.shade700)
          : (isDarkMode ? Colors.white : Colors.black),
      backgroundColor: isDestructive
          ? (isDarkMode
              ? Colors.red.shade900.withOpacity(0.3)
              : Colors.red.shade50)
          : (isDarkMode ? Colors.grey[800] : Colors.white),
      disabledForegroundColor: (isDestructive
              ? (isDarkMode ? Colors.red.shade700 : Colors.red.shade300)
              : (isDarkMode ? Colors.grey[600] : Colors.grey[400]))!
          .withOpacity(0.5),
      disabledBackgroundColor: (isDestructive
              ? (isDarkMode ? Colors.red.shade900 : Colors.red.shade100)
              : (isDarkMode ? Colors.grey[800] : Colors.white))!
          .withOpacity(0.2),
      elevation: 0, // Devre dışı butonda gölge olmasın
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: (isDestructive
                  ? (isDarkMode ? Colors.red.shade800 : Colors.red.shade200)
                  : (isDarkMode ? Colors.grey[700] : Colors.grey[300]))!
              .withOpacity(0.5),
        ),
      ),
    );

    return ElevatedButton.icon(
      style: style,
      // ONEMLI: onPressed: null olarak ayarlandı, bu da butonu devre dışı bırakır.
      onPressed: () {
        // Tıklandığında hafif bir titreşim ver (opsiyonel, UX için)
        // HapticFeedback.lightImpact();
        // Ancak buton zaten null olduğu için bu da çalışmayacak.
        // Eğer çalışmasını isterseniz, boş bir fonksiyon () {} atayıp
        // içine HapticFeedback koyabilirsiniz ama buton "etkin" görünür.
        // En iyisi null bırakmak.
      },
      icon: Icon(icon, size: 22),
      label: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }
}
