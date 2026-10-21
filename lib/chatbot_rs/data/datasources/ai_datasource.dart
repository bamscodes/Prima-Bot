// ignore_for_file: use_null_aware_elements
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Layanan AI yang terhubung ke OpenRouter untuk generasi jawaban.
/// Dioptimalkan anti-RTO: hanya 2 model tercepat, cache, dan fallback langsung ke RAG ekstaktif
/// tanpa menampilkan "layanan AI sedang padat" ke user.
class AIService {
  static const String _urlOpenRouter = 'https://openrouter.ai/api/v1/chat/completions';
  // Daftar model gratis OpenRouter pilihan, dicoba berurutan dengan fallback cepat
  // agar tidak terjadi RTO beruntun dan pengguna tidak melihat pesan "layanan padat"
  static const List<String> _modelGratis = [
    'nvidia/nemotron-3-super-120b-a12b:free',
    'openrouter/free',
    'poolside/laguna-xs-2.1:free',
  ];

  // Cache sederhana untuk jawaban yang sudah pernah di-generate (hemat API dan anti RTO)
  static final Map<String, String> _cacheJawaban = {};
  static const int _maksCache = 50;

  // API key dimuat dari environment. Untuk produksi sebaiknya dipindah ke server-side proxy
  static String get _kunciOpenRouter => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static bool get _adaKunciOpenRouter =>
      _kunciOpenRouter.isNotEmpty && _kunciOpenRouter != 'YOUR_OPENROUTER_API_KEY';

  /// Klasifikasi intent sederhana berbasis kata kunci lokal.
  static Future<Map<String, dynamic>> classifyIntent(String teks) {
    return Future.value(_simulasiIntent(teks));
  }

  /// Generasi jawaban umum dari LLM dengan memori percakapan.
  /// Mengembalikan null jika gagal agar caller bisa fallback ke RAG ekstaktif (tidak menampilkan "padat" ke user).
  static Future<String?> generateResponse(
    List<Map<String, String>> daftarPesan,
  ) async {
    if (!_adaKunciOpenRouter) return null;

    // Cek cache dulu
    final String kunciCache = _buatKunciCache(daftarPesan);
    if (_cacheJawaban.containsKey(kunciCache)) {
      log('AI cache hit');
      return _cacheJawaban[kunciCache];
    }

    final Map<String, String> promptSistem = {
      'role': 'system',
      'content': '''Anda adalah Prima, asisten ramah RS Prima Insan Mulia.

ATURAN KETAT:
1. Jawab dengan Bahasa Indonesia baku, sopan, dan logis. Sapaan seperti halo, hai, selamat pagi harus dibalas dengan ramah tanpa mengatakan informasi belum tersedia.
2. Jika pertanyaan tentang RS (jadwal, dokter, poli, layanan, kontak, lokasi), jawab HANYA berdasarkan konteks yang diberikan. Jika tidak ada di konteks, katakan: "Maaf, informasi tersebut belum tersedia di sistem kami. Silakan hubungi Informasi dan Pendaftaran di 0815 1100 0600 atau Call Center 0283 847 3333."
3. Jika pertanyaan umum di luar RS (misal pengetahuan umum), jawab secara logis dan membantu dengan Bahasa Indonesia yang natural, tetap tawarkan bantuan terkait RS jika relevan.
4. DILARANG mengarang jadwal, nama dokter, atau tarif. DILARANG output tag seperti "User Safety" atau "Response Safety".
5. Format daftar dengan nomor dan beri jeda natural antar poin.''',
    };

    final String? konten = await _mintaCompletion([
      promptSistem,
      ...daftarPesan,
    ], daftarModel: _modelGratis, batasWaktu: const Duration(seconds: 10));

    if (konten == null) return null;
    final String? bersih = _saringOutputSafety(konten);
    if (bersih == null) return null;
    _simpanCache(kunciCache, bersih);
    return bersih;
  }

