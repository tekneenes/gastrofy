import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // YENİ: HapticFeedback için eklendi
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:printing/printing.dart';
// GÜNCELLENDİ: flutter_pdfview kaldırıldı, syncfusion eklendi (macOS desteği için)
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatelessWidget {
  final File file;

  const PdfViewerScreen({super.key, required this.file});

  // YENİ: Stil uyumluluğu için report_list_screen'den kopyalandı
  Widget _buildAppBarAction(
      IconData icon, String tooltip, Color color, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 26, color: color),
        style: IconButton.styleFrom(backgroundColor: Colors.transparent),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: Paylaşma fonksiyonunu AppBar'da daha temiz kullanmak için ayır
    final shareAction = () async {
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: file.path.split('/').last,
      );
    };

    return Scaffold(
      // YENİ: Arka plan rengi uyumlaştırıldı
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        // YENİ: Tüm AppBar stilleri report_list_screen'den alındı
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          file.path.split('/').last,
          // YENİ: Stil eklendi
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
            fontSize: 24,
          ),
          overflow: TextOverflow.ellipsis, // Uzun dosya adları için
        ),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E), // Geri butonu rengi
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          // YENİ: Buton, _buildAppBarAction stiline uyarlandı
          _buildAppBarAction(
            MdiIcons.exportVariant, // Daha yumuşak bir ikon
            'Raporu Paylaş',
            Colors.deepPurple.shade400, // Ana temayla aynı renk
            shareAction,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // GÜNCELLENDİ: macOS desteği için SfPdfViewer kullanıldı
      body: SfPdfViewer.file(
        file,
        // Opsiyonel: Görünümü iyileştirmek için
        canShowScrollHead: false,
        canShowScrollStatus: false,
      ),
    );
  }
}
