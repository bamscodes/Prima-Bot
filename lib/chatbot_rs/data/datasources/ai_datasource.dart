// ignore_for_file: use_null_aware_elements
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Layanan AI yang terhubung ke OpenRouter untuk generasi jawaban.
/// Telah diperkuat dengan prompt anti-halusinasi dan penanganan fallback yang robust.
class AIService {
  static const String _urlOpenRouter = 'https://openrouter.ai/api/v1/chat/completions';
  static const List<String> _modelGratis = [
    'openrouter/free',
    'google/gemini-2.5-pro:free',
    'meta-llama/llama-3-8b-instruct:free',
    'mistralai/mistral-7b-instruct:free',
    'google/gemma-7b-it:free',
  ];

  // API key dimuat dari environment. Untuk produksi sebaiknya dipindah ke server-side proxy
  // agar kunci tidak terbundle di aplikasi klien.
  static String get _kunciOpenRouter => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static bool get _adaKunciOpenRouter =>
      _kunciOpenRouter.isNotEmpty && _kunciOpenRouter != 'YOUR_OPENROUTER_API_KEY';

  /// Klasifikasi intent sederhana berbasis kata kunci lokal.
  /// Sengaja deterministik agar tidak salah mengarahkan pertanyaan umum ke alur jadwal.
  static Future<Map<String, dynamic>> classifyIntent(String teks) {
    return Future.value(_simulasiIntent(teks));
  }

  /// Generasi jawaban umum dari LLM dengan memori percakapan.
  /// Menggunakan prompt sistem yang ketat agar tidak berhalusinasi.
  static Future<String> generateResponse(
    List<Map<String, String>> daftarPesan,
  ) async {
    if (!_adaKunciOpenRouter) {
      return 'Maaf, saya sedang offline (API Key tidak ditemukan). Silakan hubungi pendaftaran di 0815 1100 0600.';
    }

    final Map<String, String> promptSistem = {
      'role': 'system',
      'content': '''Anda adalah Prima, asisten ramah RS Prima Insan Mulia.

ATURAN KETAT ANTI-HALUSINASI:
1. Jawab HANYA berdasarkan KONTEKS dan DATA RUMAH SAKIT yang diberikan di pesan pengguna. Jika konteks tidak menjawab, katakan: "Maaf, informasi tersebut belum tersedia di sistem kami. Silakan hubungi Informasi dan Pendaftaran di 0815 1100 0600 atau Call Center 0283 847 3333."
2. DILARANG mengarang jadwal, nama dokter, jam praktek, atau tarif yang tidak ada di data.
3. Jika menyebut jadwal, sebutkan persis nama dokter, hari, dan jam sesuai data dan beri sumber jika ada.
4. JANGAN memberikan diagnosis atau resep obat spesifik. Sarankan konsultasi langsung dengan dokter.
5. Gunakan HANYA Bahasa Indonesia baku, sopan, profesional. DILARANG menggunakan bahasa daerah.
6. Format daftar dengan jelas dan beri jeda natural antar poin.
7. Jika data jadwal kosong, jelaskan dengan sopan dan tawarkan bantuan lain.''',
    };

    final String? konten = await _mintaCompletion([
      promptSistem,
      ...daftarPesan,
    ], daftarModel: _modelGratis);

    return konten ??
        'Maaf, semua layanan AI kami sedang padat. Silakan coba lagi beberapa saat lagi atau hubungi pendaftaran di 0815 1100 0600.';
  }

  /// Generasi jawaban dengan konteks RAG yang sudah terkurasi.
  /// Konteks berisi hasil retrieval TF-IDF dari basis pengetahuan lokal.
  static Future<String> generateResponseDenganKonteks({
    required String pertanyaanPengguna,
    required String konteksTerkurasi,
    required List<Map<String, String>> riwayatPercakapan,
  }) async {
    if (!_adaKunciOpenRouter) {
      // Fallback akan ditangani di layer GetBotResponse
      return 'Maaf, saya sedang offline (API Key tidak ditemukan).';
    }

    final String promptKonteks = '''KONTEKS TERKURASI DARI BASIS PENGETAHUAN RS PRIMA INSAN MULIA:
$konteksTerkurasi

PERTANYAAN PASIEN: "$pertanyaanPengguna"

Instruksi: Jawab dengan ramah berdasarkan konteks di atas. Jika konteks tidak cukup, katakan informasi belum tersedia dan arahkan ke kontak resmi. Jangan mengarang.''';

    final List<Map<String, String>> pesanLengkap = [
      ...riwayatPercakapan,
      {'role': 'user', 'content': promptKonteks},
    ];

    final String? jawaban = await _mintaCompletion(
      [
        {
          'role': 'system',
          'content': '''Anda adalah Prima, asisten RS Prima Insan Mulia yang akurat dan anti-halusinasi.
ATURAN:
- Hanya jawab dari konteks yang diberikan. Jika tidak ada di konteks, katakan belum tersedia dan beri nomor kontak 0815 1100 0600.
- Jangan membuat jadwal dokter palsu. Sebutkan hanya yang ada di konteks.
- Bahasa Indonesia baku, sopan, jelas. Format daftar dengan nomor agar mudah dibaca TTS.
- Jika ragu, utamakan menyarankan hubungi pendaftaran.''',
        },
        ...pesanLengkap,
      ],
      daftarModel: _modelGratis,
      batasWaktu: const Duration(seconds: 12),
    );

    return jawaban ??
        'Maaf, layanan AI sedang padat. Silakan coba lagi atau hubungi pendaftaran di 0815 1100 0600.';
  }

