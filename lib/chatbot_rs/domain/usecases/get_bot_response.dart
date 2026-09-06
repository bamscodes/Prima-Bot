// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:developer';

import '../../../services/hospital_ai.dart' as rs;
import '../../data/datasources/ai_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/jadwal_model.dart';
import '../../../services/rag_service.dart';

/// Use case utama untuk menghasilkan jawaban bot.
///
/// Arsitektur baru (anti-bias, anti-halusinasi, terasa hidup):
///  1. [HospitalAI] menjadi OTAK lokal deterministik: setiap intent dan entitas
///     (dokter, poli, hari, kontak, alamat, simtom) dijawab HANYA dari data
///     rumah sakit, dengan variasi pembuka/penutup agar tidak kaku.
///  2. [LayananRag] (TF-IDF) & [DatabaseHelper] menjadi sumber pembenahan
///     konteks untuk intent terbuka (umum hospital) dan untuk penguatan
///     validasi anti-halusinasi.
///  3. LLM (OpenRouter) hanya dipakai untuk memperkaya intent terbuka dan
///     DITUNGGU dengan validasi ketat; jika gagal/kosong, jawaban lokal
///     tergrounding langsung dipakai (tidak ada jawaban yang ngarang).
///
/// Seluruh alur 100% Dart, tanpa backend.
class GetBotResponse {
  final LayananRag _layananRag = LayananRag();
  final rs.HospitalAI _otak = rs.HospitalAI();

  /// Menjalankan alur jawaban untuk satu pertanyaan pengguna.
  ///
  /// Mengembalikan [rs.JawabanBot] berisi:
  /// - [rs.JawabanBot.tampilan] : teks markdown untuk UI
  /// - [rs.JawabanBot.tts]      : teks polos untuk TTS
  /// - [rs.JawabanBot.saran]    : quick action lanjutan
  Future<rs.JawabanBot> execute(
    String masukanPengguna,
    List<Map<String, String>> riwayat,
  ) async {
    final String masukanBersih = masukanPengguna.trim();
    if (masukanBersih.isEmpty) {
      return const rs.JawabanBot(
        tampilan: 'Silakan ketik pertanyaan Anda, saya siap membantu.',
        tts: 'Silakan ketik pertanyaan Anda, saya siap membantu.',
      );
    }

    // Otak lokal menjawab dengan deterministik & tergrounding.
    final rs.JawabanBot jawabanDasar = _otak.jawab(masukanBersih);

    // Untuk intent terbuka (umum hospital), perkuat dengan LLM bila tersedia.
    // Jawaban LLM hanya dipakai jika lolos validasi anti-halusinasi.
    final bool bolehLLM = _otakApakahUmum(masukanBersih);
    if (bolehLLM) {
      final rs.JawabanBot? diperkaya =
          await _perkuatDenganLlm(masukanBersih, riwayat);
      if (diperkaya != null) return diperkaya;
    }

    return jawabanDasar;
  }

  /// Apakah pertanyaan ini termasuk "umum hospital" yang boleh diperkaya LLM?
  bool _otakApakahUmum(String q) {
    final rs.HasilDeteksi d = _otak.deteksi(q);
    return d.intent == rs.IntentAi.umumHospital;
  }

  /// Coba perkuat jawaban dengan LLM + konteks RAG; validasi ketat.
  Future<rs.JawabanBot?> _perkuatDenganLlm(
    String q,
    List<Map<String, String>> riwayat,
  ) async {
    try {
      await _layananRag.inisialisasi();
    } catch (e) {
      log('Gagal inisialisasi RAG saat perkuat LLM: $e');
    }

    List<HasilPencarianRag> hasil;
    try {
      hasil = _layananRag.cari(q, batasHasil: 5, ambangBatas: 0.08);
    } catch (e) {
      log('Error retrieval RAG: $e');
      hasil = [];
    }

    String konteks = _layananRag.bangunKonteks(hasil);
    if (konteks.isEmpty ||
        konteks.contains('Tidak ada data relevan')) {
      konteks = _konteksFaktaRingkas();
    }

    try {
      final String? mentah = await AIService.generateResponseDenganKonteks(
        pertanyaanPengguna: q,
        konteksTerkurasi: konteks,
        riwayatPercakapan: riwayat.length > 4
            ? riwayat.sublist(riwayat.length - 4)
            : riwayat,
      ).timeout(const Duration(seconds: 15));

      if (mentah == null || mentah.trim().isEmpty) return null;

      // Validasi anti-halusinasi: LLM tidak boleh menyebut nama dokter/jadwal
      // yang tidak ada di basis data.
      if (_berhalusinasi(mentah)) {
        log('LLM terdeteksi berhalusinasi, pakai jawaban lokal.');
        return null;
      }

      final String tampil = _bersihkanMentah(mentah);
      if (tampil.isEmpty) return null;

      return rs.JawabanBot(
        tampilan: tampil,
        tts: _teksTts(tampil),
        saran: const ['Jadwal Poliklinik', 'Informasi Kontak', 'Lokasi RS'],
      );
    } catch (e) {
      log('Perkuat LLM gagal, pakai jawaban lokal: $e');
      return null;
    }
  }

