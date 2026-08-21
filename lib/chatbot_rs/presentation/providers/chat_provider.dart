import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/edge_tts_service.dart';
import '../../data/datasources/local_datasource.dart';
import '../../domain/usecases/get_bot_response.dart';
import '../../domain/usecases/generate_conversation_title.dart';
import '../../domain/utils/conversation_title_formatter.dart';

class ChatMessage {
  final String text; // Teks untuk ditampilkan di UI (bisa berisi markdown/link)
  final String?
  ttsText; // Teks khusus untuk TTS (tanpa markdown, plain text). Jika null, gunakan text.
  final bool isBot;
  final DateTime time;
  bool isAnimated; // Menyimpan status apakah animasi typewriter telah selesai

  ChatMessage({
    required this.text,
    this.ttsText,
    required this.isBot,
    required this.time,
    this.isAnimated = true,
  });
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTitlePending;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isTitlePending,
  });

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isTitlePending: (map['title_generated'] as int? ?? 1) == 0,
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final GetBotResponse _getBotResponse = GetBotResponse();
  final GenerateConversationTitle _generateConversationTitle =
      GenerateConversationTitle();
  final EdgeTtsService _tts = EdgeTtsService();
  final Uuid _uuid = const Uuid();

  String _sessionId = '';
  bool _isSessionPersisted = false;
  bool _isLoading = false;
  String? _loadingSessionId;
  int? _activeRequestToken;
  int _requestTokenSequence = 0;
  int? _speakingMessageIndex;
  bool _isTtsPaused = false;
  List<String> _suggestions = [
    'Jadwal Poliklinik',
    'Informasi Kontak',
    'Lokasi RS',
  ];
  List<ChatSession> _sessions = [];

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSpeaking => _speakingMessageIndex != null;
  bool get isTtsPaused => _isTtsPaused;
  int? get speakingMessageIndex => _speakingMessageIndex;
  bool isMessagePlaying(int index) =>
      _speakingMessageIndex == index && !_isTtsPaused;
  bool isMessagePaused(int index) =>
      _speakingMessageIndex == index && _isTtsPaused;
  String get sessionId => _sessionId;
  List<String> get suggestions => _suggestions;
  List<ChatSession> get sessions => _sessions;

  void markMessageAnimated(int index) {
    if (index >= 0 && index < _messages.length) {
      _messages[index].isAnimated = true;
    }
  }

  ChatProvider() {
    _initTts();
    _initSessions();
  }

  /// Initialize: load session list for drawer, but ALWAYS start on a fresh draft ("Hai Hai" landing page)
  Future<void> _initSessions() async {
    try {
      await DatabaseHelper.instance.deleteSessionsWithoutUserMessages();
      await DatabaseHelper.instance.sanitizeSessionTitles(
        ConversationTitleFormatter.format,
      );
      await loadSessions();
      // Selalu mulai di sesi baru / halaman awal ("Hai Hai") saat pertama kali masuk
      await startNewChat();
    } catch (e) {
      log('Failed to init sessions: $e');
      await startNewChat();
    }
  }

  /// Load all sessions from database
  Future<void> loadSessions() async {
    try {
      final sessionMaps = await DatabaseHelper.instance.getAllSessions();
      _sessions = sessionMaps.map((m) => ChatSession.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      log('Failed to load sessions: $e');
    }
  }

  /// Start an in-memory draft that is persisted after the first message.
  Future<void> startNewChat() async {
    _clearLoadingForSession(_sessionId);
    await stopSpeaking();

    _sessionId = _uuid.v4();
    _isSessionPersisted = false;
    _messages.clear();
    _suggestions = [];
    notifyListeners();
  }

  /// Switch to an existing session
  Future<void> switchSession(String sessionId) async {
    if (_sessionId == sessionId) return;

    // Stop any TTS and detach loading state from the previous session.
    _clearLoadingForSession(_sessionId);
    await stopSpeaking();

    _sessionId = sessionId;
    _isSessionPersisted = true;
    _messages.clear();
    _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'];

    await _loadHistory(sessionId);
  }

  /// Delete a specific session
  Future<void> deleteSessionById(String sessionId) async {
    _clearLoadingForSession(sessionId);
    await DatabaseHelper.instance.deleteSession(sessionId);

    // If we deleted the current session, switch to another or create new
    if (_sessionId == sessionId) {
      await loadSessions();
      if (_sessions.isNotEmpty) {
        await switchSession(_sessions.first.id);
      } else {
        await startNewChat();
      }
    } else {
      await loadSessions();
    }
  }

  Future<void> _loadHistory(String sessionId) async {
    final loadedMessages = <ChatMessage>[];

    try {
      final history = await DatabaseHelper.instance.getChatHistory(sessionId);
      for (final item in history) {
        loadedMessages.add(
          ChatMessage(
            text: item['text'],
            ttsText: item['tts_text'],
            isBot: item['is_bot'] == 1,
            time: DateTime.parse(item['timestamp']),
          ),
        );
      }
    } catch (e) {
      log('Failed to load history for session $sessionId: $e');
    }

    if (_sessionId != sessionId) return;

    _messages
      ..clear()
      ..addAll(loadedMessages);
    notifyListeners();
  }

  void _initTts() async {
    // Pasang callback handler SEBELUM init agar tidak terlewat
    _tts.setStartHandler(() {
      debugPrint('[TTS Provider] Suara mulai diputar');
      _isTtsPaused = false;
      notifyListeners();
    });

    _tts.setPauseHandler(() {
      debugPrint('[TTS Provider] Suara dijeda (paused)');
      _isTtsPaused = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      debugPrint('[TTS Provider] Suara selesai diputar');
      _speakingMessageIndex = null;
      _isTtsPaused = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      debugPrint('[TTS Provider] Error saat memutar suara: $msg');
      _speakingMessageIndex = null;
      _isTtsPaused = false;
      notifyListeners();
    });

    // Inisialisasi setelah handler terpasang
    await _tts.init();
    debugPrint('[TTS Provider] TTS service siap digunakan');
  }

  /// Toggle antara Play, Pause, dan Resume untuk pesan ke-[index]
  Future<void> togglePlayPause(int index, String text) async {
    debugPrint(
      '[TTS Provider] togglePlayPause for index $index. Speaking index: $_speakingMessageIndex, isPaused: $_isTtsPaused',
    );

    if (_speakingMessageIndex == index) {
      if (!_isTtsPaused) {
        // Sedang play -> Pause
        await pauseSpeaking();
      } else {
        // Sedang pause -> Resume dari posisi terakhir
        await resumeSpeaking();
      }
    } else {
      // Memutar pesan baru atau pesan yang berbeda -> Putar dari awal
      await speak(text, index);
    }
  }

  Future<void> speak(String text, int index) async {
    _speakingMessageIndex = index;
    _isTtsPaused = false;
    notifyListeners();

    // Gunakan ttsText jika tersedia (teks bersih tanpa markdown/link),
    // jika tidak ada, kirim teks asli dan biarkan IndonesianTextProcessor yang membersihkan
    final message = _messages[index];
    final textToSpeak = message.ttsText ?? text;

    debugPrint('[TTS Provider] Memulai bicara untuk pesan ke-$index');

    try {
      await _tts.speak(textToSpeak);
    } catch (e) {
      debugPrint('[TTS Provider] Exception dari speak(): $e');
      _speakingMessageIndex = null;
      _isTtsPaused = false;
      notifyListeners();
    }
  }

  /// Jeda pemutaran suara
  Future<void> pauseSpeaking() async {
    if (_speakingMessageIndex != null && !_isTtsPaused) {
      await _tts.pause();
      _isTtsPaused = true;
      notifyListeners();
    }
  }

  /// Lanjutkan pemutaran suara dari posisi terakhir
  Future<void> resumeSpeaking() async {
    if (_speakingMessageIndex != null && _isTtsPaused) {
      await _tts.resume();
      _isTtsPaused = false;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _speakingMessageIndex = null;
    _isTtsPaused = false;
    notifyListeners();
  }

  void _clearLoadingForSession(String sessionId) {
    if (_loadingSessionId != sessionId) return;
    _loadingSessionId = null;
    _activeRequestToken = null;
    _isLoading = false;
  }

  Future<void> _saveAssistantMessage(
    String sessionId,
    String text, {
    String? ttsText,
  }) async {
    final wasSaved = await DatabaseHelper.instance.insertChatIfSessionExists(
      sessionId,
      text,
      true,
      ttsText: ttsText,
    );
    if (!wasSaved) return;

    if (_sessionId == sessionId) {
      _messages.add(
        ChatMessage(
          text: text,
          ttsText: ttsText,
          isBot: true,
          time: DateTime.now(),
          isAnimated: false,
        ),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading || _sessionId.isEmpty) return;

    final requestSessionId = _sessionId;
    final requestToken = ++_requestTokenSequence;
    final isDraftSession = !_isSessionPersisted;
    final fallbackTitle = _generateConversationTitle.fallback(
      userMessage: text,
    );
    var requestSessionPersisted = !isDraftSession;
    ChatMessage? optimisticUserMessage;

    _isLoading = true;
    _loadingSessionId = requestSessionId;
    _activeRequestToken = requestToken;
    _suggestions = [];
    notifyListeners();

    try {
      // Add and save the user message before requesting a response.
      if (isDraftSession) _messages.clear();
      final userMsg = ChatMessage(
        text: text,
        isBot: false,
        time: DateTime.now(),
        isAnimated: false,
      );
      optimisticUserMessage = userMsg;
      _messages.add(userMsg);
      final messagesForRequest = List<ChatMessage>.of(_messages);

      if (isDraftSession) {
        // Buat judul langsung secara lokal dari pesan pertama user
        await DatabaseHelper.instance.insertSessionWithFirstMessage(
          requestSessionId,
          fallbackTitle,
          text,
        );
        requestSessionPersisted = true;
        if (_sessionId == requestSessionId) {
          _isSessionPersisted = true;
        }
        await loadSessions();
      } else {
        final wasSaved = await DatabaseHelper.instance
            .insertChatIfSessionExists(requestSessionId, text, false);
        if (!wasSaved) {
          throw StateError('Chat session was deleted before sending');
        }
      }

      await _generateAndSaveBotResponse(
        requestSessionId,
        text,
        messagesForRequest,
        isDraftSession,
      );
    } catch (e) {
      log('Failed to send message in session $requestSessionId: $e');
      const errorResponse =
          'Maaf, terjadi kesalahan sistem. Silakan coba lagi nanti.';

      if (isDraftSession && requestSessionPersisted) {
        unawaited(
          _resolveConversationTitleFallback(
            sessionId: requestSessionId,
            expectedFallbackTitle: fallbackTitle,
          ),
        );
      }

      if (requestSessionPersisted) {
        try {
          await _saveAssistantMessage(requestSessionId, errorResponse);
        } catch (persistenceError) {
          log(
            'Failed to save error response for session $requestSessionId: '
            '$persistenceError',
          );
          if (_sessionId == requestSessionId) {
            _messages.add(
              ChatMessage(
                text: errorResponse,
                isBot: true,
                time: DateTime.now(),
                isAnimated: false,
              ),
            );
          }
        }
      } else {
        if (_sessionId == requestSessionId) {
          if (optimisticUserMessage != null) {
            _messages.remove(optimisticUserMessage);
          }
          _messages.add(
            ChatMessage(
              text: errorResponse,
              isBot: true,
              time: DateTime.now(),
              isAnimated: false,
            ),
          );
        }
      }
    } finally {
      if (_activeRequestToken == requestToken) {
        _loadingSessionId = null;
        _activeRequestToken = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Edit prompt user pada [index], hapus respons AI lama setelahnya, dan generate respons baru.
  Future<void> editMessageAndRegenerate(int index, String newText) async {
    if (newText.trim().isEmpty || _isLoading || _sessionId.isEmpty) return;
    if (index < 0 || index >= _messages.length || _messages[index].isBot) {
      return;
    }

    final requestSessionId = _sessionId;
    final requestToken = ++_requestTokenSequence;

    await stopSpeaking();

    // 1. Update pesan user pada index tersebut
    final updatedUserMsg = ChatMessage(
      text: newText.trim(),
      isBot: false,
      time: DateTime.now(),
      isAnimated: false,
    );

    // 2. Hapus respons lama AI dan pesan sesudahnya
    _messages.removeRange(index, _messages.length);
    _messages.add(updatedUserMsg);

    // 3. Jika ini pesan pertama user, perbarui judul sesi
    final isFirstUserMessage = !_messages.take(index).any((m) => !m.isBot);
    if (isFirstUserMessage) {
      final newTitle = _generateConversationTitle.fallback(
        userMessage: newText.trim(),
      );
      await DatabaseHelper.instance.updateSessionTitle(
        _sessionId,
        newTitle,
        false,
      );
      await loadSessions();
    }

    // 4. Update database dengan riwayat yang telah dipotong
    await DatabaseHelper.instance.replaceChatHistory(
      _sessionId,
      _messages
          .map(
            (m) => {
              'text': m.text,
              'tts_text': m.ttsText,
              'is_bot': m.isBot ? 1 : 0,
              'timestamp': m.time.toIso8601String(),
            },
          )
          .toList(),
    );

    // 5. Generate respons AI baru
    _isLoading = true;
    _loadingSessionId = requestSessionId;
    _activeRequestToken = requestToken;
    _suggestions = [];
    notifyListeners();

    try {
      final messagesForRequest = List<ChatMessage>.of(_messages);
      await _generateAndSaveBotResponse(
        requestSessionId,
        newText.trim(),
        messagesForRequest,
        isFirstUserMessage,
      );
    } catch (e) {
      log('Failed to generate response after edit: $e');
      const errorResponse =
          'Maaf, terjadi kesalahan sistem. Silakan coba lagi nanti.';
      await _saveAssistantMessage(requestSessionId, errorResponse);
      if (isFirstUserMessage) {
        unawaited(
          _resolveConversationTitleFallback(
            sessionId: requestSessionId,
            expectedFallbackTitle: _generateConversationTitle.fallback(
              userMessage: newText.trim(),
            ),
          ),
        );
      }
    } finally {
      if (_activeRequestToken == requestToken) {
        _loadingSessionId = null;
        _activeRequestToken = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Regenerate respons AI pada [assistantIndex].
  Future<void> regenerateResponse(int assistantIndex) async {
    if (_isLoading || _sessionId.isEmpty) return;
    if (assistantIndex < 0 ||
        assistantIndex >= _messages.length ||
        !_messages[assistantIndex].isBot) {
      return;
    }

    // Cari prompt user sebelum respons bot ini
    final userIndex = assistantIndex - 1;
    if (userIndex < 0 || _messages[userIndex].isBot) return;

    final userPrompt = _messages[userIndex].text;
    final requestSessionId = _sessionId;
    final requestToken = ++_requestTokenSequence;

    await stopSpeaking();

    // Hapus respons AI lama dan pesan setelahnya
    _messages.removeRange(assistantIndex, _messages.length);
    final isFirstUserResponse = !_messages
        .take(userIndex)
        .any((message) => !message.isBot);

    // Simpan history yang dipotong ke DB
    await DatabaseHelper.instance.replaceChatHistory(
      _sessionId,
      _messages
          .map(
            (m) => {
              'text': m.text,
              'tts_text': m.ttsText,
              'is_bot': m.isBot ? 1 : 0,
              'timestamp': m.time.toIso8601String(),
            },
          )
          .toList(),
    );

    _isLoading = true;
    _loadingSessionId = requestSessionId;
    _activeRequestToken = requestToken;
    _suggestions = [];
    notifyListeners();

    try {
      final messagesForRequest = List<ChatMessage>.of(_messages);
      await _generateAndSaveBotResponse(
        requestSessionId,
        userPrompt,
        messagesForRequest,
        isFirstUserResponse,
      );
    } catch (e) {
      log('Failed to regenerate response: $e');
      const errorResponse =
          'Maaf, terjadi kesalahan sistem. Silakan coba lagi nanti.';
      await _saveAssistantMessage(requestSessionId, errorResponse);
      if (isFirstUserResponse) {
        unawaited(
          _resolveConversationTitleFallback(
            sessionId: requestSessionId,
            expectedFallbackTitle: _generateConversationTitle.fallback(
              userMessage: userPrompt,
            ),
          ),
        );
      }
    } finally {
      if (_activeRequestToken == requestToken) {
        _loadingSessionId = null;
        _activeRequestToken = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Helper untuk memproses respons bot (Quick actions atau AI LLM)
  Future<void> _generateAndSaveBotResponse(
    String requestSessionId,
    String text,
    List<ChatMessage> messagesForRequest,
    bool generateTitle,
  ) async {
    final fallbackTitle = _generateConversationTitle.fallback(
      userMessage: text,
    );

    Future<void> saveResponse(String response, {String? ttsText}) async {
      await _saveAssistantMessage(requestSessionId, response, ttsText: ttsText);
      if (generateTitle) {
        unawaited(
          _generateAndPersistConversationTitle(
            sessionId: requestSessionId,
            userMessage: text,
            assistantMessage: response,
            expectedFallbackTitle: fallbackTitle,
          ),
        );
      }
    }

    final String lowerText = text.toLowerCase().trim();
    if (lowerText == 'informasi kontak') {
      await Future.delayed(const Duration(milliseconds: 600));
      final displayResponse = '''📞 **Layanan 24 Jam RS Prima Insan Mulia:**
- **Informasi & Pendaftaran:** 0815 1100 0600
- **IGD (Gawat Darurat):** 0856 4507 7831
- **Humas / HC:** 0856 4507 7830
- **Call Center:** 0283 847 3333
- **Email:** primainsan2021@gmail.com''';
      const ttsResponse =
          'Layanan 24 jam Rumah Sakit Prima Insan Mulia. '
          'Informasi dan Pendaftaran: kosong delapan satu lima, satu satu kosong kosong, kosong enam kosong kosong. '
          'I G D Gawat Darurat: kosong delapan lima enam, empat lima kosong tujuh, tujuh delapan tiga satu. '
          'Humas atau H C: kosong delapan lima enam, empat lima kosong tujuh, tujuh delapan tiga kosong. '
          'Call Center: kosong dua delapan tiga, delapan empat tujuh tiga tiga tiga.';
      await saveResponse(displayResponse, ttsText: ttsResponse);
      if (_sessionId == requestSessionId) {
        _suggestions = ['Lokasi RS', 'Jadwal Dokter', 'Kembali'];
      }
      unawaited(_tts.pregenerate(ttsResponse));
      return;
    } else if (lowerText == 'lokasi rs') {
      await Future.delayed(const Duration(milliseconds: 600));
      const displayResponse =
          '📍 **Lokasi RS Prima Insan Mulia:**\n'
          '[Jln. Raya Losari Lor, Kec. Losari, Kab. Brebes, Jawa Tengah, Indonesia]'
          '(https://www.google.com/maps/search/?api=1&query=RS+Prima+Insan+Mulia+Losari+Brebes)';
      const ttsResponse =
          'Lokasi Rumah Sakit Prima Insan Mulia: '
          'Jalan Raya Losari Lor, Kecamatan Losari, Kabupaten Brebes, Jawa Tengah, Indonesia.';
      await saveResponse(displayResponse, ttsText: ttsResponse);
      if (_sessionId == requestSessionId) {
        _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'];
      }
      unawaited(_tts.pregenerate(ttsResponse));
      return;
    } else if (lowerText == 'jadwal poliklinik') {
      await Future.delayed(const Duration(milliseconds: 600));
      final response =
          '''Berikut adalah layanan Poliklinik yang tersedia di RS Prima Insan Mulia:
1. **Spesialis Anak**
2. **Spesialis Bedah**
3. **Spesialis Kandungan (Obsgyn)**
4. **Spesialis Penyakit Dalam**
5. **Poli Umum**
6. **Poli VCT**

Silakan pilih pintasan di bawah ini atau ketik poli mana yang jadwalnya ingin Anda ketahui.''';
      await saveResponse(response);
      if (_sessionId == requestSessionId) {
        _suggestions = [
          'Jadwal Poli Anak',
          'Jadwal Poli Bedah',
          'Jadwal Kandungan',
          'Jadwal Penyakit Dalam',
          'Poli Umum',
          'Poli VCT',
        ];
      }
      unawaited(_tts.pregenerate(response));
      return;
    }

    // AI Response
    final history = messagesForRequest
        .where((message) => message.text.isNotEmpty)
        .take(messagesForRequest.length - 1)
        .toList();

    final lastMessages = history.length > 5
        ? history.sublist(history.length - 5)
        : history;

    final List<Map<String, String>> aiHistory = lastMessages
        .map((m) => {'role': m.isBot ? 'assistant' : 'user', 'content': m.text})
        .toList();

    final response = await _getBotResponse.execute(text, aiHistory);
    await saveResponse(response);
    unawaited(_tts.pregenerate(response));

    if (_sessionId == requestSessionId) {
      _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'];
    }
  }

  Future<void> _generateAndPersistConversationTitle({
    required String sessionId,
    required String userMessage,
    required String assistantMessage,
    required String expectedFallbackTitle,
  }) async {
    try {
      final title = await _generateConversationTitle.execute(
        userMessage: userMessage,
        assistantMessage: assistantMessage,
      );
      if (title == null) {
        await _resolveConversationTitleFallback(
          sessionId: sessionId,
          expectedFallbackTitle: expectedFallbackTitle,
        );
        return;
      }

      final wasUpdated = await DatabaseHelper.instance
          .updateGeneratedSessionTitleIfPending(
            sessionId,
            expectedFallbackTitle,
            title,
          );
      if (wasUpdated > 0) await loadSessions();
    } catch (error, stackTrace) {
      log(
        'Failed to generate conversation title for $sessionId',
        error: error,
        stackTrace: stackTrace,
      );
      await _resolveConversationTitleFallback(
        sessionId: sessionId,
        expectedFallbackTitle: expectedFallbackTitle,
      );
    }
  }

  Future<void> _resolveConversationTitleFallback({
    required String sessionId,
    required String expectedFallbackTitle,
  }) async {
    try {
      final wasUpdated = await DatabaseHelper.instance
          .resolveSessionTitleFallbackIfPending(
            sessionId,
            expectedFallbackTitle,
          );
      if (wasUpdated > 0) await loadSessions();
    } catch (error, stackTrace) {
      log(
        'Failed to resolve fallback title for $sessionId',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> clearChat() async {
    await stopSpeaking();
    await DatabaseHelper.instance.deleteAllSessions();
    _messages.clear();
    _sessions.clear();
    await startNewChat();
  }
}
