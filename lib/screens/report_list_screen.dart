import 'dart:io';
import 'dart:math'; // YENİ: Dosya boyutu formatlaması için eklendi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_viewer_screen.dart'; // Bu dosyanın var olduğunu varsayıyoruz

// GÜNCELLENDİ: Dosya boyutunu da tutan model
class ReportListItem {
  final File pdfFile;
  final File? thumbnailFile;
  final int? fileSizeInBytes; // HATA DÜZELTMESİ: Nullable (int?) yapıldı

  ReportListItem({
    required this.pdfFile,
    this.thumbnailFile,
    required this.fileSizeInBytes, // YENİ
  });
}

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  late Future<List<ReportListItem>> _reportItems;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    _reportItems = _loadReports();
  }

  // GÜNCELLENDİ: Artık PDF'leri, önizlemeleri ve dosya boyutlarını yüklüyor
  Future<List<ReportListItem>> _loadReports() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();

    final pdfs = files
        .where((file) => file.path.endsWith('.pdf'))
        .map((file) => File(file.path))
        .toList();

    // En yeni raporun en üstte olması için sırala
    pdfs.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    List<ReportListItem> items = [];
    for (var pdfFile in pdfs) {
      final thumbnailPath =
          '${pdfFile.path.replaceAll('.pdf', '')}-thumbnail.png';
      final thumbnailFile = File(thumbnailPath);

      int? fileSize; // HATA DÜZELTMESİ: Nullable yapıldı
      try {
        fileSize = pdfFile.lengthSync(); // YENİ: Dosya boyutu alındı
      } catch (e) {
        // Dosya bir şekilde silinirse veya okunamıyorsa
        fileSize = 0;
      }

      items.add(ReportListItem(
        pdfFile: pdfFile,
        thumbnailFile: await thumbnailFile.exists() ? thumbnailFile : null,
        fileSizeInBytes: fileSize, // YENİ: Modele eklendi
      ));
    }
    return items;
  }

  // YENİ: Bayt'ı KB, MB, GB olarak formatlayan yardımcı fonksiyon
  String _formatBytes(int? bytes, int decimals) {
    // HATA DÜZELTMESİ: Nullable int (int?) kabul et
    if (bytes == null || bytes <= 0)
      return "0 B"; // HATA DÜZELTMESİ: Null kontrolü eklendi
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void _refreshList() {
    setState(() {
      _reportItems = _loadReports();
    });
  }

  // GÜNCELLENDİ: Silme fonksiyonu iki parçaya ayrıldı (Dismissible için)

  // 1. Parça: Sadece onay dialog'unu gösterir ve sonucu (true/false) döner
  Future<bool> _showDeleteConfirmDialog(ReportListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Raporu Sil'),
        content: Text(
            '${item.pdfFile.path.split('/').last} adlı rapor ve önizlemesi silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return confirm ?? false; // Kullanıcı dialog dışına basarsa null gelir
  }

  // 2. Parça: Asıl silme işlemini yapar ve SnackBar gösterir
  Future<void> _performDelete(ReportListItem item) async {
    try {
      await item.pdfFile.delete();
      if (item.thumbnailFile != null && await item.thumbnailFile!.exists()) {
        await item.thumbnailFile!.delete();
      }

      // Not: `onDismissed` içindeyiz, liste zaten
      // kendini güncelleyecektir. Yeniden _loadReports çağırmak
      // en temiz yöntemdir.
      _refreshList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Rapor silindi.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Rapor silinirken hata oluştu: $e'),
              backgroundColor: Colors.red),
        );
      }
      // Hata durumunda listeyi eski haline getirmek için yenile
      _refreshList();
    }
  }

  // ReportScreen'den alınan AppBar butonu stili
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

  // ReportScreen'den alınan stil ile uyumlu boş sayfa tasarımı
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.find_in_page_outlined,
              size: 64,
              color: Colors.deepPurple.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Kayıt Bulunamadı',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz oluşturulmuş bir raporunuz yok.\nRapor panosundan yeni bir PDF oluşturabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // ReportScreen ile aynı
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Oluşturulan Raporlar',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
              fontSize: 24),
        ),
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          _buildAppBarAction(
            MdiIcons.fileRefreshOutline,
            'Listeyi Yenile',
            Colors.deepPurple.shade400,
            _refreshList,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ReportListItem>>(
        future: _reportItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
              color: Colors.deepPurple.shade400,
            ));
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Hata oluştu: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade400)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final fileName = item.pdfFile.path.split('/').last;
              final modifiedDate = item.pdfFile.lastModifiedSync();
              final isEndOfDayReport = fileName.contains("Gun_Sonu_Raporu");

              // YENİ: Dosya boyutu formatlandı
              final fileSize = _formatBytes(item.fileSizeInBytes, 1);

              // YENİ: Kaydırarak silmek için Dismissible eklendi
              return Dismissible(
                key: ValueKey(item.pdfFile.path), // Benzersiz bir anahtar
                direction: DismissDirection.endToStart, // Sadece sağdan sola

                // Silmeden önce onayı göster
                confirmDismiss: (direction) => _showDeleteConfirmDialog(item),

                // Onay verilirse silme işlemini yap
                onDismissed: (direction) => _performDelete(item),

                // Kaydırma arka planı
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  margin: const EdgeInsets.only(bottom: 12), // Card ile aynı
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16), // Card ile aynı
                  ),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: Colors.white, size: 30),
                ),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: item.thumbnailFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.file(
                              item.thumbnailFile!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Icon(Icons.picture_as_pdf_rounded,
                                color: Colors.red.shade600, size: 30),
                          ),
                    title: Text(
                      isEndOfDayReport ? "Gün Sonu Raporu" : "Detaylı Rapor",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),

                    // GÜNCELLENDİ: Subtitle artık 2 satırlı (Tarih ve Dosya Boyutu)
                    subtitle: Text(
                      'Oluşturma: ${DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(modifiedDate)}\nDosya Boyutu: $fileSize',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.4, // Satır aralığı için eklendi
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PdfViewerScreen(file: item.pdfFile),
                        ),
                      );
                    },
                    // KALDIRILDI: Silme ikonu, yerini Dismissible aldı
                    // trailing: IconButton( ... ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
