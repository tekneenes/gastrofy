import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'pdf_report_service.dart';
import '../models/table_record_model.dart';
import '../models/top_product.dart';

// Arka plan görevlerinin adını merkezi bir yerden yönetmek için
const String _dailyReportTaskName = "generateDailyReport";

class BackgroundTaskService {
  static String get dailyReportTaskName => _dailyReportTaskName;

  /// Gün sonu raporu oluşturma işlemini arka planda çalıştırır
  static Future<void> executeReportGeneration() async {
    print("Executing background report generation...");
    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final allRecentRecordsMaps = await db.getClosedOrdersLastSixMonths();
      if (allRecentRecordsMaps.isEmpty) {
        print("Background: No records found in the last six months.");
        return;
      }

      final allRecentRecords = allRecentRecordsMaps
          .map((map) => TableRecordModel.fromSqliteMap(map))
          .toList();

      final todaysRecords = allRecentRecords.where((record) {
        return record.startTime.isAfter(startOfDay);
      }).toList();

      if (todaysRecords.isEmpty) {
        print("Background: Bugün için raporlanacak kayıt bulunamadı.");
        return; // Kayıt yoksa rapor oluşturma.
      }

      final double totalRevenue =
          todaysRecords.fold(0.0, (sum, record) => sum + record.totalPrice);

      final Map<String, int> productSales = {};
      for (var record in todaysRecords) {
        for (var item in record.items) {
          productSales.update(
              item.productName, (value) => value + item.quantity,
              ifAbsent: () => item.quantity);
        }
      }
      final sortedProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final List<TopProduct> topProducts = sortedProducts.map((entry) {
        return TopProduct(name: entry.key, salesCount: entry.value);
      }).toList();

      final Map<String, double> dailyRevenues = {
        DateFormat('yyyy-MM-dd').format(now): totalRevenue
      };

      final reportData = ReportData(
        startDate: startOfDay,
        endDate: now,
        totalRevenue: totalRevenue,
        dailyRevenues: dailyRevenues,
        topProducts: topProducts,
      );

      final pdfService = PdfReportService();
      await pdfService.generateEndOfDayReport(reportData, todaysRecords);

      print("Background: Report generated successfully.");
    } catch (e) {
      print("Background task executeReportGeneration error: $e");
    }
  }
}
