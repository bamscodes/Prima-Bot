import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local_datasource.dart';
import '../../domain/usecases/get_bot_response.dart';

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.time,
  });
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final GetBotResponse _getBotResponse = GetBotResponse();
  final String _sessionId = "user_anonymous_001"; // In real app, store this in secure storage
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isLoading = false;
  int? _speakingMessageIndex;
  List<String> _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'];

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSpeaking => _speakingMessageIndex != null;
  int? get speakingMessageIndex => _speakingMessageIndex;
  String get sessionId => _sessionId;
  List<String> get suggestions => _suggestions;

  ChatProvider() {
    _initTts();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await DatabaseHelper.instance.getChatHistory(_sessionId);
      if (history.isEmpty) {
        // Initial greeting if no history
        final initialMessage = 'Halo! Selamat datang di **RS Prima Insan Mulia**. Ada yang bisa saya bantu hari ini?\n\nAnda bisa menanyakan jadwal dokter atau informasi layanan kami.';
        _messages.add(ChatMessage(
          text: initialMessage,
          isBot: true,
          time: DateTime.now(),
        ));
        await DatabaseHelper.instance.insertChat(_sessionId, initialMessage, true);
      } else {
        for (var item in history) {
          _messages.add(ChatMessage(
            text: item['text'],
            isBot: item['is_bot'] == 1,
            time: DateTime.parse(item['timestamp']),
          ));
        }
      }
    } catch (e) {
      print('Failed to load history: $e');
      // Fallback greeting if DB fails
      _messages.add(ChatMessage(
        text: 'Halo! Selamat datang di **RS Prima Insan Mulia**. (Koneksi database sedang disiapkan)',
        isBot: true,
        time: DateTime.now(),
      ));
    }
    notifyListeners();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("id-ID");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setStartHandler(() {
      // _speakingMessageIndex is set in speak() to avoid race conditions
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _speakingMessageIndex = null;
      notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _speakingMessageIndex = null;
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _speakingMessageIndex = null;
      notifyListeners();
    });
  }

  Future<void> speak(String text, int index) async {
    if (_speakingMessageIndex != null) {
      await _flutterTts.stop();
      // Memberi jeda sedikit agar CancelHandler dari suara lama tereksekusi duluan
      // sehingga tidak menimpa state _speakingMessageIndex yang baru.
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _speakingMessageIndex = index;
    notifyListeners();
    
    // Clean markdown before speaking
    final cleanText = text
        .replaceAll(RegExp(r'\*\*'), '') // Remove bold
        .replaceAll(RegExp(r'\*'), '')  // Remove italic/bullets
        .replaceAll(RegExp(r'#+ '), '')  // Remove headers
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)') , r'$1'); // Remove links but keep text
    
    await _flutterTts.speak(cleanText);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _speakingMessageIndex = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add and Save user message
    final userMsg = ChatMessage(
      text: text,
      isBot: false,
      time: DateTime.now(),
    );
    _messages.add(userMsg);
    await DatabaseHelper.instance.insertChat(_sessionId, text, false);
    
    _isLoading = true;
    _suggestions = []; 
    notifyListeners();

    try {
      // Check for exact Quick Action matches
      final String lowerText = text.toLowerCase().trim();
      if (lowerText == 'informasi kontak') {
        await Future.delayed(const Duration(milliseconds: 600)); // Simulate typing
        final response = '''📞 **Layanan 24 Jam RS Prima Insan Mulia:**
- **Informasi & Pendaftaran:** 0815 1100 0600
- **IGD (Gawat Darurat):** 0856 4507 7831
- **Humas / HC:** 0856 4507 7830
- **Call Center:** (0283) 847 3333
- **Email:** primainsan2021@gmail.com''';
        _messages.add(ChatMessage(text: response, isBot: true, time: DateTime.now()));
        await DatabaseHelper.instance.insertChat(_sessionId, response, true);
        _suggestions = ['Lokasi RS', 'Jadwal Dokter', 'Kembali'];
        return;
      } else if (lowerText == 'lokasi rs') {
        await Future.delayed(const Duration(milliseconds: 600));
        final response = '📍 **Lokasi RS Prima Insan Mulia:**\n[Jln. Raya Losari Lor, Kec. Losari, Kab. Brebes, Jawa Tengah, Indonesia](https://www.google.com/maps/search/?api=1&query=RS+Prima+Insan+Mulia+Losari+Brebes)';
        _messages.add(ChatMessage(text: response, isBot: true, time: DateTime.now()));
        await DatabaseHelper.instance.insertChat(_sessionId, response, true);
        _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'];
        return;
      } else if (lowerText == 'jadwal poliklinik') {
        await Future.delayed(const Duration(milliseconds: 600));
        final response = '''Berikut adalah layanan Poliklinik yang tersedia di RS Prima Insan Mulia:
1. **Spesialis Anak**
2. **Spesialis Bedah**
3. **Spesialis Kandungan (Obsgyn)**
4. **Spesialis Penyakit Dalam**
5. **Poli Umum**
6. **Poli VCT**

Silakan pilih pintasan di bawah ini atau ketik poli mana yang jadwalnya ingin Anda ketahui.''';
        _messages.add(ChatMessage(text: response, isBot: true, time: DateTime.now()));
        await DatabaseHelper.instance.insertChat(_sessionId, response, true);
        _suggestions = ['Jadwal Poli Anak', 'Jadwal Poli Bedah', 'Jadwal Kandungan', 'Jadwal Penyakit Dalam', 'Poli Umum', 'Poli VCT'];
        return;
      }

      // Prepare history for AI (last 5 messages)
      final history = _messages
          .where((m) => m.text.isNotEmpty)
          .take(_messages.length - 1) 
          .toList();
      
      final lastMessages = history.length > 5 
          ? history.sublist(history.length - 5) 
          : history;

      final List<Map<String, String>> aiHistory = lastMessages.map((m) => {
        'role': m.isBot ? 'assistant' : 'user',
        'content': m.text,
      }).toList();

      // Get bot response from use case
      final response = await _getBotResponse.execute(text, aiHistory);
      
      _messages.add(ChatMessage(
        text: response,
        isBot: true,
        time: DateTime.now(),
      ));
      await DatabaseHelper.instance.insertChat(_sessionId, response, true);

      _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'];
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Maaf, terjadi kesalahan sistem. Silakan coba lagi nanti.',
        isBot: true,
        time: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearChat() async {
    await DatabaseHelper.instance.deleteChatHistory(_sessionId);
    _messages.clear();
    // Re-load initial greeting
    await _loadHistory();
    notifyListeners();
  }
}
