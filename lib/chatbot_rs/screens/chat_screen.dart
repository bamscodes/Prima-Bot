import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../presentation/providers/chat_provider.dart';
import '../presentation/widgets/app_motion.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode(skipTraversal: true);
  final FocusNode _editFocusNode = FocusNode(skipTraversal: true);
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? _editingMessageIndex;
  DateTime? _lastTypewriterScrollTime;

  void _onTypewriterTick() {
    final now = DateTime.now();
    if (_lastTypewriterScrollTime == null ||
        now.difference(_lastTypewriterScrollTime!) >
            const Duration(milliseconds: 100)) {
      _lastTypewriterScrollTime = now;
      if (_scrollController.hasClients) {
        if (_scaffoldKey.currentState?.isDrawerOpen == true) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (_scrollController.offset >= maxScroll - 200) {
          _scrollController.jumpTo(maxScroll);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _lastMessageCount = chatProvider.messages.length;
      _lastIsLoading = chatProvider.isLoading;
      chatProvider.addListener(_onChatUpdated);
      _inputFocusNode.unfocus();
      _editFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      _scrollToBottom(smooth: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.removeListener(_onChatUpdated);
    _controller.dispose();
    _editController.dispose();
    _inputFocusNode.dispose();
    _editFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Cegah scroll jump saat sidebar sedang terbuka agar animasi slide drawer tetap 60 FPS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scaffoldKey.currentState?.isDrawerOpen == true) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  int _lastMessageCount = 0;
  bool _lastIsLoading = false;

  void _onChatUpdated() {
    if (!mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentCount = chatProvider.messages.length;
    final currentIsLoading = chatProvider.isLoading;

    if (currentCount > _lastMessageCount) {
      _scrollToBottom();
    } else if (currentIsLoading && !_lastIsLoading) {
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
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final bottomExtent = _scrollController.position.maxScrollExtent;
      final isTyping = _inputFocusNode.hasFocus || _editFocusNode.hasFocus;
      if (smooth && !isTyping) {
        _scrollController.animateTo(
          bottomExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(bottomExtent);
      }
    });
  }

  void _showUserBubbleActions(
    BuildContext context,
    int index,
    String text,
    ChatProvider chatProvider,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.secondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 8.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D9D9D).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.copy_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    'Salin Teks',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Teks disalin'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    'Edit Pesan',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _editingMessageIndex = index;
                      _editController.text = text;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.surface,
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          _inputFocusNode.unfocus();
          _editFocusNode.unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      drawer: RepaintBoundary(
        child: _buildDrawer(context, theme, chatProvider),
      ),
      body: RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            _inputFocusNode.unfocus();
            _editFocusNode.unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(theme),
                Expanded(
                  child:
                      chatProvider.messages.isEmpty && !chatProvider.isLoading
                      ? _buildEmptyChat(theme)
                      : _buildChatList(chatProvider, theme),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child:
                      (chatProvider.messages.isNotEmpty &&
                          chatProvider.suggestions.isNotEmpty &&
                          !chatProvider.isLoading)
                      ? _buildSuggestions(chatProvider, theme)
                      : const SizedBox.shrink(),
                ),
                _buildInputArea(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.view_sidebar_outlined,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ),
          Text(
            'Prima',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                context.read<ChatProvider>().startNewChat();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hai Hai',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gimana Kabarmu Hari Ini?\nAda Yang Bisa Prima Bantu',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9D9D9D),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider, ThemeData theme) {
    final totalCount =
        chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final lastUserMessage = chatProvider.messages.reversed
        .cast<ChatMessage?>()
        .firstWhere((m) => m != null && !m.isBot, orElse: () => null);

    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      scrollCacheExtent: const ScrollCacheExtent.pixels(350),
      padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (chatProvider.isLoading && index == chatProvider.messages.length) {
          return RepaintBoundary(
            child: _MessageEntranceAnimation(
              child: AIThinkingIndicator(
                theme: theme,
                userPrompt: lastUserMessage?.text,
              ),
            ),
          );
        }

        final messageIndex = index;
        final message = chatProvider.messages[messageIndex];
        final isBot = message.isBot;
        final isEditingThis = !isBot && _editingMessageIndex == messageIndex;
        final shouldAnimate = !message.isAnimated;

        if (isEditingThis) {
          return RepaintBoundary(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(left: 48, bottom: 16),
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(maxWidth: screenWidth * 0.85),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _editController,
                      focusNode: _editFocusNode,
                      autofocus: false,
                      maxLines: null,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _editingMessageIndex = null);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF7F9F9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final newText = _editController.text;
                            setState(() => _editingMessageIndex = null);
                            chatProvider.editMessageAndRegenerate(
                              messageIndex,
                              newText,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kirim',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!isBot) {
          // User Message Bubble (Rapat Kanan, fit content sesuai Figma)
          return RepaintBoundary(
            child: _MessageEntranceAnimation(
              animate: shouldAnimate,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(left: 60, bottom: 16),
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(4),
                    ),
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                      onTap: () => _showUserBubbleActions(
                        context,
                        messageIndex,
                        message.text,
                        chatProvider,
                        theme,
                      ),
                      onLongPress: () => _showUserBubbleActions(
                        context,
                        messageIndex,
                        message.text,
                        chatProvider,
                        theme,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                DateFormat('HH.mm').format(message.time),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: const Color(0xFF9D9D9D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Bot Message Bubble (Rapat Kiri, Prima Toska) + Action Buttons
        return RepaintBoundary(
          child: _MessageEntranceAnimation(
            animate: shouldAnimate,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 32, bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.86),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Prima',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TypewriterMarkdownBody(
                          fullText: message.text,
                          theme: theme,
                          animate: shouldAnimate,
                          onTick: _onTypewriterTick,
                          onComplete: () {
                            message.isAnimated = true;
                            chatProvider.markMessageAnimated(messageIndex);
                            _scrollToBottom();
                          },
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('HH.mm').format(message.time),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action Icons di bawah bubble AI (Play, Refresh, Copy)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 18.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            chatProvider.togglePlayPause(
                              messageIndex,
                              message.text,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              chatProvider.isMessagePlaying(messageIndex)
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: chatProvider.isMessagePlaying(messageIndex)
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            chatProvider.regenerateResponse(messageIndex);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: message.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Teks disalin'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestions(ChatProvider provider, ThemeData theme) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: provider.suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = provider.suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _sendMessage(suggestion);
              },
              backgroundColor: theme.colorScheme.secondary,
              side: BorderSide.none,
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('chat_input'),
                controller: _controller,
                focusNode: _inputFocusNode,
                autofocus: false,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                textAlignVertical: TextAlignVertical.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Tanya Sesuatu...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9D9D9D),
                    fontSize: 15,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            AppScaleTap(
              semanticLabel: 'Kirim pesan',
              onTap: () => _sendMessage(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    ThemeData theme,
    ChatProvider chatProvider,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: screenWidth * 0.78,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Prima',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 2.0,
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusColor: Colors.transparent,
                      hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                      splashColor: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      leading: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      title: Text(
                        'New Chat',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                        chatProvider.startNewChat();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 2.0,
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusColor: Colors.transparent,
                      hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                      splashColor: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      leading: Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      title: Text(
                        'Search',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Divider(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24.0,
                      top: 4.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      'Riwayat',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF9D9D9D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Dynamic History List (Isolated Scroll Area)
            Expanded(
              child: ClipRect(
                child: Material(
                  type: MaterialType.transparency,
                  child: chatProvider.sessions.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak Ada Chat',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF9D9D9D),
                            ),
                          ),
                        )
                      : ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: chatProvider.sessions.length,
                        itemBuilder: (context, index) {
                          final session = chatProvider.sessions[index];
                          final isActive =
                              session.id == chatProvider.sessionId;
                          final timeAgo = _formatTimeAgo(session.updatedAt);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 2.0,
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusColor: Colors.transparent,
                              hoverColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                              splashColor: theme.colorScheme.secondary.withValues(alpha: 0.7),
                              selected: isActive,
                              selectedColor: theme.colorScheme.onSurface,
                              selectedTileColor: theme.colorScheme.secondary,
                              leading: Icon(
                                Icons.chat_outlined,
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : const Color(0xFF9D9D9D),
                                size: 20,
                              ),
                              title: session.isTitlePending
                                  ? const HistoryTitleSkeleton()
                                  : Text(
                                      session.title,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              subtitle: Text(
                                timeAgo,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF9D9D9D),
                                  fontSize: 10,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFF9D9D9D),
                                  size: 18,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor:
                                          theme.colorScheme.secondary,
                                      title: Text(
                                        'Hapus Chat?',
                                        style: TextStyle(
                                          color:
                                              theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      content: Text(
                                        'Chat "${session.title}" akan dihapus permanen.',
                                        style: const TextStyle(
                                          color: Color(0xFF9D9D9D),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx),
                                          child: const Text(
                                            'Batal',
                                            style: TextStyle(
                                              color: Color(
                                                0xFFF7F9F9,
                                              ),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            chatProvider.deleteSessionById(
                                              session.id,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text(
                                            'Hapus',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context);
                                chatProvider.switchSession(session.id);
                              },
                            ),
                          );
                        },
                      ),
                ),
              ),
            ),
            // Solid Footer (Mencegah riwayat tembus/bocor saat di-scroll ke bawah)
            Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.settings,
                        color: theme.colorScheme.onSurface,
                        size: 22,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }
}

/// Placeholder skeleton untuk riwayat yang judulnya masih dirangkum AI.
/// Bentuk ini tidak menampilkan pesan pertama agar pengguna tidak melihat
/// fallback sebelum request AI benar-benar gagal.
class HistoryTitleSkeleton extends StatefulWidget {
  const HistoryTitleSkeleton({super.key});

  @override
  State<HistoryTitleSkeleton> createState() => _HistoryTitleSkeletonState();
}

class _HistoryTitleSkeletonState extends State<HistoryTitleSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.secondary;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_controller),
      child: Container(
        key: const ValueKey('history_title_skeleton'),
        height: 16,
        width: 180,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Widget Indikator Pemikiran AI dengan animasi 3 titik mengetik dan alur berpikir dinamis bebas overflow
class AIThinkingIndicator extends StatefulWidget {
  final ThemeData theme;
  final String? userPrompt;
  const AIThinkingIndicator({super.key, required this.theme, this.userPrompt});

  @override
  State<AIThinkingIndicator> createState() => _AIThinkingIndicatorState();
}

class _AIThinkingIndicatorState extends State<AIThinkingIndicator> {
  late List<String> _thoughts;
  int _thoughtIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _thoughts = _generateThoughts(widget.userPrompt);

    _timer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (mounted) {
        setState(() {
          _thoughtIndex = (_thoughtIndex + 1) % _thoughts.length;
        });
      }
    });
  }

  List<String> _generateThoughts(String? prompt) {
    if (prompt == null || prompt.trim().isEmpty) {
      return [
        'Sedang berpikir...',
        'Menghubungkan ke database RS...',
        'Menyusun respons terbaik...',
      ];
    }

    final lower = prompt.toLowerCase();

    if (lower.contains('dokter') ||
        lower.contains('jadwal') ||
        lower.contains('praktek') ||
        lower.contains('spesialis')) {
      return [
        'Menganalisis jadwal dokter...',
        'Mencari data spesialis di RS...',
        'Memverifikasi jam praktek...',
        'Menyusun jadwal untuk Anda...',
      ];
    } else if (lower.contains('poli') ||
        lower.contains('anak') ||
        lower.contains('bedah') ||
        lower.contains('kandungan') ||
        lower.contains('dalam') ||
        lower.contains('vct') ||
        lower.contains('umum')) {
      return [
        'Memeriksa layanan poliklinik...',
        'Mengambil daftar dokter poli...',
        'Menyiapkan ringkasan poli...',
      ];
    } else if (lower.contains('lokasi') ||
        lower.contains('alamat') ||
        lower.contains('gedung') ||
        lower.contains('dimana') ||
        lower.contains('maps') ||
        lower.contains('tempat')) {
      return ['Mencari lokasi RS Prima...', 'Menyiapkan navigasi gedung...'];
    } else if (lower.contains('kontak') ||
        lower.contains('nomor') ||
        lower.contains('telepon') ||
        lower.contains('wa') ||
        lower.contains('whatsapp') ||
        lower.contains('call center') ||
        lower.contains('igd') ||
        lower.contains('darurat')) {
      return [
        'Mengakses kontak resmi 24 jam...',
        'Menyiapkan nomor darurat & pendaftaran...',
      ];
    } else if (lower.contains('biaya') ||
        lower.contains('tarif') ||
        lower.contains('bpjs') ||
        lower.contains('asuransi') ||
        lower.contains('daftar') ||
        lower.contains('kamar')) {
      return [
        'Memeriksa ketentuan pendaftaran...',
        'Menyiapkan rincian administrasi...',
      ];
    } else {
      return [
        'Menganalisis pertanyaan Anda...',
        'Memahami kebutuhan informasi...',
        'Mencari data RS yang relevan...',
        'Menyusun jawaban terbaik...',
      ];
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 24, top: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.secondary.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: widget.theme.colorScheme.primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ThreeDotsWave(color: widget.theme.colorScheme.primary, size: 5.0),
              const SizedBox(width: 10),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _thoughts[_thoughtIndex],
                    key: ValueKey<int>(_thoughtIndex),
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9D9D9D),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
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
}

/// Animasi 3 titik bergelombang (*typing wave loader*)
class ThreeDotsWave extends StatefulWidget {
  final Color color;
  final double size;
  const ThreeDotsWave({super.key, required this.color, this.size = 5.0});

  @override
  State<ThreeDotsWave> createState() => _ThreeDotsWaveState();
}

class _ThreeDotsWaveState extends State<ThreeDotsWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final val = (_controller.value - delay) % 1.0;
            final wave = (val < 0.5) ? (val * 2) : (2 - val * 2);
            final scale = 0.6 + (wave * 0.6);
            final opacity = 0.35 + (wave * 0.65);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Widget Typewriter Markdown Body untuk efek mengetik pesan AI baru secara bertahap yang smooth
class TypewriterMarkdownBody extends StatefulWidget {
  final String fullText;
  final ThemeData theme;
  final bool animate;
  final VoidCallback onComplete;
  final VoidCallback? onTick;

  const TypewriterMarkdownBody({
    super.key,
    required this.fullText,
    required this.theme,
    required this.animate,
    required this.onComplete,
    this.onTick,
  });

  @override
  State<TypewriterMarkdownBody> createState() => _TypewriterMarkdownBodyState();
}

class _TypewriterMarkdownBodyState extends State<TypewriterMarkdownBody> {
  int _characterCount = 0;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.fullText.isNotEmpty) {
      _startTypewriter();
    } else {
      _characterCount = widget.fullText.length;
    }
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _characterCount = 0;
    // Kurangi frekuensi rebuild agar input tetap responsif. Markdown hanya
    // diparse setelah animasi selesai.
    const step = 8;
    const interval = Duration(milliseconds: 50);

    _typewriterTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _characterCount += step;
        if (_characterCount >= widget.fullText.length) {
          _characterCount = widget.fullText.length;
          timer.cancel();
          widget.onComplete();
        } else {
          widget.onTick?.call();
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant TypewriterMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText != widget.fullText ||
        oldWidget.animate != widget.animate) {
      _typewriterTimer?.cancel();
      if (widget.animate && widget.fullText.isNotEmpty) {
        _startTypewriter();
      } else {
        _characterCount = widget.fullText.length;
      }
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = _characterCount >= widget.fullText.length;
    final displayText = isFinished
        ? widget.fullText
        : widget.fullText.substring(0, _characterCount);

    return GestureDetector(
      onTap: () {
        // Klik bubble untuk menyelesaikan typewriter secara instan
        if (!isFinished) {
          _typewriterTimer?.cancel();
          setState(() {
            _characterCount = widget.fullText.length;
          });
          widget.onComplete();
        }
      },
      child: isFinished
          ? MarkdownBody(
              data: widget.fullText,
              onTapLink: (text, href, title) async {
                if (href == null) return;

                final uri = Uri.tryParse(href);
                if (uri == null ||
                    (uri.scheme != 'https' && uri.scheme != 'http')) {
                  return;
                }

                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch $href: $e');
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: widget.theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
                strong: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : Text(
              displayText,
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
    );
  }
}

/// Mikro-animasi masuk halus untuk bubble chat baru secara real-time.
class _MessageEntranceAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;

  const _MessageEntranceAnimation({required this.child, this.animate = true});

  @override
  State<_MessageEntranceAnimation> createState() =>
      _MessageEntranceAnimationState();
}

class _MessageEntranceAnimationState extends State<_MessageEntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
