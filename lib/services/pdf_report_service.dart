import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
  pw.MemoryImage? logoImage;

  // Tasarım Renk Paleti (Modern Executive SaaS Stili)
  static const primaryNavy = PdfColor.fromInt(0xFF0F172A); // Slate 900
  static const primarySlate = PdfColor.fromInt(0xFF1E293B); // Slate 800
  static const brandTeal = PdfColor.fromInt(0xFF0D9488); // Teal 600
  static const brandTealLight = PdfColor.fromInt(0xFFF0FDFA); // Teal 50
  static const brandTealBorder = PdfColor.fromInt(0xFF99F6E4); // Teal 200
  static const surfaceLight = PdfColor.fromInt(0xFFF8FAFC); // Slate 50
  static const surfaceBorder = PdfColor.fromInt(0xFFE2E8F0); // Slate 200
  static const textPrimary = PdfColor.fromInt(0xFF0F172A);
  static const textSecondary = PdfColor.fromInt(0xFF475569);
  static const textMuted = PdfColor.fromInt(0xFF94A3B8);
  static const accentGreen = PdfColor.fromInt(0xFF059669); // Emerald 600
  static const accentGreenLight = PdfColor.fromInt(0xFFECFDF5); // Emerald 50
  static const accentAmber = PdfColor.fromInt(0xFFD97706); // Amber 600
  static const accentAmberLight = PdfColor.fromInt(0xFFFFFBEB); // Amber 50
  static const accentBlue = PdfColor.fromInt(0xFF2563EB); // Blue 600

  // HATA AYIKLAMA: Bu fonksiyon, NaN veya Infinity değerlerini varsayılan bir değere (0.0) dönüştürür.
  double _safeDouble(num? value, {double defaultValue = 0.0}) {
    if (value == null || value.isNaN || value.isInfinite) {
      return defaultValue;
    }
    return value.toDouble();
  }

  Future<void> _loadFonts() async {
    if (ttf == null) {
      try {
        final fontData =
            await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
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

    if (logoImage == null) {
      try {
        final logoData = await rootBundle.load("assets/gastrofy.png");
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (e) {
        debugPrint("Logo yüklenemedi: $e");
      }
    }
  }

  pw.ThemeData _getTheme() {
    return pw.ThemeData.withFont(
      base: ttf ?? pw.Font.helvetica(),
      bold: ttfBold ?? pw.Font.helveticaBold(),
      italic: ttfItalic ?? pw.Font.helveticaOblique(),
      boldItalic: ttfBoldItalic ?? pw.Font.helveticaBoldOblique(),
    );
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        build: (context) => _buildReportContent(
            data, dateFormat, currencyFormat, shortDateFormat),
        footer: _buildFooter,
      ),
    );

    return _saveDocument(pdf, reportName: "Gastrofy_Ciro_Raporu");
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        build: (context) {
          List<pw.Widget> content = [];

          // Başlık
          content.add(_buildHeader(data, dateFormat, isEndOfDay: true));
          content.add(pw.SizedBox(height: 16));

          // Yönetici Özet Kartları
          content.add(_buildExecutiveSummaryCards(data, currencyFormat,
              isEndOfDay: true, recordCount: todaysRecords.length));
          content.add(pw.SizedBox(height: 22));

          // Masa Kayıtları Başlığı
          content.add(_buildSectionHeader(
            'Günün Kapanan Masa Kayıtları',
            subtitle: 'Bugün hesap kapatan masaların detay dökümü',
            badgeText: '${todaysRecords.length} Adet',
          ));
          content.add(pw.SizedBox(height: 10));
          content.add(_buildTodaysRecordsTable(
              todaysRecords, currencyFormat, timeFormat));

          if (data.topProducts.isNotEmpty) {
            content.add(pw.SizedBox(height: 24));
            content.add(_buildSectionHeader(
              'En Çok Satan Ürünler',
              subtitle: 'Günün en çok talep gören lezzetleri',
              badgeText: '${data.topProducts.length} Ürün',
            ));
            content.add(pw.SizedBox(height: 10));
            content.add(_buildTopProductsTable(data));
          }

          return content;
        },
        footer: _buildFooter,
      ),
    );

    return _saveDocument(pdf, reportName: "Gastrofy_Gun_Sonu_Raporu");
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
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);
      final page = await document.getPage(1);
      final double renderHeight = (page.width > 0 && !page.width.isNaN)
          ? (300 * page.height / page.width)
          : 400.0;
      final pageImage = await page.render(
        width: 300,
        height: renderHeight.isNaN ? 400 : renderHeight,
        format: pdfx.PdfPageImageFormat.png,
      );

      await page.close();
      await document.close();

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

  List<pw.Widget> _buildReportContent(ReportData data, DateFormat dateFormat,
      NumberFormat currencyFormat, DateFormat shortDateFormat) {
    List<pw.Widget> content = [];

    // 1. Kurumsal Başlık
    content.add(_buildHeader(data, dateFormat));
    content.add(pw.SizedBox(height: 16));

    // 2. Yönetici KPI Özet Kartları
    content.add(_buildExecutiveSummaryCards(data, currencyFormat));
    content.add(pw.SizedBox(height: 22));

    // 3. Grafikler (Varsa)
    final bool hasRevenues =
        data.dailyRevenues.values.any((v) => _safeDouble(v) > 0);
    final bool hasProducts =
        data.topProducts.any((p) => _safeDouble(p.salesCount) > 0);

    if (hasRevenues || hasProducts) {
      content.add(_buildCharts(
          data, shortDateFormat, currencyFormat, dateFormat));
      content.add(pw.SizedBox(height: 22));
    }

    // 4. Günlük Ciro Dökümü
    content.add(_buildSectionHeader(
      'Günlük Ciro Dökümü',
      subtitle: 'Dönem içindeki tarih bazlı ciro dağılımı',
    ));
    content.add(pw.SizedBox(height: 10));
    content.add(_buildDailyRevenueTable(data, dateFormat, currencyFormat));
    content.add(pw.SizedBox(height: 22));

    // 5. En Çok Satan Ürünler Tablosu
    content.add(_buildSectionHeader(
      'En Çok Satan Ürünler',
      subtitle: 'Dönem boyunca masalardan en çok sipariş edilen ürünler',
      badgeText: data.topProducts.isNotEmpty
          ? '${data.topProducts.length} Kalem'
          : null,
    ));
    content.add(pw.SizedBox(height: 10));
    content.add(_buildTopProductsTable(data));

    return content;
  }

  // --- ÜST BAŞLIK (HEADER) ---
  pw.Widget _buildHeader(ReportData data, DateFormat dateFormat,
      {bool isEndOfDay = false}) {
    final reportCode =
        'GM-RPR-${DateFormat('yyyyMMdd').format(data.endDate)}';
    final reportTitle =
        isEndOfDay ? 'GÜN SONU KAPANIK RAPORU' : 'CİRO & PERFORMANS RAPORU';
    final reportSubtitle = isEndOfDay
        ? 'İşletme Günlük Kapanış ve Masa Hareket Analizi'
        : 'İşletme Zekası, Satış ve Ciro Analiz Raporu';

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: surfaceBorder, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Sol: Logo & Marka Adı
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 44,
                  height: 44,
                  margin: const pw.EdgeInsets.only(right: 12),
                  decoration: pw.BoxDecoration(
                    color: surfaceLight,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: surfaceBorder, width: 1),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
                  ),
                ),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'GASTROFY',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryNavy,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: brandTealLight,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(
                              color: brandTealBorder, width: 0.8),
                        ),
                        child: pw.Text(
                          reportTitle,
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: brandTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    reportSubtitle,
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Sağ: Dönem ve Rapor Meta Kartı
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: surfaceLight,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: surfaceBorder, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  isEndOfDay
                      ? 'Rapor Tarihi: ${dateFormat.format(data.endDate)}'
                      : 'Dönem: ${dateFormat.format(data.startDate)} - ${dateFormat.format(data.endDate)}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: primarySlate,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Yazdırılma: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 7, color: textMuted),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Belge Kodu: $reportCode',
                  style: const pw.TextStyle(fontSize: 6.5, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- YÖNETİCİ KPI ÖZET KARTLARI ---
  pw.Widget _buildExecutiveSummaryCards(
      ReportData data, NumberFormat currencyFormat,
      {bool isEndOfDay = false, int recordCount = 0}) {
    final double totalRevenue = _safeDouble(data.totalRevenue);
    final activeEntries = data.dailyRevenues.entries
        .where((e) => _safeDouble(e.value) > 0)
        .toList();
    final int activeDays = activeEntries.length;
    final int totalDays = max(
        data.endDate.difference(data.startDate).inDays + 1, 1);
    final double dailyAverage =
        activeDays > 0 ? (totalRevenue / activeDays) : 0.0;

    final maxRevenueEntry = activeEntries.isEmpty
        ? null
        : activeEntries.reduce((a, b) => a.value > b.value ? a : b);

    final topProduct =
        data.topProducts.isNotEmpty ? data.topProducts.first : null;

    return pw.Row(
      children: [
        // 1. Toplam Ciro Kartı (Vurgulu)
        pw.Expanded(
          child: _buildKpiCard(
            topBarColor: brandTeal,
            title: 'TOPLAM CİRO',
            value: currencyFormat.format(totalRevenue),
            subtext: isEndOfDay ? 'Günün Toplam Cirosu' : 'Dönem Toplam Geliri',
            valueColor: brandTeal,
            highlightBackground: true,
          ),
        ),
        pw.SizedBox(width: 8),

        // 2. Aktif Satış / Masa Sayısı
        pw.Expanded(
          child: _buildKpiCard(
            topBarColor: accentBlue,
            title: isEndOfDay ? 'KAPANAN MASA' : 'SATIŞ YAPILAN GÜN',
            value: isEndOfDay ? '$recordCount Masa' : '$activeDays Gün',
            subtext: isEndOfDay
                ? 'Hesabı kapatılan masa'
                : '$totalDays günlük dönem içinde',
            valueColor: primaryNavy,
          ),
        ),
        pw.SizedBox(width: 8),

        // 3. Günlük Ortalama / Masa Başı Ortalama
        pw.Expanded(
          child: _buildKpiCard(
            topBarColor: accentGreen,
            title: isEndOfDay ? 'MASA BAŞI ORTALAMA' : 'GÜNLÜK ORTALAMA',
            value: currencyFormat.format(isEndOfDay
                ? (recordCount > 0 ? totalRevenue / recordCount : 0.0)
                : dailyAverage),
            subtext: isEndOfDay
                ? 'Masa başı ortalama gelir'
                : 'Satış olan günler ortalaması',
            valueColor: primaryNavy,
          ),
        ),
        pw.SizedBox(width: 8),

        // 4. Lider Ürün / Zirve Satış
        pw.Expanded(
          child: _buildKpiCard(
            topBarColor: accentAmber,
            title: isEndOfDay ? 'LİDER ÜRÜN' : 'EN ÇOK SATAN KALEM',
            value: topProduct != null ? topProduct.name : (maxRevenueEntry != null ? DateFormat('dd/MM').format(DateTime.parse(maxRevenueEntry.key)) : '-'),
            subtext: topProduct != null
                ? '${topProduct.salesCount} Adet Satıldı'
                : (maxRevenueEntry != null ? 'En yüksek cirolu gün' : 'Kayıt bulunmuyor'),
            valueColor: primarySlate,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildKpiCard({
    required PdfColor topBarColor,
    required String title,
    required String value,
    required String subtext,
    required PdfColor valueColor,
    bool highlightBackground = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: highlightBackground ? brandTealLight : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
            color: highlightBackground ? brandTealBorder : surfaceBorder,
            width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Container(
                width: 12,
                height: 3,
                decoration: pw.BoxDecoration(
                  color: topBarColor,
                  borderRadius: pw.BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtext,
            maxLines: 1,
            style: const pw.TextStyle(fontSize: 6.5, color: textSecondary),
          ),
        ],
      ),
    );
  }

  // --- BÖLÜM BAŞLIĞI BİLEŞENİ ---
  pw.Widget _buildSectionHeader(String title,
      {String? subtitle, String? badgeText}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 3.5,
              height: 14,
              decoration: pw.BoxDecoration(
                color: brandTeal,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
                if (subtitle != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                        fontSize: 7.5, color: textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
        if (badgeText != null) ...[
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: pw.BoxDecoration(
              color: surfaceLight,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: surfaceBorder, width: 0.8),
            ),
            child: pw.Text(
              badgeText,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- GRAFİKLER BÖLÜMÜ ---
  pw.Widget _buildCharts(ReportData data, DateFormat shortDateFormat,
      NumberFormat currencyFormat, DateFormat dateFormat) {
    final hasRevenues =
        data.dailyRevenues.values.any((v) => _safeDouble(v) > 0);
    final hasProducts =
        data.topProducts.any((p) => _safeDouble(p.salesCount) > 0);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (hasRevenues) ...[
          _buildSectionHeader(
            'Dönemsel Ciro Trendi',
            subtitle: 'Günlük ciro değişim grafiği',
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: surfaceBorder, width: 1),
            ),
            child: _buildBarChart(
                data, shortDateFormat, currencyFormat, dateFormat),
          ),
        ],
        if (hasProducts) ...[
          pw.SizedBox(height: 18),
          _buildSectionHeader(
            'Ürün Satış Dağılımı',
            subtitle: 'En çok satan ürünlerin satış payları',
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: surfaceBorder, width: 1),
            ),
            child: _buildPieChart(data),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildBarChart(ReportData data, DateFormat shortDateFormat,
      NumberFormat currencyFormat, DateFormat dateFormat) {
    final chartData = data.dailyRevenues.entries
        .where((e) => _safeDouble(e.value) > 0)
        .toList();

    if (chartData.isEmpty) return pw.SizedBox();

    final revenues = chartData.map((e) => _safeDouble(e.value)).toList();
    if (revenues.isEmpty) return pw.SizedBox();

    final maxRevenue = revenues.reduce(max);
    final double topValue =
        max(_safeDouble(maxRevenue * 1.2, defaultValue: 1.0), 1.0);
    final yAxisValues =
        List<double>.generate(6, (i) => _safeDouble(i * (topValue / 5)));

    final bool isSingleBar = chartData.length == 1;

    // Tek veri noktasında 0'a bölme (NaN) olmaması için sol ve sağ boşluk eklenir.
    final List<String> xStrings = isSingleBar
        ? ['', shortDateFormat.format(DateTime.parse(chartData[0].key)), ' ']
        : chartData
            .map((e) => shortDateFormat.format(DateTime.parse(e.key)))
            .toList();

    final List<pw.PointChartValue> barData = isSingleBar
        ? [pw.PointChartValue(1.0, _safeDouble(chartData[0].value))]
        : List<pw.PointChartValue>.generate(
            chartData.length,
            (i) {
              final entry = chartData[i];
              return pw.PointChartValue(
                  _safeDouble(i.toDouble()), _safeDouble(entry.value));
            },
          );

    return pw.Column(
      children: [
        pw.Container(
          height: 155,
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis.fromStrings(
                xStrings,
                textStyle: const pw.TextStyle(fontSize: 7.5, color: textSecondary),
                ticks: true,
              ),
              yAxis: pw.FixedAxis(
                yAxisValues,
                format: (v) {
                  final safeV = _safeDouble(v);
                  return currencyFormat.format(safeV);
                },
                textStyle:
                    const pw.TextStyle(fontSize: 7.5, color: textSecondary),
              ),
            ),
            datasets: [
              pw.BarDataSet(
                width: isSingleBar ? 26 : 14,
                color: brandTeal,
                data: barData,
              ),
            ],
          ),
        ),
        if (isSingleBar) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: brandTealLight,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: brandTealBorder, width: 0.8),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Bilgi: Seçilen aralıkta yalnızca ${dateFormat.format(DateTime.parse(chartData[0].key))} tarihinde ${currencyFormat.format(chartData[0].value)} ciro gerçekleşmiştir.',
                  style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: brandTeal),
                ),
              ],
            ),
          ),
        ],
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
      PdfColor.fromInt(0xFF0D9488), // Teal
      PdfColor.fromInt(0xFF2563EB), // Blue
      PdfColor.fromInt(0xFFD97706), // Amber
      PdfColor.fromInt(0xFF7C3AED), // Purple
      PdfColor.fromInt(0xFFE11D48), // Rose
      PdfColor.fromInt(0xFF64748B), // Slate Grey
    ];

    List<pw.Widget> legends = [];
    List<pw.PieDataSet> datasets = [];

    for (int i = 0; i < top5.length; i++) {
      final product = top5[i];
      final salesCount = _safeDouble(product.salesCount);
      final percentage =
          totalSales > 0 ? (salesCount / totalSales * 100) : 0.0;

      legends.add(_buildLegend(
        color: colors[i],
        productName: product.name,
        count: salesCount.toInt(),
        percentage: percentage,
      ));
      datasets.add(pw.PieDataSet(value: salesCount, color: colors[i]));
    }

    if (otherSales > 0) {
      final percentage =
          totalSales > 0 ? (otherSales / totalSales * 100) : 0.0;
      legends.add(_buildLegend(
        color: colors[5],
        productName: 'Diğer Ürünler',
        count: otherSales.toInt(),
        percentage: percentage,
      ));
      datasets.add(pw.PieDataSet(value: otherSales, color: colors[5]));
    }

    if (datasets.isEmpty) return pw.SizedBox();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            height: 140,
            child: pw.Chart(grid: pw.PieGrid(), datasets: datasets),
          ),
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

  pw.Widget _buildLegend({
    required PdfColor color,
    required String productName,
    required int count,
    required double percentage,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 9,
                height: 9,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(2.5),
                ),
              ),
              pw.SizedBox(width: 7),
              pw.Text(
                productName,
                style: const pw.TextStyle(fontSize: 8, color: textPrimary),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Text(
                '$count Adet',
                style: const pw.TextStyle(fontSize: 8, color: textSecondary),
              ),
              pw.SizedBox(width: 6),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: pw.BoxDecoration(
                  color: surfaceLight,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: surfaceBorder, width: 0.6),
                ),
                child: pw.Text(
                  '%${percentage.toStringAsFixed(1)}',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primarySlate,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- GÜNLÜK CİRO DÖKÜMÜ TABLOSU ---
  pw.Widget _buildDailyRevenueTable(
      ReportData data, DateFormat dateFormat, NumberFormat currencyFormat) {
    final double totalRevenue = _safeDouble(data.totalRevenue);
    final activeEntries = data.dailyRevenues.entries
        .where((entry) => _safeDouble(entry.value) > 0)
        .toList();

    if (activeEntries.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: surfaceLight,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: surfaceBorder),
        ),
        child: pw.Text(
          'Bu tarih aralığında kaydedilmiş ciro verisi bulunamadı.',
          style: pw.TextStyle(fontSize: 8.5, color: textMuted, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    final headers = ['Tarih', 'Ciro Tutarı', 'Dönem İçi Payı (%)'];
    final tableData = activeEntries.map((entry) {
      final double val = _safeDouble(entry.value);
      final double share = totalRevenue > 0 ? (val / totalRevenue * 100) : 0.0;
      return [
        dateFormat.format(DateTime.parse(entry.key)),
        currencyFormat.format(val),
        '%${share.toStringAsFixed(1)}',
      ];
    }).toList();

    // Toplam Satırı Ekleniyor
    tableData.add([
      'TOPLAM CİRO',
      currencyFormat.format(totalRevenue),
      '%100,0',
    ]);

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      headerStyle: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: primaryNavy,
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {0: pw.Alignment.centerLeft},
      cellStyle: const pw.TextStyle(fontSize: 8, color: textPrimary),
      border: pw.TableBorder.all(color: surfaceBorder, width: 0.5),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    );
  }

  // --- EN ÇOK SATAN ÜRÜNLER TABLOSU ---
  pw.Widget _buildTopProductsTable(ReportData data) {
    final validProducts = data.topProducts
        .where((p) => _safeDouble(p.salesCount) > 0)
        .toList();

    if (validProducts.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: surfaceLight,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: surfaceBorder),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              'Bilgi: Bu dönemde doğrudan ürün detayıyla kapanan masa kaydı bulunmuyor.',
              style: pw.TextStyle(
                fontSize: 8,
                color: textSecondary,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final double totalCount = validProducts.fold<double>(
        0.0, (sum, p) => sum + _safeDouble(p.salesCount));

    final headers = ['Sıra', 'Ürün Adı', 'Satış Adedi', 'Adet Payı (%)'];
    final tableData = validProducts.asMap().entries.map((entry) {
      int idx = entry.key;
      var product = entry.value;
      final double count = _safeDouble(product.salesCount);
      final double share = totalCount > 0 ? (count / totalCount * 100) : 0.0;
      return [
        '#${idx + 1}',
        product.name,
        count.toInt().toString(),
        '%${share.toStringAsFixed(1)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      headerStyle: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: primarySlate,
      ),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 8, color: textPrimary),
      border: pw.TableBorder.all(color: surfaceBorder, width: 0.5),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    );
  }

  // --- GÜNÜN KAPANAN MASALARI TABLOSU (GÜN SONU İÇİN) ---
  pw.Widget _buildTodaysRecordsTable(List<TableRecordModel> records,
      NumberFormat currencyFormat, DateFormat timeFormat) {
    if (records.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: surfaceLight,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: surfaceBorder),
        ),
        child: pw.Text(
          'Bugün kapatılan masa kaydı bulunamadı.',
          style: pw.TextStyle(fontSize: 8.5, color: textMuted, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    final headers = ['Masa Adı', 'Açılış Saati', 'Süre (Dk)', 'Tahsil Edilen'];
    final tableData = records.map((record) {
      return [
        record.tableName,
        timeFormat.format(record.startTime),
        '${record.duration.inMinutes} dk',
        currencyFormat.format(_safeDouble(record.totalPrice)),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      headerStyle: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: primaryNavy),
      border: pw.TableBorder.all(color: surfaceBorder, width: 0.5),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 8, color: textPrimary),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    );
  }

  // --- SAYFA ALTLIĞI (FOOTER) ---
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Gastrofy™ Masa Takip & Restoran Yönetim Sistemi • Gizli & İşletmeye Özeldir',
            style: const pw.TextStyle(fontSize: 7, color: textMuted),
          ),
          pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: textSecondary,
            ),
          ),
        ],
      ),
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
