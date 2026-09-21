import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/product_provider.dart';
import 'theme_preview_screen.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  void _openThemePreview(
      ProductProvider provider, String themeId, String themeName) {
    final slug = provider.companySlug;
    if (slug == null || slug.isEmpty) {
      _showSnackBar('Önizleme için önce bir Slug ID belirlemelisiniz.',
          isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThemePreviewScreen(
          slug: slug,
          themeId: themeId,
          themeName: themeName,
        ),
      ),
    );
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isError
                    ? Icons.error_outline_rounded
                    : (isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded),
                color: Colors.white,
                size: 26),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : (isSuccess ? Colors.teal.shade600 : Colors.grey.shade800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine crossAxisCount based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2; // Default for user request
    if (screenWidth < 600) {
      crossAxisCount = 2; // Keep 2 columns even on mobile as requested, or 1 if too cramped. Let's do 2.
    } else if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menü Tasarımı Seçin', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          final slug = provider.companySlug ?? 'demo'; // Fallback slug for preview rendering

          final themes = [
            {'id': 'retro', 'name': 'Retro Diner', 'desc': 'Canlı ve enerjik', 'color': Colors.pink},
            {'id': 'midnight', 'name': 'Midnight Velvet', 'desc': 'Karanlık ve lüks', 'color': Colors.amber},
            {'id': 'earth', 'name': 'Earth & Clay', 'desc': 'Sıcak ve bohem', 'color': const Color(0xFF065F46)},
            {'id': 'glass', 'name': 'Glassmorphism', 'desc': 'Fütüristik, şeffaf', 'color': Colors.blueAccent},
            {'id': 'zen', 'name': 'Zen Garden', 'desc': 'Minimalist, sakin', 'color': const Color(0xFF2D5A27)},
            {'id': 'nordic', 'name': 'Nordic Menu', 'desc': 'Kuzey Rüzgarı, ferah', 'color': Colors.blueGrey},
            {'id': 'flame', 'name': 'Flame Rush', 'desc': 'Ateşli ve hızlı', 'color': Colors.redAccent},
            {'id': 'bamboo', 'name': 'Bamboo Whisper', 'desc': 'Doğal ve huzurlu', 'color': const Color(0xFF4A6741)},
            {'id': 'streetfire', 'name': 'Street Fire', 'desc': 'Sokak lezzetleri, iddialı', 'color': Colors.deepOrange},
            {'id': 'gatsby', 'name': 'Gatsby Glamour', 'desc': 'Kükreyen yirmiler, lüks', 'color': const Color(0xFFD4AF37)},
            {'id': 'midnight2', 'name': 'Midnight Velvet 2', 'desc': 'Modern avangart', 'color': const Color(0xFFFBBF24)},
            {'id': 'comic', 'name': 'Comic Boom', 'desc': 'Pop-Art dinamik lezzet', 'color': const Color(0xFFFDE047)},
            {'id': 'earthy', 'name': 'Earthy Soul', 'desc': 'Organik, doğal ve taze', 'color': const Color(0xFF5A5A40)},
            {'id': 'syndicate', 'name': 'Syndicate', 'desc': 'Lounge deneyimi, premium', 'color': const Color(0xFFD4AF37)},
            {'id': 'lumiere', 'name': 'Lumière Light', 'desc': 'Zarif gastronomi, aydınlık', 'color': const Color(0xFFF8F8F6)},
            {'id': 'cupertino', 'name': 'Cupertino Glass', 'desc': 'Akıcı şeffaflık, Apple stili', 'color': const Color(0xFFE2E8F0)},
            {'id': 'grandverandah', 'name': 'Grand Verandah', 'desc': 'Aristokrat ve ferah, Beyoğlu esintisi', 'color': const Color(0xFF9B7B3C)},
            {'id': 'atelier', 'name': 'The Atelier', 'desc': 'Butik sanat galerisi, özel kulüp', 'color': const Color(0xFFE8D5A3)},
            {'id': 'forgebrasserie', 'name': 'Forge Brasserie', 'desc': 'Endüstriyel şık, bakır ve beton dokulu', 'color': const Color(0xFFC47D47)},
            {'id': 'mistluxury', 'name': 'Mist - Luxury', 'desc': 'Wellness & Spa, dingin mermer dokusu', 'color': const Color(0xFF7D9B76)},
            {'id': 'elysium', 'name': 'Elysium', 'desc': 'Premium lüks, obsidian ve altın detaylar', 'color': const Color(0xFFB89A5A)},
            {'id': 'rooftopmenu', 'name': 'Rooftop Menu', 'desc': 'Modern şehir manzaralı, glassmorphism estetiği', 'color': const Color(0xFFF59E0B)},
            {'id': 'saffronbazaar', 'name': 'Saffron Bazaar', 'desc': 'Otantik Doğu esintisi, Mandala ve baharat detayları', 'color': const Color(0xFFF59E0B)},
            {'id': 'dinermenu', 'name': 'Diner Menu', 'desc': 'Nostaljik 1950ler Amerikan Diner estetiği, interaktif TV animasyonu', 'color': const Color(0xFFDC2626)},
            {'id': 'maisondouce', 'name': 'Maison Douce', 'desc': 'Zarif Fransız pastanesi, butik estetik', 'color': const Color(0xFFB45309)},
            {'id': 'blackforge', 'name': 'Black Forge', 'desc': 'Endüstriyel steakhouse, ateşin gücü', 'color': const Color(0xFF111827)},
            {'id': 'osmanlisofrasi', 'name': 'Osmanlı Sofrası', 'desc': 'Saray mutfağı mirası, asil estetik', 'color': const Color(0xFFB8860B)},
            {'id': 'cafeqr', 'name': 'Café QR', 'desc': 'Modern neobrutalist kafe, cesur ve taze', 'color': const Color(0xFFFDE047)},
            {'id': 'cafemenu', 'name': 'Café Menu', 'desc': 'Butik kafeterya deneyimi, Neobrutalist renk blokları', 'color': const Color(0xFF2563EB)},
            {'id': 'fiestamenu', 'name': 'Fiesta Menu', 'desc': 'Baharatlı ve tutkulu, enerjik Meksika esintili tasarım', 'color': const Color(0xFFDC2626)},
            {'id': 'zenkitchen', 'name': 'Zen Kitchen', 'desc': 'Minimalist Japon estetiği, dingin ve modern', 'color': const Color(0xFF2D3A2D)},
            {'id': 'plajbar', 'name': 'Plaj Bar', 'desc': 'Sahil esintisi, canlı ve enerjik beach club tasarımı', 'color': const Color(0xFF0D9488)},
            {'id': 'obsidianelegance', 'name': 'Obsidian Elegance', 'desc': 'Lüks Fine Dining, siyah ve altın uyumu', 'color': const Color(0xFF0A0A0A)},
          ];

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65, // Taller cards to fit the mobile preview shape
            ),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final t = themes[index];
              final id = t['id'] as String;
              final name = t['name'] as String;
              final desc = t['desc'] as String;
              final color = t['color'] as Color;
              final isSelected = provider.themeId == id;

              return Card(
                elevation: isSelected ? 8 : 2,
                shadowColor: isSelected ? color.withOpacity(0.4) : Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isSelected ? color : Colors.transparent,
                    width: isSelected ? 3 : 0,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    await provider.updateTheme(id);
                    _showSnackBar('Tema güncellendi: $name', isSuccess: true);
                  },
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              color: Colors.grey.shade200,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                child: IgnorePointer( // Don't allow scrolling the mini-preview
                                  child: MiniThemePreview(
                                    slug: slug,
                                    themeId: id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: isSelected ? color.withOpacity(0.05) : Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openThemePreview(provider, id, name),
                                      icon: const Icon(Icons.fullscreen_rounded, size: 18),
                                      label: const Text('Önizle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected ? color : Colors.grey.shade900,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
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

// A widget that loads an actual WebView scaled down as a thumbnail.
class MiniThemePreview extends StatefulWidget {
  final String slug;
  final String themeId;

  const MiniThemePreview({super.key, required this.slug, required this.themeId});

  @override
  State<MiniThemePreview> createState() => _MiniThemePreviewState();
}

class _MiniThemePreviewState extends State<MiniThemePreview> with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Prevent reloading when scrolling grid

  @override
  void initState() {
    super.initState();
    final url = 'https://gastroqr-5dcdb.web.app/${widget.slug}?theme=${widget.themeId}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          // Canlı taslakların içinde kaydırmanın engellenmesi ve sayfanın CSS ile küçültülmesi (macOS PlatformView uyumluluğu için)
          _controller.runJavaScript("""
            var style = document.createElement('style');
            style.innerHTML = '::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; } * { -ms-overflow-style: none; scrollbar-width: none; } body { overflow: hidden !important; touch-action: none; margin: 0; padding: 0; transform-origin: top left; }';
            document.head.appendChild(style);

            // Fetch container width to scale down dynamically like a mobile viewport
            var width = window.innerWidth;
            if (width > 0 && width < 375) {
              var scale = width / 375.0;
              document.body.style.width = '375px';
              document.body.style.transform = 'scale(' + scale + ')';
            }
          """);
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        // Do directly load the WebView container to let it negotiate sizes with macOS cleanly.
        // The CSS injection above handles the internal 'scale to fit'.
        SizedBox.expand(
          child: WebViewWidget(controller: _controller),
        ),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade400),
          ),
        // Add a subtle gradient overlay so the text doesn't clash with it
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.3)],
            ),
          ),
        ),
      ],
    );
  }
}

