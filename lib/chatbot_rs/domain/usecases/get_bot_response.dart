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

  /// Menjalankan alur RAG lengkap untuk pertanyaan pengguna.
  /// [masukanPengguna] adalah pesan terbaru, [riwayat] berisi percakapan sebelumnya.
  Future<String> execute(String masukanPengguna, List<Map<String, String>> riwayat) async {
    // Pastikan indeks RAG sudah siap (hanya build sekali seumur hidup aplikasi)
    try {
      await _layananRag.inisialisasi();
    } catch (error) {
      log('Gagal inisialisasi RAG: $error');
    }

    // 1. Klasifikasi intent sederhana untuk menentukan apakah perlu query jadwal presisi
    final Map<String, dynamic> dataIntent = await AIService.classifyIntent(masukanPengguna);
    final String intent = (dataIntent['intent'] as String?) ?? 'Umum';
    final String? spesialisasi = dataIntent['entitas'] as String?;
    final String? hari = dataIntent['hari'] as String?;

    // 2. Retrieval RAG berbasis TF-IDF untuk konteks umum (layanan, kontak, lokasi, jadwal)
    List<HasilPencarianRag> hasilRetrieval = [];
    try {
      hasilRetrieval = _layananRag.cari(masukanPengguna, batasHasil: 5, ambangBatas: 0.05);
      log('RAG retrieval: ${hasilRetrieval.length} dokumen untuk "$masukanPengguna"');
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

    // 5. Siapkan riwayat yang relevan (ambil 5 pesan terakhir agar tidak terlalu panjang)
    final List<Map<String, String>> riwayatRelevan = riwayat.length > 5 ? riwayat.sublist(riwayat.length - 5) : riwayat;

    // 6. Coba generasi via LLM dengan konteks RAG
    try {
      final String jawabanLlm = await AIService.generateResponseDenganKonteks(
        pertanyaanPengguna: masukanPengguna,
        konteksTerkurasi: konteksTerkurasi,
        riwayatPercakapan: riwayatRelevan,
      ).timeout(const Duration(seconds: 45));

      // Validasi anti-halusinasi: cek apakah LLM mengarang jadwal
      final String? peringatanHalusinasi = _layananRag.validasiJawaban(jawabanLlm, hasilRetrieval);
      if (peringatanHalusinasi != null) {
        log('Peringatan halusinasi terdeteksi: $peringatanHalusinasi');
        // Tidak memblokir jawaban, tapi log untuk observability
        // Jika daftarJadwal kosong tapi LLM tetap menyebut jadwal spesifik, fallback ke ekstraktif
        if (intent == 'Cari_Jadwal' && daftarJadwal.isEmpty && hasilRetrieval.isEmpty) {
          return _jawabanFallbackEkstraktif(masukanPengguna, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
        }
      }

      // Pastikan jawaban tidak kosong dan mengandung informasi yang diminta
      if (jawabanLlm.trim().isEmpty) {
        return _jawabanFallbackEkstraktif(masukanPengguna, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
      }

      // Jika LLM mengembalikan jawaban generik yang mengindikasikan tidak ada data,
      // tapi kita punya data jadwal presisi, prioritaskan data lokal
      if (jawabanLlm.toLowerCase().contains('tidak ditemukan') && daftarJadwal.isNotEmpty) {
        // Biarkan jawaban LLM apa adanya, tapi pastikan data lokal sudah ada di konteks
        // LLM seharusnya sudah menjawab dengan data tersebut
      }

      return jawabanLlm;
    } catch (error, stackTrace) {
      log('Error generasi LLM: $error', stackTrace: stackTrace);
      // Fallback ke jawaban ekstraktif saat LLM gagal (offline, timeout, quota habis)
      return _jawabanFallbackEkstraktif(masukanPengguna, hasilRetrieval, daftarJadwal, konteksJadwalPresisi);
    }
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