  /// Generasi jawaban dengan konteks RAG yang sudah terkurasi.
  /// Mengembalikan null jika gagal agar caller fallback ke jawaban ekstaktif lokal.
  static Future<String?> generateResponseDenganKonteks({
    required String pertanyaanPengguna,
    required String konteksTerkurasi,
    required List<Map<String, String>> riwayatPercakapan,
    bool modeUmum = false,
  }) async {
    if (!_adaKunciOpenRouter) return null;

    final String kunciCache = _buatKunciCache([
      {'role': 'user', 'content': pertanyaanPengguna},
      {'role': 'system', 'content': konteksTerkurasi}
    ]);
    if (_cacheJawaban.containsKey(kunciCache)) {
      log('AI konteks cache hit');
      return _cacheJawaban[kunciCache];
    }

    // Deteksi apakah pertanyaan adalah sapaan
    final bool isSapaan = _adalahSapaan(pertanyaanPengguna);

    String promptSistem;
    String promptKonteks;

    if (modeUmum) {
      promptSistem = '''Anda adalah Prima, asisten RS Prima Insan Mulia yang ramah dan cerdas.
- Jawab pertanyaan umum di luar RS secara logis, informatif, dengan Bahasa Indonesia baku.
- Tetap tawarkan bantuan terkait RS jika relevan di akhir jawaban.
- DILARANG output tag safety seperti "User Safety".''';
      promptKonteks = 'Pertanyaan umum pasien: "$pertanyaanPengguna"\n\nJawab secara logis dan membantu.';
    } else if (isSapaan) {
      promptSistem = '''Anda adalah Prima, asisten RS Prima Insan Mulia yang ramah.
- Balas sapaan dengan natural, hangat, dan tawarkan bantuan (jadwal dokter, layanan, lokasi).
- Jangan katakan informasi belum tersedia untuk sapaan.
- Bahasa Indonesia baku, sopan.''';
      promptKonteks = 'Sapaan pasien: "$pertanyaanPengguna"\n\nBalas dengan salam yang sesuai dan tawarkan bantuan.';
    } else {
      promptSistem = '''Anda adalah Prima, asisten RS Prima Insan Mulia yang akurat dan anti-halusinasi.

ATURAN KETAT:
- Jawab HANYA dari KONTEKS yang diberikan. Jika tidak ada di konteks, katakan: "Maaf, informasi tersebut belum tersedia di sistem kami. Silakan hubungi Informasi dan Pendaftaran di 0815 1100 0600 atau Call Center 0283 847 3333."
- Jangan membuat jadwal dokter palsu. Sebutkan hanya yang ada di konteks.
- Bahasa Indonesia baku, sopan, jelas. Format daftar dengan nomor agar mudah dibaca TTS.
- DILARANG output tag seperti "User Safety" atau "Response Safety".
- Jika ragu, utamakan menyarankan hubungi pendaftaran.''';
      promptKonteks = '''KONTEKS TERKURASI DARI BASIS PENGETAHUAN RS PRIMA INSAN MULIA:
$konteksTerkurasi

PERTANYAAN PASIEN: "$pertanyaanPengguna"

Instruksi: Jawab dengan ramah berdasarkan konteks di atas. Jika konteks tidak cukup, katakan informasi belum tersedia dan arahkan ke kontak resmi. Jangan mengarang.''';
    }

    final List<Map<String, String>> pesanLengkap = [
      ...riwayatPercakapan,
      {'role': 'user', 'content': promptKonteks},
    ];

    final String? jawaban = await _mintaCompletion(
      [
        {'role': 'system', 'content': promptSistem},
        ...pesanLengkap,
      ],
      daftarModel: _modelGratis,
      batasWaktu: const Duration(seconds: 10),
      maxTokens: modeUmum || isSapaan ? 300 : 600,
      temperature: 0.7,
    );

    if (jawaban == null) return null;
    final String? bersih = _saringOutputSafety(jawaban);
    if (bersih == null) return null;
    _simpanCache(kunciCache, bersih);
    return bersih;
  }

  /// Deteksi sapaan sederhana — hindari false positive "hai jadwal..."
  static bool _adalahSapaan(String teks) {
    final String lower = teks.toLowerCase().trim();
    // Jika mengandung kata jadwal/dokter/poli, bukan sapaan
    if (RegExp(r'\b(jadwal|dokter|poli|jadwal|spesialis|igd|vct)\b').hasMatch(lower)) return false;
    if (RegExp(r'^(halo|hai|hey|hello|hi|pagi|siang|sore|malam|assalamu alaikum|selamat|permisi)\b').hasMatch(lower)) {
      return true;
    }
    if (lower.length <= 20 && RegExp(r'\b(halo|hai|hey)\b').hasMatch(lower)) return true;
    return false;
  }

