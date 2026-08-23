// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:developer';

import '../../../services/rag_service.dart';
import '../../data/datasources/ai_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/jadwal_model.dart';

/// Use case utama untuk menghasilkan jawaban bot dengan pendekatan RAG enterprise.
/// Menggabungkan retrieval TF-IDF lokal, query database jadwal, dan generasi LLM
/// dengan validasi anti-halusinasi. Seluruh proses 100 persen Dart dan gratis
/// kecuali pemanggilan OpenRouter yang memang memerlukan API key.
class GetBotResponse {
  final DatabaseHelper _bantuanDatabase = DatabaseHelper.instance;
  final LayananRag _layananRag = LayananRag();

  /// Daftar pola sapaan yang harus dijawab secara natural tanpa RAG.
  static final RegExp _polaSapaan = RegExp(
    r'^\s*(halo|hai|hey|hello|hi|assalamu\s*alaikum|selamat\s*(pagi|siang|sore|malam)|permisi|pagi|siang|sore|malam|apa\s*kabar)\b',
    caseSensitive: false,
  );

  /// Pola untuk mendeteksi pertanyaan di luar konteks RS (umum).
  static final RegExp _polaRs = RegExp(
    r'(rs|rumah sakit|prima|insan|mulia|dokter|jadwal|poli|spesialis|igd|vct|bedah|anak|kandungan|penyakit dalam|umum|layanan|kontak|lokasi|alamat|telepon|pendaftaran|bpjs|biaya|tarif|kamar|fasilitas|brebes|losari)',
    caseSensitive: false,
  );

