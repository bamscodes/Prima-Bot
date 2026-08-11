import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import '../../../services/edge_tts_service.dart';
import '../../data/datasources/local_datasource.dart';
import '../../domain/usecases/get_bot_response.dart';

class ChatMessage {
  final String text;     // Teks untuk ditampilkan di UI (bisa berisi markdown/link)
  final String? ttsText; // Teks khusus untuk TTS (tanpa markdown, plain text). Jika null, gunakan text.
  final bool isBot;
  final DateTime time;

  ChatMessage({
    required this.text,
    this.ttsText,
    required this.isBot,
    required this.time,
  });
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final GetBotResponse _getBotResponse = GetBotResponse();
  final String _sessionId = "user_anonymous_001"; // In real app, store this in secure storage
  final EdgeTtsService _tts = EdgeTtsService();
  
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
            ttsText: item['tts_text'],
            isBot: item['is_bot'] == 1,
            time: DateTime.parse(item['timestamp']),
          ));
        }
      }
    } catch (e) {
      log('Failed to load history: $e');
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
    // Pasang callback handler SEBELUM init agar tidak terlewat
    _tts.setStartHandler(() {
      debugPrint('[TTS Provider] Suara mulai diputar');
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      debugPrint('[TTS Provider] Suara selesai diputar');
      _speakingMessageIndex = null;
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      debugPrint('[TTS Provider] Suara dibatalkan');
      _speakingMessageIndex = null;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      debugPrint('[TTS Provider] Error saat memutar suara: $msg');
      _speakingMessageIndex = null;
      notifyListeners();
    });

    // Inisialisasi setelah handler terpasang
    await _tts.init();
    debugPrint('[TTS Provider] TTS service siap digunakan');
  }

  Future<void> speak(String text, int index) async {
    if (_speakingMessageIndex != null) {
      await _tts.stop();
      // Beri jeda agar handler cancel selesai sebelum mulai yang baru
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _speakingMessageIndex = index;
    notifyListeners();

    // Gunakan ttsText jika tersedia (teks bersih tanpa markdown/link),
    // jika tidak ada, kirim teks asli dan biarkan IndonesianTextProcessor yang membersihkan
    final message = _messages[index];
    final textToSpeak = message.ttsText ?? text;

    debugPrint('[TTS Provider] Memulai bicara untuk pesan ke-$index');

    // Jalankan speak dan tangkap error agar state tidak stuck
    try {
      await _tts.speak(textToSpeak);
    } catch (e) {
      debugPrint('[TTS Provider] Exception dari speak(): $e');
      _speakingMessageIndex = null;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
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
        await Future.delayed(const Duration(milliseconds: 600));
        // Teks untuk ditampilkan di UI (format markdown)
        final displayResponse = '''📞 **Layanan 24 Jam RS Prima Insan Mulia:**
- **Informasi & Pendaftaran:** 0815 1100 0600
- **IGD (Gawat Darurat):** 0856 4507 7831
- **Humas / HC:** 0856 4507 7830
- **Call Center:** 0283 847 3333
- **Email:** primainsan2021@gmail.com''';
        // Teks plain untuk TTS (tanpa emoji, angka dieja, awalan 0 → kosong)
        const ttsResponse = 'Layanan 24 jam Rumah Sakit Prima Insan Mulia. '
            'Informasi dan Pendaftaran: kosong delapan satu lima, satu satu kosong kosong, kosong enam kosong kosong. '
            'I G D Gawat Darurat: kosong delapan lima enam, empat lima kosong tujuh, tujuh delapan tiga satu. '
            'Humas atau H C: kosong delapan lima enam, empat lima kosong tujuh, tujuh delapan tiga kosong. '
            'Call Center: kosong dua delapan tiga, delapan empat tujuh tiga tiga tiga.';
        _messages.add(ChatMessage(text: displayResponse, ttsText: ttsResponse, isBot: true, time: DateTime.now()));
        await DatabaseHelper.instance.insertChat(_sessionId, displayResponse, true, ttsText: ttsResponse);
        _suggestions = ['Lokasi RS', 'Jadwal Dokter', 'Kembali'];
        // Pre-generate audio TTS di background agar playback lebih cepat
        unawaited(_tts.pregenerate(ttsResponse));
        return;
      } else if (lowerText == 'lokasi rs') {
        await Future.delayed(const Duration(milliseconds: 600));
        // Teks untuk ditampilkan di UI (ada link Google Maps yang bisa diklik)
        const displayResponse = '📍 **Lokasi RS Prima Insan Mulia:**\n'
            '[Jln. Raya Losari Lor, Kec. Losari, Kab. Brebes, Jawa Tengah, Indonesia]'
            '(https://www.google.com/maps/search/?api=1&query=RS+Prima+Insan+Mulia+Losari+Brebes)';
        // Teks plain untuk TTS (tanpa emoji, tanpa link URL)
        const ttsResponse = 'Lokasi Rumah Sakit Prima Insan Mulia: '
            'Jalan Raya Losari Lor, Kecamatan Losari, Kabupaten Brebes, Jawa Tengah, Indonesia.';
        _messages.add(ChatMessage(text: displayResponse, ttsText: ttsResponse, isBot: true, time: DateTime.now()));
        await DatabaseHelper.instance.insertChat(_sessionId, displayResponse, true, ttsText: ttsResponse);
        _suggestions = ['Jadwal Poliklinik', 'Informasi Kontak', 'Kembali'];
        // Pre-generate audio TTS di background agar playback lebih cepat
        unawaited(_tts.pregenerate(ttsResponse));
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
        // Pre-generate audio di background
        unawaited(_tts.pregenerate(response));
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

      // Ambil respons dari bot
      final response = await _getBotResponse.execute(text, aiHistory);

      _messages.add(ChatMessage(
        text: response,
        isBot: true,
        time: DateTime.now(),
      ));
      await DatabaseHelper.instance.insertChat(_sessionId, response, true);

      // Pre-generate audio TTS di background agar playback lebih cepat saat user tap play
      unawaited(_tts.pregenerate(response));

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
    // Hentikan TTS yang sedang berjalan sebelum menghapus pesan
    await stopSpeaking();
    await DatabaseHelper.instance.deleteChatHistory(_sessionId);
    _messages.clear();
    // Muat ulang greeting awal
    await _loadHistory();
    notifyListeners();
  }
}