  /// Saring output yang mengandung tag safety moderation yang tidak diinginkan
  static String? _saringOutputSafety(String teks) {
    final String lower = teks.toLowerCase();
    if (lower.contains('user safety') && lower.contains('response safety')) return null;
    if (lower.contains('user safety: safe') || lower.contains('response safety: safe')) return null;
    if (RegExp(r'^\s*(user safety|response safety|safe)\s*[:\-]?\s*safe\s*$', caseSensitive: false).hasMatch(teks.trim())) return null;
    if (teks.trim().length < 60 && lower.contains('safe') && (lower.contains('user') || lower.contains('response'))) return null;
    // Filter tag moderation lain
    if (lower.contains('content policy') || lower.contains('as an ai') && lower.contains('cannot')) {
      // Biarkan tapi log, karena mungkin genuine refusal
    }
    return teks;
  }

  /// Menghasilkan judul percakapan yang ringkas
  static Future<String?> generateConversationTitle({
    required String userMessage,
    required String assistantMessage,
  }) {
    if (!_adaKunciOpenRouter) return Future.value(null);

    final String kutipanPengguna = _kutip(userMessage);
    final String kutipanAsisten = _kutip(assistantMessage);
    return _mintaCompletion(
      [
        {
          'role': 'system',
          'content': '''Buat judul riwayat percakapan dalam Bahasa Indonesia.
Rangkum topik utama, bukan salin pembuka pesan pengguna. Gunakan 3-7 kata,
tanpa tanda kutip, tanpa awalan "Judul:", tanpa markdown, dan hanya tulis judul.''',
        },
        {
          'role': 'user',
          'content': 'Pesan pengguna: $kutipanPengguna\n\nRespons asisten: $kutipanAsisten',
        },
      ],
      // Pembuatan judul cukup pakai model ringan yang sama agar konsisten dan hemat kuota
      daftarModel: const ['openrouter/free', 'nvidia/nemotron-3-super-120b-a12b:free'],
      maxTokens: 24,
      temperature: 0.2,
      batasWaktu: const Duration(seconds: 10),
    );
  }

