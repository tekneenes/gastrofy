import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/table_model.dart';
import '../providers/table_provider.dart';
import 'package:provider/provider.dart';
// Uygulamanızdaki gerekli import'lar
// import '../models/table_model.dart';
// import '../providers/table_provider.dart';

// Gerekli Enum ve Modellerin Tanımlaması (Eğer uygulama kodu yoksa bu varsayılır)
// enum TableViewMode { list, gridSmall, gridLarge }
// class TableModel {
//   final String id;
//   final String name;
//   final bool isOccupied;
//   final DateTime? startTime;
//   final double totalRevenue;
//   TableModel({required this.id, required this.name, required this.isOccupied, this.startTime, this.totalRevenue = 0.0});
// }
// class TableProvider with ChangeNotifier {}

class TableCard extends StatefulWidget {
  final TableModel table;
  final TableViewMode viewMode;
  final VoidCallback? onMoreOptionsPressed;
  final VoidCallback? onCardTapped;

  const TableCard({
    super.key,
    required this.table,
    required this.viewMode,
    this.onMoreOptionsPressed,
    this.onCardTapped,
  });

  @override
  State<TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<TableCard> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  // 🎨 Renk Paleti Tanımlamaları
  static final Color occupiedAccent = Colors.deepOrange.shade600;
  static final Color occupiedLight = Colors.deepOrange.shade50;
  static final Color freeAccent = Colors.teal.shade500;
  static final Color freeLight = Colors.white; // Boş masalar için temiz beyaz

  @override
  void initState() {
    super.initState();
    _startOrUpdateTimer();
  }

