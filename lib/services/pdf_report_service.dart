import 'dart:io';
import 'dart:math';
import 'dart:ui'; // ImageByteFormat için gerekli, ancak pdfx kendi formatını kullanır
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// pdf_render kaldırıldı, yerine pdfx eklendi
import 'package:pdfx/pdfx.dart' as pdfx;
import '../models/top_product.dart';
import '../models/table_record_model.dart';

class PdfReportResult {
  final File pdfFile;
  final File? thumbnailFile;

  PdfReportResult({required this.pdfFile, this.thumbnailFile});
}

class ReportData {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final Map<String, double> dailyRevenues;
  final List<TopProduct> topProducts;

  ReportData({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.dailyRevenues,
    required this.topProducts,
  });
}

class PdfReportService {
  pw.Font? ttf;
  pw.Font? ttfBold;
  pw.Font? ttfItalic;
  pw.Font? ttfBoldItalic;

  // HATA AYIKLAMA: Bu fonksiyon, NaN veya Infinity değerlerini varsayılan bir değere (0.0) dönüştürür.
  double _safeDouble(num? value, {double defaultValue = 0.0}) {
    if (value == null || value.isNaN || value.isInfinite) {
      return defaultValue;
    }
    return value.toDouble();
  }

  Future<void> _loadFonts() async {
    if (ttf != null) return;
    try {
      // Font yolları projenizdeki assets klasörüne uygun olmalıdır.
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final fontDataBold =
          await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
      final fontDataItalic =
          await rootBundle.load("assets/fonts/Roboto-Italic.ttf");
      final fontDataBoldItalic =
          await rootBundle.load("assets/fonts/Roboto-BoldItalic.ttf");

      ttf = pw.Font.ttf(fontData);
      ttfBold = pw.Font.ttf(fontDataBold);
      ttfItalic = pw.Font.ttf(fontDataItalic);
      ttfBoldItalic = pw.Font.ttf(fontDataBoldItalic);
    } catch (e) {
      debugPrint("Fontlar yüklenemedi: $e");
    }
  }