  /// Menjalankan alur RAG lengkap untuk pertanyaan pengguna.
  /// [masukanPengguna] adalah pesan terbaru, [riwayat] berisi percakapan sebelumnya.
  Future<String> execute(String masukanPengguna, List<Map<String, String>> riwayat) async {
    final String masukanBersih = masukanPengguna.trim();
    if (masukanBersih.isEmpty) {
      return 'Silakan ketik pertanyaan Anda, saya siap membantu.';
    }

    // 0. Tangani sapaan secara langsung agar tidak kena fallback "informasi belum tersedia"
    if (_apakahSapaan(masukanBersih)) {
      return _jawabanSapaan(masukanBersih);
    }

    // Pastikan indeks RAG sudah siap (hanya build sekali seumur hidup aplikasi)
    try {
      await _layananRag.inisialisasi();
    } catch (error) {
      log('Gagal inisialisasi RAG: $error');
    }

    // 1. Klasifikasi intent sederhana untuk menentukan apakah perlu query jadwal presisi
    final Map<String, dynamic> dataIntent = await AIService.classifyIntent(masukanBersih);
    final String intent = (dataIntent['intent'] as String?) ?? 'Umum';
    final String? spesialisasi = dataIntent['entitas'] as String?;
    final String? hari = dataIntent['hari'] as String?;

    // 2. Retrieval RAG berbasis TF-IDF untuk konteks umum (layanan, kontak, lokasi, jadwal)
    List<HasilPencarianRag> hasilRetrieval = [];
    try {
      hasilRetrieval = _layananRag.cari(masukanBersih, batasHasil: 5, ambangBatas: 0.05);
      log('RAG retrieval: ${hasilRetrieval.length} dokumen untuk "$masukanBersih"');
      for (final hasil in hasilRetrieval) {
        log(' - [${hasil.dokumen.kategori}] skor ${hasil.skor.toStringAsFixed(3)}: ${hasil.dokumen.konten.substring(0, 60)}...');
      }
    } catch (error) {
      log('Error retrieval RAG: $error');
    }

    // 3. Jika intent jadwal, lakukan query presisi ke database lokal untuk grounding kuat
    String konteksJadwalPresisi = '';
    List<JadwalModel> daftarJadwal = [];
    if (intent == 'Cari_Jadwal') {
      if (spesialisasi != null) {
        try {
          daftarJadwal = await _bantuanDatabase.queryJadwal(spesialisasi, hari);
          if (daftarJadwal.isEmpty) {
            konteksJadwalPresisi =
                'DATA JADWAL PRESISI: Tidak ditemukan jadwal dokter $spesialisasi${hari != null ? ' pada hari $hari' : ''} di database lokal. Sampaikan dengan sopan bahwa jadwal tidak tersedia dan tawarkan untuk cek hari lain atau hubungi pendaftaran.';
          } else {
            final StringBuffer bufferJadwal = StringBuffer();
            bufferJadwal.writeln('DATA JADWAL PRESISI DARI DATABASE LOKAL (sumber paling terpercaya):');
            for (final jadwal in daftarJadwal) {
              bufferJadwal.writeln(
                '- ${jadwal.namaDokter} | Spesialisasi ${jadwal.spesialisasi} | Hari ${jadwal.hari} | Jam ${jadwal.jamMulai} sampai ${jadwal.jamSelesai}',
              );
            }
            konteksJadwalPresisi = bufferJadwal.toString();
          }
        } catch (error) {
          log('Error query jadwal: $error');
          konteksJadwalPresisi = 'DATA JADWAL PRESISI: Gagal mengakses database lokal. Gunakan konteks RAG saja.';
        }
      } else {
        // Spesialisasi tidak terdeteksi, biarkan LLM bertanya klarifikasi dengan bantuan konteks layanan
        konteksJadwalPresisi =
            'DATA JADWAL PRESISI: Spesialisasi tidak disebutkan. Tanyakan dengan sopan spesialisasi apa yang dicari (contoh: Anak, Bedah, Kandungan, Penyakit Dalam, Umum, VCT).';
      }
    }

    // 4. Bangun konteks terkurasi dari hasil retrieval
    String konteksTerkurasi = _layananRag.bangunKonteks(hasilRetrieval);
    if (konteksJadwalPresisi.isNotEmpty) {
      konteksTerkurasi = '$konteksTerkurasi\n\n$konteksJadwalPresisi';
    }

    // 5. Deteksi apakah pertanyaan di luar konteks RS (umum)
    final bool isPertanyaanRs = _polaRs.hasMatch(masukanBersih.toLowerCase()) || intent == 'Cari_Jadwal' || hasilRetrieval.isNotEmpty;
    if (!isPertanyaanRs) {
      // Pertanyaan umum di luar RS: jawab secara logis tanpa mengarang data RS
      try {
        final String jawabanUmum = await AIService.generateResponseDenganKonteks(
          pertanyaanPengguna: masukanBersih,
          konteksTerkurasi: 'Konteks RS tidak relevan untuk pertanyaan umum ini. Jawab secara umum dengan Bahasa Indonesia yang ramah, tetap tawarkan bantuan terkait RS jika diperlukan.',
          riwayatPercakapan: riwayat.length > 5 ? riwayat.sublist(riwayat.length - 5) : riwayat,
          modeUmum: true,
        ).timeout(const Duration(seconds: 30));
        final String? jawabanBersih = _saringJawabanSafety(jawabanUmum);
        if (jawabanBersih != null && jawabanBersih.trim().isNotEmpty) {
          return jawabanBersih;
        }
      } catch (error) {
        log('Error jawaban umum: $error');
      }
      // Fallback untuk pertanyaan umum jika LLM gagal
      return 'Terima kasih atas pertanyaannya. Saya adalah asisten RS Prima Insan Mulia yang fokus membantu informasi layanan rumah sakit. Untuk pertanyaan umum tersebut, saya sarankan mencari sumber terpercaya atau hubungi layanan kami di 0815 1100 0600 jika ada kaitannya dengan kesehatan.';
    }

    // 6. Siapkan riwayat yang relevan (ambil 5 pesan terakhir agar tidak terlalu panjang)
    final List<Map<String, String>> riwayatRelevan = riwayat.length > 5 ? riwayat.sublist(riwayat.length - 5) : riwayat;

    // 7. Coba generasi via LLM dengan konteks RAG dan filter safety
    try {
      final String jawabanLlmMentah = await AIService.generateResponseDenganKonteks(
        pertanyaanPengguna: masukanBersih,
        konteksTerkurasi: konteksTerkurasi,
        riwayatPercakapan: riwayatRelevan,
      ).timeout(const Duration(seconds: 45));

      // Saring output safety yang tidak diinginkan
      final String? jawabanLlm = _saringJawabanSafety(jawabanLlmMentah);
      if (jawabanLlm == null) {
        log('Jawaban LLM terdeteksi sebagai safety filter, fallback ke ekstraktif');
        return _jawabanFallbackEkstraktif(masukanBersih, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
      }

      // Validasi anti-halusinasi: cek apakah LLM mengarang jadwal
      final String? peringatanHalusinasi = _layananRag.validasiJawaban(jawabanLlm, hasilRetrieval);
      if (peringatanHalusinasi != null) {
        log('Peringatan halusinasi terdeteksi: $peringatanHalusinasi');
        if (intent == 'Cari_Jadwal' && daftarJadwal.isEmpty && hasilRetrieval.isEmpty) {
          return _jawabanFallbackEkstraktif(masukanBersih, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
        }
      }

      // Pastikan jawaban tidak kosong
      if (jawabanLlm.trim().isEmpty) {
        return _jawabanFallbackEkstraktif(masukanBersih, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
      }

      // Jika jawaban mengandung fallback generik padahal data ada, biarkan (LLM seharusnya sudah pakai data)
      return jawabanLlm;
    } catch (error, stackTrace) {
      log('Error generasi LLM: $error', stackTrace: stackTrace);
      // Fallback ke jawaban ekstraktif saat LLM gagal (offline, timeout, quota habis)
      return _jawabanFallbackEkstraktif(masukanBersih, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
    }
  }

  /// Mengecek apakah teks merupakan sapaan.
  bool _apakahSapaan(String teks) {
    final String teksLower = teks.toLowerCase().trim();
    // Jika teks sangat pendek dan cocok pola sapaan, anggap sapaan
    if (teksLower.length <= 30 && _polaSapaan.hasMatch(teksLower)) {
      return true;
    }
    // Jika teks hanya 1-2 kata sapaan
    final List<String> kataSapaan = ['halo', 'hai', 'hey', 'hello', 'hi', 'pagi', 'siang', 'sore', 'malam', 'assalamualaikum'];
    if (kataSapaan.contains(teksLower)) return true;
    // Jika diawali sapaan dan panjang masih pendek
    if (teksLower.split(' ').length <= 3 && _polaSapaan.hasMatch(teksLower)) return true;
    return false;
  }

  /// Jawaban sapaan yang ramah dan natural.
  String _jawabanSapaan(String sapaan) {
    final String sapaanLower = sapaan.toLowerCase();
    String salamWaktu = 'Halo';
    if (sapaanLower.contains('pagi')) salamWaktu = 'Selamat pagi';
    else if (sapaanLower.contains('siang')) salamWaktu = 'Selamat siang';
    else if (sapaanLower.contains('sore')) salamWaktu = 'Selamat sore';
    else if (sapaanLower.contains('malam')) salamWaktu = 'Selamat malam';
    else if (sapaanLower.contains('assalam')) return 'Waalaikumsalam! Ada yang bisa Prima bantu hari ini? Silakan tanya jadwal dokter, layanan poliklinik, atau lokasi RS.';
    else if (sapaanLower.contains('halo')) salamWaktu = 'Halo';
    else if (sapaanLower.contains('hai')) salamWaktu = 'Hai';

    return '$salamWaktu! Ada yang bisa Prima bantu hari ini? Anda bisa tanya jadwal dokter, informasi kontak, atau lokasi RS Prima Insan Mulia. Silakan pilih tombol cepat di bawah atau ketik pertanyaan Anda.';
  }

  /// Menyaring jawaban yang mengandung output safety moderation yang tidak diinginkan.
  /// Mengembalikan null jika terdeteksi sebagai safety filter agar bisa di-fallback.
  String? _saringJawabanSafety(String jawaban) {
    final String lower = jawaban.toLowerCase();
    // Deteksi pola safety yang sering muncul dari model moderation
    if (lower.contains('user safety') && lower.contains('response safety')) {
      log('Filter safety terdeteksi: User Safety / Response Safety');
      return null;
    }
    if (lower.contains('user safety: safe') || lower.contains('response safety: safe')) {
      return null;
    }
    // Jika jawaban hanya berisi tag safety tanpa konten bermakna
    if (RegExp(r'^\s*(user safety|response safety|safe)\s*[:\-]?\s*safe\s*$', caseSensitive: false).hasMatch(jawaban.trim())) {
      return null;
    }
    // Jika jawaban sangat pendek dan mengandung kata safe berulang (indikasi moderation)
    if (jawaban.trim().length < 50 && lower.contains('safe') && (lower.contains('user') || lower.contains('response'))) {
      return null;
    }
    return jawaban;
  }

  /// Menghasilkan jawaban fallback ekstraktif tanpa LLM.
  /// Digunakan saat offline, timeout, atau API key tidak tersedia.
  String _jawabanFallbackEkstraktif(
    String pertanyaan,
    List<HasilPencarianRag> hasilRag,
    List<JadwalModel> jadwalPresisi,
    String konteksJadwal,
  ) {
    // Jika ada data jadwal presisi, format langsung sebagai jawaban
    if (jadwalPresisi.isNotEmpty) {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('Berikut jadwal yang tersedia berdasarkan data rumah sakit:');
      buffer.writeln();
      for (int i = 0; i < jadwalPresisi.length; i++) {
        final JadwalModel jadwal = jadwalPresisi[i];
        buffer.writeln(
          '${i + 1}. **${jadwal.namaDokter}** - ${jadwal.spesialisasi} - Hari ${jadwal.hari}, Jam ${jadwal.jamMulai} sampai ${jadwal.jamSelesai}',
        );
      }
      buffer.writeln();
      buffer.writeln('Untuk pendaftaran hubungi 0815 1100 0600 atau Call Center 0283 847 3333.');
      return buffer.toString();
    }

    // Jika konteks jadwal menyatakan tidak ditemukan, sampaikan dengan sopan
    if (konteksJadwal.contains('Tidak ditemukan')) {
      final String pesanTidakDitemukan = konteksJadwal.replaceAll('DATA JADWAL PRESISI: ', '');
      return '$pesanTidakDitemukan\n\nSilakan coba hari lain atau hubungi pendaftaran di 0815 1100 0600 untuk informasi lebih lanjut.';
    }

    // Fallback umum via layanan RAG ekstraktif
    try {
      return _layananRag.jawabanEkstraktif(pertanyaan, hasilRag);
    } catch (_) {
      return 'Maaf, saya sedang mengalami kendala koneksi. Saat ini saya hanya bisa melayani pertanyaan seputar jadwal dokter yang tersimpan secara lokal. Silakan coba lagi atau hubungi pendaftaran di 0815 1100 0600.';
    }
  }
}
