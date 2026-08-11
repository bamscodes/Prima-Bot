import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../presentation/providers/chat_provider.dart';
import '../presentation/providers/theme_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll when messages change or bot starts/stops typing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _lastMessageCount = chatProvider.messages.length;
      _lastIsLoading = chatProvider.isLoading;
      chatProvider.addListener(_onChatUpdated);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.removeListener(_onChatUpdated);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _lastMessageCount = 0;
  bool _lastIsLoading = false;

  void _onChatUpdated() {
    if (!mounted) return;
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentCount = chatProvider.messages.length;
    final currentIsLoading = chatProvider.isLoading;

    // Only scroll if there are new messages or bot starts typing
    if (currentCount > _lastMessageCount || (currentIsLoading && !_lastIsLoading)) {
      _scrollToBottom();
    }
    
    _lastMessageCount = currentCount;
    _lastIsLoading = currentIsLoading;
  }

  void _sendMessage([String? text]) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messageText = text ?? _controller.text;
    if (messageText.trim().isNotEmpty) {
      chatProvider.sendMessage(messageText);
      _controller.clear();
      // No need to call _scrollToBottom here as the listener will handle it
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _launchWhatsApp() async {
    const phone = "6281511000600";
    final Uri whatsappUri = Uri.parse("whatsapp://send?phone=$phone");
    final Uri webUri = Uri.parse("https://wa.me/$phone");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp. Pastikan WhatsApp terinstal.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prima Bot',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.brightness == Brightness.dark 
                          ? Colors.blueAccent // Warna cyan/biru terang khusus dark mode
                          : Colors.greenAccent, 
                      radius: 4,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Online',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent_rounded, color: theme.colorScheme.onPrimary),
            onPressed: _launchWhatsApp,
            tooltip: 'Hubungi WhatsApp',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimary),
            onSelected: (value) {
              if (value == 'theme') {
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                themeProvider.toggleTheme(theme.brightness == Brightness.dark);
              } else if (value == 'clear') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Chat?'),
                    content: const Text('Semua riwayat percakapan Anda akan dihapus secara permanen.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          chatProvider.clearChat();
                          Navigator.pop(context);
                        },
                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      theme.brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Text(theme.brightness == Brightness.dark ? 'Mode Terang' : 'Mode Gelap'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    const Text('Hapus Pesan', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final message = chatProvider.messages[index];
                final isBot = message.isBot;
                
                return Align(
                  alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: isBot 
                            ? (theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white)
                            : theme.colorScheme.primary,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isBot ? Radius.zero : const Radius.circular(16),
                            bottomRight: isBot ? const Radius.circular(16) : Radius.zero,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: isBot ? Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              selectable: true,
                              data: message.text,
                              onTapLink: (text, href, title) async {
                                if (href != null) {
                                  final uri = Uri.parse(href);
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (e) {
                                    debugPrint('Could not launch $href: $e');
                                  }
                                }
                              },
                              styleSheet: MarkdownStyleSheet(
                                p: theme.textTheme.bodyMedium?.copyWith(
                                  color: isBot ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary,
                                ),
                                strong: TextStyle(fontWeight: FontWeight.bold, color: isBot ? theme.colorScheme.primary : theme.colorScheme.onPrimary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isBot) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (chatProvider.speakingMessageIndex == index) {
                                        chatProvider.stopSpeaking();
                                      } else {
                                        chatProvider.speak(message.text, index);
                                      }
                                    },
                                    child: Icon(
                                      chatProvider.speakingMessageIndex == index ? Icons.stop_circle_outlined : Icons.play_circle_outline, 
                                      size: 18, 
                                      color: chatProvider.speakingMessageIndex == index 
                                          ? Colors.red.withValues(alpha: 0.8) 
                                          : theme.colorScheme.primary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  DateFormat('HH:mm').format(message.time),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: isBot 
                                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4) 
                                      : theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (chatProvider.isLoading) _buildTypingIndicator(theme),
          if (chatProvider.suggestions.isNotEmpty) _buildSuggestions(chatProvider, theme),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Text('Bot sedang mengetik', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ChatProvider provider, ThemeData theme) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = provider.suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () => _sendMessage(suggestion),
              backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              labelStyle: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Tanya sesuatu...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary,
              child: IconButton(
                icon: Icon(Icons.send_rounded, color: theme.colorScheme.onPrimary, size: 24),
                onPressed: () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