  Future<PdfReportResult> generateReport(ReportData data) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _getTheme());
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
    final shortDateFormat = DateFormat('dd/MM');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => _buildReportContent(
            data, dateFormat, currencyFormat, shortDateFormat),
        footer: _buildFooter,
      ),
    );

    return _saveDocument(pdf, reportName: "Rapor");
  }

  Future<PdfReportResult> generateEndOfDayReport(
      ReportData data, List<TableRecordModel> todaysRecords) async {
    await _loadFonts();
    final pdf = pw.Document(theme: _getTheme());
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
    final timeFormat = DateFormat('HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          List<pw.Widget> content = [];

          content.add(pw.Header(
            level: 0,
            text: 'Gün Sonu Raporu',
            textStyle:
                pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ));
          content.add(pw.Text(
            'Rapor Tarihi: ${dateFormat.format(data.endDate)}',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ));
          content.add(pw.Divider(height: 20));

          content.add(_buildSummary(data, currencyFormat));
          content.add(pw.SizedBox(height: 30));

          content.add(pw.Header(
            level: 1,
            text: 'Günün Kapanan Masa Kayıtları (${todaysRecords.length} adet)',
            textStyle:
                pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ));
          content.add(pw.SizedBox(height: 10));
          content.add(_buildTodaysRecordsTable(
              todaysRecords, currencyFormat, timeFormat));

          if (data.topProducts.isNotEmpty) {
            content.add(pw.SizedBox(height: 30));
            content.add(pw.Header(
              level: 1,
              text: 'En Çok Satan Ürünler',
              textStyle:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ));
            content.add(pw.SizedBox(height: 10));
            content.add(_buildTopProductsTable(data));
          }

          return content;
        },
        footer: _buildFooter,
      ),
    );

    return _saveDocument(pdf, reportName: "Gun_Sonu_Raporu");
  }

  Future<PdfReportResult> _saveDocument(pw.Document pdf,
      {required String reportName}) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${reportName}_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}';

    final pdfFile = File('${dir.path}/$fileName.pdf');
    await pdfFile.writeAsBytes(bytes);

    File? thumbnailFile;
    try {
      // --- PDFX KULLANARAK THUMBNAIL OLUŞTURMA ---

      // 1. Dosyayı pdfx ile aç
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);

      // 2. İlk sayfayı al (Sayfa indeksi 1'den başlar)
      final page = await document.getPage(1);

      // 3. Sayfayı render et
      // pdfx render metodu doğrudan bir PdfPageImage döner
      final pageImage = await page.render(
        width: 300,
        height: 300 * page.height / page.width, // Oranı koru
        format: pdfx.PdfPageImageFormat.png, // Formatı belirle
      );

      // 4. Kaynakları serbest bırak (Önemli!)
      await page.close();
      await document.close();

      // 5. Dosyaya yaz
      if (pageImage != null) {
        final thumbnailPath = '${dir.path}/$fileName-thumbnail.png';
        thumbnailFile = File(thumbnailPath);
        await thumbnailFile.writeAsBytes(pageImage.bytes);
      }
    } catch (e) {
      debugPrint("PDF thumbnail oluşturulurken hata: $e");
      thumbnailFile = null;
    }

    return PdfReportResult(pdfFile: pdfFile, thumbnailFile: thumbnailFile);
  }

  pw.ThemeData _getTheme() {
    return pw.ThemeData.withFont(
      base: ttf!,
      bold: ttfBold!,
      italic: ttfItalic!,
      boldItalic: ttfBoldItalic!,
    );
  }

  List<pw.Widget> _buildReportContent(ReportData data, DateFormat dateFormat,
      NumberFormat currencyFormat, DateFormat shortDateFormat) {
    List<pw.Widget> content = [];

    content.add(_buildHeader(data, dateFormat));
    content.add(pw.SizedBox(height: 20));
    content.add(_buildSummary(data, currencyFormat));
    content.add(pw.SizedBox(height: 30));

    // *** KARARLI ÇÖZÜM: Raporun tek günlük olup olmadığını kontrol et ***
    final bool isSingleDayReport = data.startDate.year == data.endDate.year &&
        data.startDate.month == data.endDate.month &&
        data.startDate.day == data.endDate.day;

    // Grafikleri yalnızca veri varsa VE "tek günlük" rapor değilse çiz.
    // Bu, "bugün" seçildiğinde oluşan NaN hatasını engeller.
    if (!isSingleDayReport &&
        (data.dailyRevenues.values.any((v) => _safeDouble(v) > 0) ||
            data.topProducts.any((p) => _safeDouble(p.salesCount) > 0))) {
      content.add(_buildCharts(data, shortDateFormat, currencyFormat));
    } else if (isSingleDayReport &&
        (data.dailyRevenues.values.any((v) => _safeDouble(v) > 0) ||
            data.topProducts.any((p) => _safeDouble(p.salesCount) > 0))) {
      // Tek günlük raporsa ve veri varsa, grafik yerine bilgilendirme mesajı göster
      content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'Not: Ayrıntılı grafikler, birden fazla günü kapsayan raporlarda (ör: "Bu Hafta") gösterilir.',
            style: pw.TextStyle(
                fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
          )));
    }

    content
        .add(pw.SizedBox(height: 20)); // Mesaj ile tablo arasına boşluk eklendi
    content.add(pw.Header(
      level: 0,
      text: 'Günlük Ciro Dökümü',
      textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    ));
    content.add(pw.SizedBox(height: 10));
    content.add(_buildDailyRevenueTable(data, dateFormat, currencyFormat));
    content.add(pw.SizedBox(height: 30));
    content.add(pw.Header(
      level: 0,
      text: 'En Çok Satan Ürünler',
      textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    ));
    content.add(pw.SizedBox(height: 10));
    content.add(_buildTopProductsTable(data));

    return content;
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
      child: pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _buildTodaysRecordsTable(List<TableRecordModel> records,
      NumberFormat currencyFormat, DateFormat timeFormat) {
    if (records.isEmpty) {
      return pw.Text(
        'Bugün kapatılan masa kaydı bulunamadı.',
        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
      );
    }

    final headers = ['Masa Adı', 'Giriş Saati', 'Süre (dk)', 'Toplam Tutar'];
    final tableData = records.map((record) {
      return [
        record.tableName,
        timeFormat.format(record.startTime),
        record.duration.inMinutes.toString(),
        currencyFormat.format(_safeDouble(record.totalPrice)),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      border: pw.TableBorder.all(color: PdfColors.grey400),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildCharts(ReportData data, DateFormat shortDateFormat,
      NumberFormat currencyFormat) {
    return pw.Column(
      children: [
        if (data.dailyRevenues.values.any((v) => _safeDouble(v) > 0)) ...[
          pw.Text('Günlük Ciro Trendi',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Container(
            height: 200,
            child: _buildBarChart(data, shortDateFormat, currencyFormat),
          ),
          pw.SizedBox(height: 40),
        ],
        if (data.topProducts.any((p) => _safeDouble(p.salesCount) > 0)) ...[
          pw.Text('Ürün Satış Dağılımı',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Container(
            height: 220,
            child: _buildPieChart(data),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildBarChart(ReportData data, DateFormat shortDateFormat,
      NumberFormat currencyFormat) {
    final chartData = data.dailyRevenues.entries
        .where((e) => _safeDouble(e.value) > 0)
        .toList();

    // Guard 1: Filtrelenmiş veri var mı?
    if (chartData.isEmpty) return pw.SizedBox();

    final revenues = chartData.map((e) => _safeDouble(e.value)).toList();

    // Guard 2: 'reduce' hatasını engellemek için.
    if (revenues.isEmpty) return pw.SizedBox();

    final maxRevenue = revenues.reduce(max); // Artık %100 güvenli olmalı

    final double topValue =
        max(_safeDouble(maxRevenue * 1.2, defaultValue: 1.0), 1.0);

    final yAxisValues =
        List<double>.generate(6, (i) => _safeDouble(i * (topValue / 5)));

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          chartData
              .map((e) => shortDateFormat.format(DateTime.parse(e.key)))
              .toList(),
          textStyle: const pw.TextStyle(fontSize: 8),
          ticks: true,
        ),
        yAxis: pw.FixedAxis(
          yAxisValues,
          format: (v) {
            final safeV = _safeDouble(v);
            return currencyFormat.format(safeV);
          },
          textStyle: const pw.TextStyle(fontSize: 8),
        ),
      ),
      datasets: [
        pw.BarDataSet(
          width: 15,
          color: PdfColors.blue,
          data: List<pw.PointChartValue>.generate(
            chartData.length,
            (i) {
              final entry = chartData[i];
              return pw.PointChartValue(
                  _safeDouble(i.toDouble()), _safeDouble(entry.value));
            },
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPieChart(ReportData data) {
    final validProducts =
        data.topProducts.where((p) => _safeDouble(p.salesCount) > 0).toList();
    if (validProducts.isEmpty) return pw.SizedBox();

    final totalSales = validProducts.fold<double>(
        0.0, (sum, p) => sum + _safeDouble(p.salesCount));

    if (totalSales.isNaN || totalSales <= 0) return pw.SizedBox();

    final top5 = validProducts.take(5).toList();
    final otherSales = validProducts
        .skip(5)
        .fold<double>(0.0, (sum, p) => sum + _safeDouble(p.salesCount));

    final colors = [
      PdfColors.blue400,
      PdfColors.green400,
      PdfColors.amber400,
      PdfColors.purple400,
      PdfColors.red400,
      PdfColors.grey400
    ];

    List<pw.Widget> legends = [];
    List<pw.PieDataSet> datasets = [];

    for (int i = 0; i < top5.length; i++) {
      final product = top5[i];
      final salesCount = _safeDouble(product.salesCount);

      final percentage = totalSales > 0 ? (salesCount / totalSales * 100) : 0.0;

      legends.add(_buildLegend(
        color: colors[i],
        text: '${product.name} (${percentage.toStringAsFixed(1)}%)',
      ));
      datasets.add(pw.PieDataSet(value: salesCount, color: colors[i]));
    }

    if (otherSales > 0) {
      final percentage = totalSales > 0 ? (otherSales / totalSales * 100) : 0.0;
      legends.add(_buildLegend(
        color: colors[5],
        text: 'Diğer (${percentage.toStringAsFixed(1)}%)',
      ));
      datasets.add(pw.PieDataSet(value: otherSales, color: colors[5]));
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Chart(grid: pw.PieGrid(), datasets: datasets),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: legends,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLegend({required PdfColor color, required String text}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Container(width: 12, height: 12, color: color),
          pw.SizedBox(width: 8),
          pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(ReportData data, DateFormat dateFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Ciro ve Satış Raporu',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text(
          'Tarih Aralığı: ${dateFormat.format(data.startDate)} - ${dateFormat.format(data.endDate)}',
          style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
        ),
        pw.Divider(height: 20),
      ],
    );
  }

  pw.Widget _buildSummary(ReportData data, NumberFormat currencyFormat) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Toplam Ciro:',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                currencyFormat.format(_safeDouble(data.totalRevenue)),
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800),
              ),
            ]));
  }

  pw.Widget _buildDailyRevenueTable(
      ReportData data, DateFormat dateFormat, NumberFormat currencyFormat) {
    final headers = ['Tarih', 'Ciro'];
    final tableData = data.dailyRevenues.entries
        .where((entry) => _safeDouble(entry.value) > 0)
        .map((entry) => [
              dateFormat.format(DateTime.parse(entry.key)),
              currencyFormat.format(_safeDouble(entry.value)),
            ])
        .toList();

    if (tableData.isEmpty) {
      return pw.Text(
        'Bu tarih aralığında ciro verisi bulunamadı.',
        style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      border: pw.TableBorder.all(color: PdfColors.grey400),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {0: pw.Alignment.centerLeft},
    );
  }

  pw.Widget _buildTopProductsTable(ReportData data) {
    final headers = ['#', 'Ürün Adı', 'Satış Adedi'];
    final tableData = data.topProducts
        .asMap()
        .entries
        .where((entry) => _safeDouble(entry.value.salesCount) > 0)
        .map((entry) {
      int idx = entry.key;
      var product = entry.value;
      return [
        (idx + 1).toString(),
        product.name,
        _safeDouble(product.salesCount).toInt().toString(),
      ];
    }).toList();

    if (tableData.isEmpty) {
      return pw.Text('Bu tarih aralığında ürün satış verisi bulunamadı.',
          style: pw.TextStyle(fontStyle: pw.FontStyle.italic));
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      border: pw.TableBorder.all(color: PdfColors.grey400),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {1: pw.Alignment.centerLeft},
    );
  }

  void openPdfFile(BuildContext context, File file) async {
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF okuyucu bulunamadı: ${result.message}')),
      );
    }
  }
}