  /// Menghasilkan judul percakapan yang ringkas setelah jawaban pertama tersedia.
  /// Berjalan terpisah dari respons chat sehingga tidak menunda render jawaban.
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
      daftarModel: const ['openrouter/free', 'google/gemini-2.5-pro:free'],
      maxTokens: 24,
      temperature: 0.2,
    );
  }

  static String _kutip(String nilai, {int panjangMaks = 600}) {
    final String normal = nilai.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normal.length <= panjangMaks) return normal;
    return normal.substring(0, panjangMaks);
  }

  /// Meminta completion ke OpenRouter dengan fallback antar model.
  static Future<String?> _mintaCompletion(
    List<Map<String, String>> daftarPesan, {
    required Iterable<String> daftarModel,
    int? maxTokens,
    double? temperature,
    Duration batasWaktu = const Duration(seconds: 8),
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
                if (maxTokens case final nilai?) 'max_tokens': nilai,
                if (temperature case final suhu?) 'temperature': suhu,
              }),
            )
            .timeout(batasWaktu);

        if (respons.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(respons.body) as Map<String, dynamic>;
          final List<dynamic>? daftarPilihan = data['choices'] as List<dynamic>?;
          if (daftarPilihan == null || daftarPilihan.isEmpty) continue;

          final Map<String, dynamic> pilihan = daftarPilihan.first as Map<String, dynamic>;
          final Map<String, dynamic>? pesan = pilihan['message'] as Map<String, dynamic>?;
          final String? konten = pesan?['content'] as String?;
          if (konten != null && konten.trim().isNotEmpty) {
            return konten;
          }
        } else {
          log('Model $model gagal: ${respons.statusCode} - ${respons.body}');
        }
      } catch (error) {
        log('Error model $model: $error');
      }
    }

    return null;
  }

  /// Simulasi intent berbasis kata kunci yang ringan dan deterministik.
  static Map<String, dynamic> _simulasiIntent(String teks) {
    final String teksLower = teks.toLowerCase();

    // Kata kunci untuk memicu pencarian jadwal
    final bool isCariJadwal =
        teksLower.contains('jadwal') ||
        teksLower.contains('dokter') ||
        teksLower.contains('poli') ||
        teksLower.contains('kapan') ||
        teksLower.contains('praktek') ||
        teksLower.contains('praktik');

    String? entitas;
    if (teksLower.contains('anak')) {
      entitas = 'Anak';
    } else if (teksLower.contains('bedah')) {
      entitas = 'Bedah';
    } else if (teksLower.contains('kandungan') ||
        teksLower.contains('obsgyn') ||
        teksLower.contains('hamil') ||
        teksLower.contains('kebidanan')) {
      entitas = 'Kandungan';
    } else if (teksLower.contains('penyakit dalam') || teksLower.contains('dalam')) {
      // Cek penyakit dalam sebelum dalam saja agar lebih spesifik
      if (teksLower.contains('penyakit dalam')) {
        entitas = 'Penyakit Dalam';
      } else if (teksLower.contains('dalam')) {
        entitas = 'Penyakit Dalam';
      }
    } else if (teksLower.contains('umum')) {
      entitas = 'Umum';
    } else if (teksLower.contains('vct') || teksLower.contains('hiv')) {
      entitas = 'VCT';
    } else if (teksLower.contains('gigi')) {
      entitas = 'Gigi';
    }

    if (isCariJadwal || entitas != null) {
      String? hari;
      if (teksLower.contains('besok')) {
        // Logika sederhana untuk besok
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
