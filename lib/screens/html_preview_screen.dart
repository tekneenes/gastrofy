import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart'; // HTML içeriğini göstermek için.
import 'dart:ui' as ui; // Resim yakalama için
import 'dart:typed_data'; // Byte verisi için
import 'dart:io'; // Dosya işlemleri için
import 'package:path_provider/path_provider.dart'; // Geçici dosya yolu için
import 'package:share_plus/share_plus.dart'; // Paylaşım için
import 'dart:async'; // Asenkron işlemler için

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlContent;

  const HtmlPreviewScreen({super.key, required this.htmlContent});

  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  // Kaydırılabilir alanın tamamını (scroll dahil) yakalamak için GlobalKey
  // ScrollView'ın içinde RepaintBoundary kullanarak tüm içeriği yakalayacağız.
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // Ekran görüntüsünü alıp paylaşma mantığı
  Future<void> _exportScreenshot(BuildContext context) async {
    // 1. RepaintBoundary'nin RenderObject'unu bulma
    RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;

    // 2. Widget'ı bir resme dönüştürme
    ui.Image image = await boundary.toImage(
        pixelRatio: 3.0); // Yüksek çözünürlük için pixelRatio artırıldı
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hata: Ekran görüntüsü verisi boş.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Resim verisini (ByteData) File'a dönüştürme
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    try {
      // 4. Geçici bir dosya oluşturma
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/menu_screenshot.png').create();
      await file.writeAsBytes(pngBytes);

      // 5. Resmi paylaşma
      // share_plus kütüphanesi XFile gerektirir
      await Share.shareXFiles([XFile(file.path)],
          text: 'Restoran Menüsü Ekran Görüntüsü');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ekran görüntüsü dışa aktarıldı ve paylaşım menüsü açıldı.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hata durumunda kullanıcıyı bilgilendir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ekran Görüntüsü Dışa Aktarma Hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
      // print('Screenshot Export Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menü Önizleme',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        actions: [
          // Ekran Görüntüsü Olarak Dışa Aktar butonu
          IconButton(
            icon: const Icon(Icons
                .camera_alt), // Kamera simgesi ekran görüntüsünü temsil eder
            tooltip: 'Tüm Sayfayı Resim Olarak Dışa Aktar',
            onPressed: () => _exportScreenshot(context),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // TÜM SAYFAYI RepaintBoundary İLE SARMALIYORUZ
      body: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: SingleChildScrollView(
          // Ekran görüntüsü alırken SingleChildScrollView'ın arka plan renginin görünmesi için
          // bu Container'ı kullanıyoruz.
          child: Container(
            color: Colors.white, // Resim arka planı beyaz olmalı
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HTML içeriğini görüntüle
                Html(
                  data: widget.htmlContent,
                  // Gerekli stilleri burada tanımlayabilirsiniz
                  style: {
                    "body":
                        Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                    "h1": Style(color: Colors.deepPurple.shade600),
                    "h2": Style(color: Colors.orange.shade700),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
