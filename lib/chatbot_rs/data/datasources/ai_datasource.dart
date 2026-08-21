import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static const _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _freeModels = [
    'openrouter/free',
    'google/gemini-2.5-pro:free',
    'meta-llama/llama-3-8b-instruct:free',
    'mistralai/mistral-7b-instruct:free',
    'google/gemma-7b-it:free',
  ];

  // Loaded from the app environment. For production, move this request to a
  // server-side proxy so the key is not bundled in the client application.
  static String get _openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static bool get _hasOpenRouterKey =>
      _openRouterApiKey.isNotEmpty &&
      _openRouterApiKey != 'YOUR_OPENROUTER_API_KEY';

  // The former Hugging Face endpoint was a base IndoBERT model, not an intent
  // classifier. Treating every HTTP 200 as `Cari_Jadwal` misrouted general
  // questions. Keep this deterministic and local until a trained intent model
  // and its label mapping are available.
  static Future<Map<String, dynamic>> classifyIntent(String text) {
    return Future.value(_simulateIntent(text));
  }

  // OpenRouter Text Generation with fallback and memory
  static Future<String> generateResponse(
    List<Map<String, String>> messages,
  ) async {
    if (!_hasOpenRouterKey) {
      return 'Maaf, saya sedang offline (API Key tidak ditemukan).';
    }

    final systemPrompt = {
      'role': 'system',
      'content': '''Anda adalah asisten ramah RS Prima Insan Mulia.
TUGAS UTAMA:
1. Jawab pertanyaan pasien HANYA berdasarkan data yang diberikan.
2. Jika data tidak ditemukan, katakan dengan sopan bahwa informasi tersebut belum tersedia atau sarankan untuk menghubungi pendaftaran.
3. JANGAN berhalusinasi atau membuat-buat jadwal dokter.
4. JANGAN memberikan saran medis yang spesifik (diagnosis atau obat). Sarankan pasien untuk berkonsultasi dengan dokter.
5. Gunakan Bahasa Indonesia yang sopan dan profesional.''',
    };

    final content = await _requestCompletion([
      systemPrompt,
      ...messages,
    ], models: _freeModels);

    return content ??
        'Maaf, semua layanan AI kami sedang padat. Silakan coba lagi beberapa saat lagi.';
  }

  /// Produces a compact, human-readable title after the first AI answer is
  /// available. This runs separately from the chat response so it never
  /// delays rendering the answer to the user.
  static Future<String?> generateConversationTitle({
    required String userMessage,
    required String assistantMessage,
  }) {
    if (!_hasOpenRouterKey) return Future.value(null);

    final userExcerpt = _excerpt(userMessage);
    final assistantExcerpt = _excerpt(assistantMessage);
    return _requestCompletion(
      [
        {
          'role': 'system',
          'content': '''Buat judul riwayat percakapan dalam Bahasa Indonesia.
Rangkum topik utama, bukan salin pembuka pesan pengguna. Gunakan 3-7 kata,
tanpa tanda kutip, tanpa awalan "Judul:", tanpa markdown, dan hanya tulis judul.''',
        },
        {
          'role': 'user',
          'content':
              'Pesan pengguna: $userExcerpt\n\nRespons asisten: $assistantExcerpt',
        },
      ],
      models: const ['openrouter/free', 'google/gemini-2.5-pro:free'],
      maxTokens: 24,
      temperature: 0.2,
    );
  }

  static String _excerpt(String value, {int maxLength = 600}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return normalized.substring(0, maxLength);
  }
  static Future<String?> _requestCompletion(
    List<Map<String, String>> messages, {
    required Iterable<String> models,
    int? maxTokens,
    double? temperature,
  }) async {
    for (final model in models) {
      try {
        final response = await http
            .post(
              Uri.parse(_openRouterUrl),
              headers: {
                'Authorization': 'Bearer $_openRouterApiKey',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://primabot.rs',
                'X-Title': 'Primabot',
              },
              body: jsonEncode({
                'model': model,
                'messages': messages,
                ...?maxTokens == null ? null : {'max_tokens': maxTokens},
                ...?temperature == null ? null : {'temperature': temperature},
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final choice = choices.first as Map<String, dynamic>;
          final message = choice['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content;
          }
        } else {
          log('Model $model failed: ${response.statusCode}');
        }
      } catch (e) {
        log('Error with model $model: $e');
      }
    }

    return null;
  }

  static Map<String, dynamic> _simulateIntent(String text) {
    final lowerText = text.toLowerCase();

    // Kata kunci untuk memicu pencarian jadwal
    bool isCariJadwal =
        lowerText.contains('jadwal') ||
        lowerText.contains('dokter') ||
        lowerText.contains('poli') ||
        lowerText.contains('kapan');

    String? entitas;
    if (lowerText.contains('anak')) {
      entitas = 'Anak';
    } else if (lowerText.contains('bedah')) {
      entitas = 'Bedah';
    } else if (lowerText.contains('kandungan') ||
        lowerText.contains('obsgyn') ||
        lowerText.contains('hamil')) {
      entitas = 'Kandungan';
    } else if (lowerText.contains('dalam') ||
        lowerText.contains('penyakit dalam')) {
      entitas = 'Penyakit Dalam';
    } else if (lowerText.contains('umum')) {
      entitas = 'Umum';
    } else if (lowerText.contains('vct') || lowerText.contains('hiv')) {
      entitas = 'VCT';
    } else if (lowerText.contains('gigi')) {
      entitas = 'Gigi'; // Retained just in case, though not in new schedule
    }

    if (isCariJadwal || entitas != null) {
      String? hari;
      if (lowerText.contains('besok')) {
        // Simple logic for "tomorrow"
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        hari = _getHariIndo(tomorrow.weekday);
      } else if (lowerText.contains('senin')) {
        hari = 'Senin';
      } else if (lowerText.contains('selasa')) {
        hari = 'Selasa';
      } else if (lowerText.contains('rabu')) {
        hari = 'Rabu';
      } else if (lowerText.contains('kamis')) {
        hari = 'Kamis';
      } else if (lowerText.contains('jumat')) {
        hari = 'Jumat';
      } else if (lowerText.contains('sabtu')) {
        hari = 'Sabtu';
      } else if (lowerText.contains('minggu')) {
        hari = 'Minggu';
      }

      return {'intent': 'Cari_Jadwal', 'entitas': entitas, 'hari': hari};
    }
    return {'intent': 'Umum'};
  }

  static String _getHariIndo(int weekday) {
    switch (weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return 'Senin';
    }
  }
}