  static String _kutip(String nilai, {int panjangMaks = 600}) {
    final String normal = nilai.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normal.length <= panjangMaks) return normal;
    return normal.substring(0, panjangMaks);
  }

  static String _buatKunciCache(List<Map<String, String>> pesan) {
    final String gabungan = pesan.map((m) => m['content'] ?? '').join('|');
    final bytes = utf8.encode(gabungan);
    return sha256.convert(bytes).toString();
  }

  static void _simpanCache(String kunci, String nilai) {
    if (_cacheJawaban.length >= _maksCache) {
      _cacheJawaban.remove(_cacheJawaban.keys.first);
    }
    _cacheJawaban[kunci] = nilai;
  }

  /// Meminta completion ke OpenRouter dengan fallback antar model dan penanganan RTO
  static Future<String?> _mintaCompletion(
    List<Map<String, String>> daftarPesan, {
    required Iterable<String> daftarModel,
    int? maxTokens,
    double? temperature,
    Duration batasWaktu = const Duration(seconds: 12),
  }) async {
    for (final String model in daftarModel) {
      try {
        final http.Response respons = await http
            .post(
              Uri.parse(_urlOpenRouter),
              headers: {
                'Authorization': 'Bearer $_kunciOpenRouter',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://primabot.rs',
                'X-Title': 'Primabot',
              },
              body: jsonEncode({
                'model': model,
                'messages': daftarPesan,
                if (maxTokens != null) 'max_tokens': maxTokens,
                if (temperature != null) 'temperature': temperature,
              }),
            )
            .timeout(batasWaktu);

        if (respons.statusCode == 200) {
          Map<String, dynamic> data;
          try {
            data = jsonDecode(respons.body) as Map<String, dynamic>;
          } catch (e) {
            log('Model $model: json decode gagal: $e');
            continue;
          }
          final List<dynamic>? daftarPilihan = data['choices'] as List<dynamic>?;
          if (daftarPilihan == null || daftarPilihan.isEmpty) {
            log('Model $model: choices kosong, coba model berikut');
            continue;
          }

          final Map<String, dynamic> pilihan = daftarPilihan.first as Map<String, dynamic>;
          final Map<String, dynamic>? pesan = pilihan['message'] as Map<String, dynamic>?;
          final String? konten = pesan?['content'] as String?;
          if (konten != null && konten.trim().isNotEmpty) {
            // Saring safety sebelum return
            final String? bersih = _saringOutputSafety(konten);
            if (bersih == null) {
              log('Model $model: output terfilter safety, coba model berikut');
              continue;
            }
            return bersih;
          } else {
            log('Model $model: konten kosong, coba berikut');
          }
        } else if (respons.statusCode == 429) {
          log('Model $model rate limit 429, coba model berikut');
          // Jeda singkat sebelum retry
          await Future.delayed(const Duration(milliseconds: 500));
        } else if (respons.statusCode >= 500) {
          log('Model $model server error ${respons.statusCode}, coba berikut');
        } else {
          final bodySnippet = respons.body.length > 200 ? respons.body.substring(0, 200) : respons.body;
          log('Model $model gagal: ${respons.statusCode} - $bodySnippet');
        }
      } on TimeoutException {
        log('Timeout model $model (${batasWaktu.inSeconds}s), lanjut ke model berikut');
      } catch (error) {
        log('Error model $model: $error (timeout ${batasWaktu.inSeconds}s)');
      }
      // Jeda kecil antar model untuk hindari rate limit
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return null;
  }

  /// Simulasi intent berbasis kata kunci yang ringan dan deterministik.
  static Map<String, dynamic> _simulasiIntent(String teks) {
    final String teksLower = teks.toLowerCase();

    final bool isCariJadwal =
        RegExp(r'\b(jadwal|dokter|poli|kapan|praktek|praktik)\b').hasMatch(teksLower);

    String? entitas;
    if (RegExp(r'\banak\b').hasMatch(teksLower)) {
      entitas = 'Anak';
    } else if (RegExp(r'\bbedah\b').hasMatch(teksLower)) {
      entitas = 'Bedah';
    } else if (RegExp(r'\b(kandungan|obsgyn|hamil|kebidanan)\b').hasMatch(teksLower)) {
      entitas = 'Kandungan';
    } else if (RegExp(r'\bpenyakit dalam\b').hasMatch(teksLower)) {
      entitas = 'Penyakit Dalam';
    } else if (RegExp(r'\b(umum)\b').hasMatch(teksLower)) {
      entitas = 'Umum';
    } else if (RegExp(r'\b(vct|hiv)\b').hasMatch(teksLower)) {
      entitas = 'VCT';
    } else if (RegExp(r'\bgigi\b').hasMatch(teksLower)) {
      entitas = 'Gigi';
    }

    if (isCariJadwal || entitas != null) {
      String? hari;
      if (teksLower.contains('besok')) {
        final DateTime besok = DateTime.now().add(const Duration(days: 1));
        hari = _hariIndo(besok.weekday);
      } else if (teksLower.contains('lusa')) {
        final DateTime lusa = DateTime.now().add(const Duration(days: 2));
        hari = _hariIndo(lusa.weekday);
      } else if (teksLower.contains('senin')) {
        hari = 'Senin';
      } else if (teksLower.contains('selasa')) {
        hari = 'Selasa';
      } else if (teksLower.contains('rabu')) {
        hari = 'Rabu';
      } else if (teksLower.contains('kamis')) {
        hari = 'Kamis';
      } else if (teksLower.contains('jumat')) {
        hari = 'Jumat';
      } else if (teksLower.contains('sabtu')) {
        hari = 'Sabtu';
      } else if (teksLower.contains('minggu')) {
        hari = 'Minggu';
      } else if (teksLower.contains('hari ini')) {
        hari = _hariIndo(DateTime.now().weekday);
      }

      return {'intent': 'Cari_Jadwal', 'entitas': entitas, 'hari': hari};
    }
    return {'intent': 'Umum'};
  }

  static String _hariIndo(int hariMinggu) {
    switch (hariMinggu) {
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
