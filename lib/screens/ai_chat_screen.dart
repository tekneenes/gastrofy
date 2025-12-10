import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/table_ai_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TableAIService _aiService = TableAIService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Content> _chatHistory = [];
  final List<ChatMessage> _displayMessages = [];

  bool _isLoading = false;
  String _thinkingPhase = '';
  late AnimationController _thinkingAnimController;
  late Animation<double> _thinkingAnimation;

  String? _geminiApiKey;
  bool _isApiKeyChecking = true;
  final TextEditingController _apiKeyController = TextEditingController();
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();

    _thinkingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _thinkingAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _thinkingAnimController, curve: Curves.easeInOut),
    );

    _loadApiKeyAndInit();

    _displayMessages.add(ChatMessage(
      role: 'assistant',
      text:
          'Merhaba! 👋 Ben Table Intelligence. Size bugünkü ciro, ödenmemiş veresiyeler, masa durumları ve daha fazlası hakkında yardımcı olabilirim.',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _loadApiKeyAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key');

    if (apiKey != null && apiKey.isNotEmpty) {
      _initializeServices(apiKey);
    }

    if (mounted) {
      setState(() => _isApiKeyChecking = false);
    }
  }

  void _initializeServices(String apiKey) {
    try {
      Gemini.init(apiKey: apiKey);
      _aiService.setApiKey(apiKey);

      setState(() {
        _geminiApiKey = apiKey;
        _apiKeyError = null;
      });
    } catch (e) {
      debugPrint("Gemini başlatılırken hata: $e");
      setState(() {
        _geminiApiKey = null;
        _apiKeyError = "API Anahtarı geçersiz veya başlatılamadı.";
      });
    }
  }

  Future<void> _resetApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gemini_api_key');

    _aiService.setApiKey('');

    setState(() {
      _geminiApiKey = null;
      _apiKeyController.clear();
      _apiKeyError = null;
    });
  }

  Widget _buildLinkText(BuildContext context, String text, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.blue.shade700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Link açılamadı: $url');
    }
  }

  @override
  void dispose() {
    _thinkingAnimController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = ChatMessage(
      role: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _displayMessages.add(userMessage);
      _controller.clear();
      _isLoading = true;
      _thinkingPhase = 'Sorgunuz analiz ediliyor...';
    });

    _scrollToBottom();

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted)
        setState(() => _thinkingPhase = 'Veritabanı sorgulanıyor...');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _thinkingPhase = 'Yanıt oluşturuluyor...');

      final responseText =
          await _aiService.getGeminiResponseWithRAG(text, _chatHistory);

      final assistantMessage = ChatMessage(
        role: 'assistant',
        text: responseText,
        timestamp: DateTime.now(),
        isAnimating: true,
      );

      final geminiResponseContent =
          Content(role: 'model', parts: [Part.text(responseText)]);

      if (mounted) {
        setState(() {
          _chatHistory.add(Content(role: 'user', parts: [Part.text(text)]));
          _chatHistory.add(geminiResponseContent);
          _displayMessages.add(assistantMessage);
          _isLoading = false;
          _thinkingPhase = '';
        });
      }

      _scrollToBottom();
      _animateMessageText(assistantMessage);
    } catch (e) {
      String errorMessage = e.toString();
      if (e.toString().toLowerCase().contains('api key not valid') ||
          e.toString().contains('Invalid API Key')) {
        _resetApiKey();
        if (mounted) {
          setState(() =>
              _apiKeyError = "API Anahtarı geçersiz. Lütfen tekrar girin.");
        }
      } else {
        if (mounted) {
          setState(() {
            _displayMessages.add(ChatMessage(
              role: 'system',
              text: '❌ Bir hata oluştu: $errorMessage',
              timestamp: DateTime.now(),
            ));
            _isLoading = false;
            _thinkingPhase = '';
          });
        }
        _scrollToBottom();
      }
    }
  }

  void _animateMessageText(ChatMessage message) async {
    final fullText = message.text;
    for (int i = 0; i <= fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
      if (mounted) {
        setState(() {
          message.displayedText = fullText.substring(0, i);
        });
        if (i % 10 == 0) _scrollToBottom();
      }
    }
    if (mounted) {
      setState(() {
        message.isAnimating = false;
        message.displayedText = fullText;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Widget _buildApiKeyPlaceholder() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_rounded,
                  size: 40, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            const Text(
              'API Anahtarı Gerekli',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Yapay zeka asistanını kullanabilmek için Google Gemini API anahtarına ihtiyacınız var.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            if (_apiKeyError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _apiKeyError!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Anahtarı',
                hintText: 'Anahtarı buraya yapıştırın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                prefixIcon: const Icon(Icons.password_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final newKey = _apiKeyController.text.trim();
                if (newKey.isEmpty) {
                  setState(() => _apiKeyError = "Lütfen bir anahtar girin.");
                  return;
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', newKey);
                _initializeServices(newKey);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Kaydet ve Başlat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  const Text(
                    'Nasıl API Anahtarı Alırım?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  _buildLinkText(
                    context,
                    "1. Google AI Studio'ya gidin.",
                    'https://aistudio.google.com/app/apikey',
                  ),
                  const SizedBox(height: 4),
                  const Text("2. 'Create API key' butonuna tıklayın.",
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isApiKeyChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text(
                'Ayarlar yükleniyor...',
                style: TextStyle(fontSize: 16, color: Colors.teal),
              ),
            ],
          ),
        ),
      );
    }

    final bool hasApiKey = _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table Intelligence',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Masa Takip Sistemi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        toolbarHeight: 70,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (hasApiKey) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 26),
              onPressed: () {
                setState(() {
                  _displayMessages.clear();
                  _chatHistory.clear();
                  _displayMessages.add(ChatMessage(
                    role: 'assistant',
                    text:
                        'Merhaba! 👋 Ben Table Intelligence. Size nasıl yardımcı olabilirim?',
                    timestamp: DateTime.now(),
                  ));
                });
              },
              tooltip: 'Sohbeti Sıfırla',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.vpn_key, color: Colors.white),
              onSelected: (value) {
                if (value == 'reset') {
                  _resetApiKey();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Anahtarı Sil / Değiştir"),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: hasApiKey
          ? Column(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.teal.withOpacity(0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: _displayMessages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == 0) {
                        return _buildThinkingIndicator();
                      }
                      final messageIndex = _isLoading ? index - 1 : index;
                      final message = _displayMessages[
                          _displayMessages.length - 1 - messageIndex];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
                _buildInputArea(),
              ],
            )
          : _buildApiKeyPlaceholder(),
    );
  }

  Widget _buildThinkingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.teal.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _thinkingAnimation,
                      child: const Icon(Icons.psychology_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _thinkingPhase,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _thinkingAnimController,
                      builder: (context, child) {
                        final delay = index * 0.2;
                        final value = (_thinkingAnimController.value - delay)
                            .clamp(0.0, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withOpacity(0.3 + (value * 0.7)),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? LinearGradient(
                          colors: [Colors.teal.shade400, Colors.teal.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUser ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isUser
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? Colors.teal.withOpacity(0.3)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      message.isAnimating
                          ? message.displayedText
                          : message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!message.isAnimating) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isUser ? Colors.white70 : Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal.shade200, width: 2),
                ),
                child: Icon(Icons.person_rounded,
                    color: Colors.teal.shade700, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final bool isApiKeySet = _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 90),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: isApiKeySet
                        ? Colors.grey.shade50
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isApiKeySet
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey.shade700,
                    ),
                    decoration: InputDecoration(
                      hintText: isApiKeySet
                          ? "Asistana bir şeyler sorun..."
                          : "Önce API anahtarını ayarlayın...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(
                          isApiKeySet
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.lock_outline_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isLoading && isApiKeySet,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: _isLoading || !isApiKeySet
                      ? LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500])
                      : LinearGradient(
                          colors: [Colors.teal.shade400, Colors.teal.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  shape: BoxShape.circle,
                  boxShadow: _isLoading || !isApiKeySet
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading || !isApiKeySet ? null : _sendMessage,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              isApiKeySet
                                  ? Icons.send_rounded
                                  : Icons.key_rounded,
                              color: Colors.white,
                              size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class ChatMessage {
  final String role;
  final String text;
  final DateTime timestamp;
  bool isAnimating;
  String displayedText;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.isAnimating = false,
  }) : displayedText = isAnimating ? '' : text;
}
