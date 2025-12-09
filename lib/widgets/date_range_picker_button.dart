import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Kullanıcının bir tarih aralığı seçmesini sağlayan özel bir butondur.
class DateRangePickerButton extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final Function(DateTime startDate, DateTime endDate) onDateRangeSelected;

  const DateRangePickerButton({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeSelected,
    this.title = 'Tarih Aralığı Seç',
  });

  /// Takvim açma işlevi
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTime now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      // Varsayılan olarak seçili olan aralık
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      // İlk açılışta 1 yıl öncesini göster
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now, // Bugünden sonrası seçilemez
      helpText: 'Rapor Tarih Aralığı',
      cancelText: 'İptal',
      confirmText: 'Onayla',
      saveText: 'Kaydet',
      fieldStartHintText: 'Başlangıç Tarihi',
      fieldEndHintText: 'Bitiş Tarihi',
    );

    if (picked != null) {
      // Seçim yapıldıysa, callback fonksiyonunu tetikle
      onDateRangeSelected(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seçilen tarih aralığını okunaklı formatta göster
    final String formattedRange =
        '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _selectDateRange(context),
        icon: const Icon(Icons.calendar_today, size: 20),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                formattedRange,
                style:
                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