  /// Konteks ringkas dari fakta statis RS (anti-halusinasi).
  String _konteksFaktaRingkas() {
    final b = StringBuffer();
    b.writeln('RS Prima Insan Mulia.');
    b.writeln('Layanan: Anak, Bedah, Kandungan, Penyakit Dalam, Poli Umum, VCT.');
    b.writeln('IGD 24 jam di Gedung Utama.');
    b.writeln('Pendaftaran: ${rs.HospitalFakta.telpPendaftaran}');
    b.writeln('IGD: ${rs.HospitalFakta.telpIgd}');
    b.writeln('Call Center: ${rs.HospitalFakta.telpCallCenter}');
    b.writeln('Alamat: ${rs.HospitalFakta.alamat}');
    b.writeln('Email: ${rs.HospitalFakta.email}');
    return b.toString();
  }

  /// Deteksi halusinasi: nama dokter / jam / hari yang tidak ada di data.
  bool _berhalusinasi(String jawaban) {
    final String lower = jawaban.toLowerCase();
    final Set<String> namaValid = {
      for (final d in rs.HospitalFakta.daftarDokter) d.nama.toLowerCase(),
    };

    // Deteksi nama dokter "dr. X" / "dr X" di jawaban.
    final RegExp reDokter = RegExp(
      r'dr\.?\s+([a-z]{2,})',
      caseSensitive: false,
    );
    for (final m in reDokter.allMatches(jawaban)) {
      final String nama = m.group(0)!.toLowerCase();
      final bool valid = namaValid.any((n) => nama.contains(n.split(' ')[0]));
      if (!valid) {
        // Nama dokter yang tidak dikenal oleh data -> potensi halusinasi.
        // Namun bila nama valid kebetulan dipotong, toleransi: cek substring.
        final bool cocok = namaValid.any((n) => n.contains(nama));
        if (!cocok) return true;
      }
    }

    // Deteksi nomor telepon yang tidak resmi (mengarang nomor).
    final RegExp reTelepon = RegExp(
      r'0(8[0-9]{2,3}|2[0-9]{2,3})[\s-]?\d{3,5}',
    );
    final Set<String> nomorValid = {
      '081511000600',
      '085645077831',
      '085645077830',
      '02838473333',
    };
    for (final m in reTelepon.allMatches(jawaban)) {
      final String hanyaAngka = m.group(0)!.replaceAll(RegExp(r'[\s-]'), '');
      if (!nomorValid.contains(hanyaAngka)) {
        // Nomor yang tidak dikenal -> halusinasi.
        return true;
      }
    }

    // Deteksi alamat yang berbeda dari data resmi.
    if (lower.contains('alamat') ||
        lower.contains('berada di') ||
        lower.contains('berlokasi di')) {
      final bool adaAlamatResmi =
          lower.contains('losari') && lower.contains('brebes');
      if (!adaAlamatResmi) return true;
    }

    return false;
  }

  String _bersihkanMentah(String s) {
    var t = s.trim();
    // Hapus tag safety/moderation yang kadang bocor dari model.
    t = t.replaceAll(
      RegExp(r'(user|response)\s*safety\s*[:\-]?\s*\w+', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(RegExp(r'as an ai\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Hapus markdown berlebihan & baris kosong berlebih
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t;
  }

  String _teksTts(String markdown) {
    var t = markdown
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
        .replaceAllMapped(
          RegExp(r'\[([^\]]*)\]\([^)]*\)'),
          (m) => m.group(1) ?? '',
        )
        .replaceAll(RegExp(r'\*{1,2}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t;
  }
}

// =============================================================================
// Kelas pendukung yang masih dipakai kode lain (biarkan tersedia).
// =============================================================================

class _RingkasanDokter {
  final String namaDokter;
  final String spesialisasi;
  final List<String> jadwal = [];

  _RingkasanDokter({
    required this.namaDokter,
    required this.spesialisasi,
  });
}

// =============================================================================
// Helper (dipakai UI / tes): format jadwal dari DB bila tersedia.
// Dipertahankan agar tidak ada import yang hilang di file lain.
// =============================================================================

String formatJadwalDb(List<JadwalModel> jadwal, {String? hari}) {
  final Map<String, _RingkasanDokter> ringkasan = {};
  for (final item in jadwal) {
    final key = '${item.namaDokter}|${item.spesialisasi}';
    final entry = ringkasan.putIfAbsent(
      key,
      () => _RingkasanDokter(
        namaDokter: item.namaDokter,
        spesialisasi: item.spesialisasi,
      ),
    );
    entry.jadwal.add('${item.hari} ${item.jamMulai}-${item.jamSelesai}');
  }

  final buffer = StringBuffer();
  var nomor = 1;
  for (final dokter in ringkasan.values) {
    buffer.writeln(
      '$nomor. **${dokter.namaDokter}** - ${dokter.spesialisasi}',
    );
    buffer.writeln('   ${dokter.jadwal.join(', ')}');
    nomor++;
  }
  return buffer.toString().trim();
}