  @override
  void didUpdateWidget(covariant TableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.table.isOccupied != oldWidget.table.isOccupied ||
        widget.table.startTime != oldWidget.table.startTime) {
      _startOrUpdateTimer();
    }
  }

  void _startOrUpdateTimer() {
    _timer?.cancel();

    if (widget.table.isOccupied && widget.table.startTime != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final startTime = widget.table.startTime;
        if (startTime == null || !widget.table.isOccupied) {
          timer.cancel();
          if (mounted) {
            setState(() => _elapsedTime = Duration.zero);
          }
          return;
        }

        final newElapsedTime = DateTime.now().difference(startTime);
        if (mounted) {
          setState(() => _elapsedTime = newElapsedTime);
        }
      });

      // İlk değeri hemen hesapla
      if (mounted) {
        _elapsedTime = DateTime.now().difference(widget.table.startTime!);
      }
    } else {
      // Masa boş ise timer'ı durdur ve süreyi sıfırla
      if (mounted) {
        setState(() => _elapsedTime = Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return "00:00:00";
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isOccupied = widget.table.isOccupied;

    // Kartın ana hatları ve animasyonu
    return Card(
      key: ValueKey(widget.table.id),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      // Dolu masalar için gölgeyi daha belirgin yap
      elevation: isOccupied ? 8 : 3,
      shadowColor: isOccupied
          ? occupiedAccent.withOpacity(0.4)
          : Colors.grey.withOpacity(0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onCardTapped,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          // İçeriği viewMode'a göre oluştur
          child: widget.viewMode == TableViewMode.list
              ? _buildListViewContent()
              : _buildGridViewContent(),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  //                           LİSTE GÖRÜNÜMÜ
  // -----------------------------------------------------------------
  Widget _buildListViewContent() {
    final bool isOccupied = widget.table.isOccupied;
    final Color accentColor = isOccupied ? occupiedAccent : freeAccent;
    final String statusText = isOccupied ? 'Dolu' : 'Boş';

    return Container(
      decoration: BoxDecoration(
        color: isOccupied ? occupiedLight : freeLight,
        // Durumu hızlıca anlamak için sol tarafta kalın renkli sınır
        border: Border(
          left: BorderSide(
            color: accentColor.withOpacity(0.8),
            width: 8,
          ),
        ),
      ),
      height: 90, // Liste öğeleri için sabit yükseklik
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            // 1. Durum İkonu
            Icon(
              isOccupied
                  ? Icons.group_outlined
                  : Icons.event_available_outlined,
              color: accentColor,
              size: 30,
            ),
            const SizedBox(width: 16),
            // 2. Masa Adı ve Durumu (Ortalanmış)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.table.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.blueGrey.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Durum Çipi
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Süre/Ciro ve Aksiyon (Sağ Taraf)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isOccupied)
                    // Dolu ise Süre
                    _buildMetaText(
                      label: 'Süre',
                      value: _formatDuration(_elapsedTime),
                      color: Colors.blueGrey.shade700,
                    )
                  else
                    // Boş ise Toplam Ciro
                    _buildMetaText(
                      label: 'Toplam Ciro',
                      value: NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                          .format(widget.table.totalRevenue),
                      color: Colors.grey.shade600,
                    ),
                  const SizedBox(height: 4),
                  if (isOccupied)
                    // Dolu ise Mevcut Ciro
                    _buildMetaText(
                      label: 'Ciro',
                      value: NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                          .format(widget.table.totalRevenue),
                      color: Colors.green.shade700,
                    ),
                ],
              ),
            ),

            // 4. Seçenekler Butonu (En Sağda)
            if (widget.onMoreOptionsPressed != null)
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey.shade500,
                ),
                onPressed: widget.onMoreOptionsPressed,
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  //                           GRID GÖRÜNÜMÜ
  // -----------------------------------------------------------------
  Widget _buildGridViewContent() {
    final bool isOccupied = widget.table.isOccupied;
    final Color accentColor = isOccupied ? occupiedAccent : freeAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      // Dolu masalar için Gradient ve Koyu Tema
      decoration: BoxDecoration(
        color: isOccupied ? Colors.blueGrey.shade900 : freeLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Üst Kısım: Aksiyon ve İkon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Durum İkonu
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? Colors.white.withOpacity(0.2) // Koyu temada beyaz çip
                      : accentColor.withOpacity(0.1), // Açık temada renkli çip
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOccupied ? Icons.access_time : Icons.clean_hands,
                  color: isOccupied ? Colors.white : accentColor,
                  size: 20,
                ),
              ),
              // Seçenekler Butonu (Köşede)
              if (widget.onMoreOptionsPressed != null)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isOccupied
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey.shade500,
                    ),
                    onPressed: widget.onMoreOptionsPressed,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),

          // 2. Masa Adı (Merkezde)
          Expanded(
            child: Center(
              child: Text(
                widget.table.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isOccupied ? Colors.white : Colors.blueGrey.shade900,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 3. Alt Kısım: Detaylar
          if (isOccupied)
            // DOLU MASA: Süre ve Ciro (Beyaz üzerine)
            Column(
              children: [
                _buildGridDetailRow(
                  label: 'Geçen Süre',
                  value: _formatDuration(_elapsedTime),
                  isOccupied: true,
                  valueColor: Colors.white,
                ),
                const SizedBox(height: 4),
                _buildGridDetailRow(
                  label: 'Mevcut Ciro',
                  value: NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                      .format(widget.table.totalRevenue),
                  isOccupied: true,
                  valueColor: Colors.greenAccent,
                ),
              ],
            )
          else
            // BOŞ MASA: Toplam Ciro (Açık üzerine)
            _buildGridDetailRow(
              label: 'Toplam Ciro',
              value: NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                  .format(widget.table.totalRevenue),
              isOccupied: false,
              valueColor: Colors.green.shade700,
            ),
        ],
      ),
    );
  }

  // Yeniden Kullanılabilir Meta Text Widget'ı (List Görünümü için)
  Widget _buildMetaText({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Yeniden Kullanılabilir Detay Row Widget'ı (Grid Görünümü için)
  Widget _buildGridDetailRow({
    required String label,
    required String value,
    required bool isOccupied,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isOccupied
                ? Colors.white.withOpacity(0.7)
                : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
