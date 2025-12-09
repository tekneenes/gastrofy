import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import '../models/product_model.dart';
import '../models/category_model.dart';
import '../screens/html_preview_screen.dart'; // Önizleme ekranı

// Varsayılan HTML Şablonu
const String defaultMenuTemplate = r'''
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{MENU_TITLE}}</title>
    <style>
        body { font-family: 'Arial', sans-serif; margin: 30px; background-color: #f4f4f9; color: #333; }
        .menu-container { max-width: 800px; margin: 0 auto; padding: 20px; background-color: #fff; border-radius: 15px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; border-bottom: 3px solid #673AB7; padding-bottom: 10px; }
        .header h1 { color: #673AB7; font-size: 36px; margin: 0; }
        .header p { color: #555; margin-top: 5px; font-style: italic; }
        .category { margin-top: 35px; border-left: 5px solid #FF9800; padding-left: 15px; }
        .category h2 { color: #FF9800; font-size: 24px; margin-bottom: 15px; padding: 5px 0; }
        .item { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px dotted #ccc; }
        .item:last-child { border-bottom: none; }
        .item-name { font-weight: bold; flex-grow: 1; font-size: 16px;}
        .item-price { font-weight: bold; color: #4CAF50; font-size: 18px; margin-left: 20px; }
    </style>
</head>
<body>
    <div class="menu-container">
        <div class="header">
            <h1>{{MENU_TITLE}}</h1>
            <p>Fiyatlar {{DATE_PLACEHOLDER}} itibarıyla geçerlidir.</p>
        </div>
        
        <!-- Dinamik İçerik: Varsayılan şablonda tüm kategori ve ürünler buraya listelenir. -->
    </div>
</body>
</html>
''';

class MenuGeneratorService {
  // HTML Şablonundaki yer tutucuları gerçek ürün verileriyle değiştiren mantık
  String generateMenuHtml(String template, List<ProductModel> products,
      List<CategoryModel> categories) {
    String html = template;
    final now = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());
    final trFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    // Genel yer tutucuları değiştir
    html = html.replaceAll('{{DATE_PLACEHOLDER}}', now);
    html = html.replaceAll('{{MENU_TITLE}}', 'Güncel Menü Listesi');

    // 1. Ürün bazlı yer tutucuları (PRODUCT_NAME_[ID], PRODUCT_PRICE_[ID]) değiştirme
    // Bu kısım, kullanıcının kendi şablonunu yüklemesi durumunda çalışır.
    for (var product in products) {
      final namePlaceholder = '{{PRODUCT_NAME_${product.id}}}';
      final pricePlaceholder = '{{PRODUCT_PRICE_${product.id}}}';
      final formattedPrice = trFormat.format(product.price);

      // Şablon içindeki tüm yer tutucuları değiştir
      html = html.replaceAll(namePlaceholder, product.name);
      html = html.replaceAll(pricePlaceholder, formattedPrice);
    }

    // 2. Varsayılan şablon için dinamik kategori/ürün listesini oluşturma
    if (template == defaultMenuTemplate) {
      final Map<String, List<ProductModel>> productsByCategory = {};
      for (var product in products) {
        final categoryName = categories
            .firstWhere(
              (c) => c.id == product.categoryId,
              orElse: () => CategoryModel(id: '', name: 'Kategorisiz'),
            )
            .name;
        if (!productsByCategory.containsKey(categoryName)) {
          productsByCategory[categoryName] = [];
        }
        productsByCategory[categoryName]!.add(product);
      }

      final sortedCategoryNames = productsByCategory.keys.toList()..sort();
      final StringBuffer menuContentBuffer = StringBuffer();

      for (var categoryName in sortedCategoryNames) {
        menuContentBuffer.writeln('<div class="category">');
        menuContentBuffer.writeln('<h2>$categoryName</h2>');

        for (var product in productsByCategory[categoryName]!) {
          final formattedPrice = trFormat.format(product.price);
          menuContentBuffer.writeln('<div class="item">');
          menuContentBuffer
              .writeln('<span class="item-name">${product.name}</span>');
          menuContentBuffer
              .writeln('<span class="item-price">$formattedPrice</span>');
          menuContentBuffer.writeln('</div>');
        }
        menuContentBuffer.writeln('</div>');
      }

      // Dinamik içeriği, ana container'ın sonuna ekliyoruz.
      // Not: Daha gelişmiş bir sistemde, HTML içinde özel bir DIV'i hedeflemek gerekir.
      final containerEndIndex = html.lastIndexOf('</div>\n</body>');
      if (containerEndIndex != -1) {
        // Dinamik içeriği eklerken, varsayılan şablonda beklediğimiz yer tutucuyu silmiyoruz,
        // çünkü varsayılan şablonun bu içeriği kapsayan bir yapısı var.
        // Ancak burada, içeriği 'menu-container' divinin hemen içine ekliyoruz.
        html = html.substring(0, html.lastIndexOf('</div>\n</body>')) +
            menuContentBuffer.toString() +
            '</div>\n</body>\n</html>';
      }
    }

    // Eğer şablon hala doldurulmamış yer tutucular içeriyorsa (kullanıcı hatalı ID kullandıysa), onları temizleyelim
    html = html.replaceAll(
        RegExp(r'\{\{PRODUCT_NAME_[^}]*\}\}'), 'Ürün Adı [YOK]');
    html =
        html.replaceAll(RegExp(r'\{\{PRODUCT_PRICE_[^}]*\}\}'), 'Fiyat [YOK]');

    return html;
  }

  // Özel HTML dosyasını yüklemeyi simüle eder
  Future<String?> loadCustomTemplate() async {
    // Simülasyon: defaultMenuTemplate içeriğini döndürerek başarılı bir yükleme taklit edilir.
    await Future.delayed(const Duration(milliseconds: 500));
    return defaultMenuTemplate;
  }

  // PDF'i oluşturur ve görüntüleme ekranını başlatır
  Future<void> exportToPdfAndPreview(
      BuildContext context, String htmlContent) async {
    // Gerçek bir uygulamada burada printing kütüphanesi kullanılır ve HTML PDF'e çevrilirdi.
    // final pdf = await Printing.convertHtml(html: htmlContent, format: PdfPageFormat.a4);
    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => PdfViewerScreen(pdfData: pdf)));

    // Simülasyon: HTML içeriğini doğrudan PDF önizleme ekranı olarak tasarlanan
    // HtmlPreviewScreen'e göndeririz.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HtmlPreviewScreen(htmlContent: htmlContent),
      ),
    );
  }
}
