import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:audioplayers/audioplayers.dart';

import 'indonesian_text_processor.dart';

/// Layanan TTS menggunakan Microsoft Edge TTS gratis tanpa API key.
/// Menggunakan suara ms-MY-YasminNeural karena paling natural untuk Bahasa Indonesia.
///
/// Fitur utama:
/// - Cache audio berdasarkan hash teks yang sudah dinormalisasi
/// - Pre-generate audio di background setelah pesan bot tiba
/// - Antrean pemutaran untuk teks panjang yang dipecah menjadi beberapa bagian
/// - Cleanup otomatis file temp yang lebih dari 24 jam
/// - Penanganan error dan retry dengan aman
/// - Pola singleton agar konsisten di seluruh aplikasi
class EdgeTtsService {
  static final EdgeTtsService _instansi = EdgeTtsService._internal();
  factory EdgeTtsService() => _instansi;
  EdgeTtsService._internal();

  FlutterEdgeTts? _layananEdgeTts;
  AudioPlayer? _pemutarAudio;
  bool _sudahDiinisialisasi = false;
  StreamSubscription? _langgananPemutar;

  /// Cache di memori: hash teks ternormalisasi -> path file audio
  final Map<int, String> _cacheAudio = {};
  static const int _maksFileCache = 24;

  /// Flag untuk mencegah pre-generate berjalan bersamaan
  bool _sedangPregenerate = false;

  /// Antrean untuk teks panjang yang dipecah menjadi beberapa file
  final List<String> _antreanBerkasAudio = [];
  int _indeksAntreanSaatIni = 0;
  bool _sedangMemutarAntrean = false;

  // Callback status untuk update UI
  Function? _onStart;
  Function? _onPause;
  Function? _onCompletion;
  Function(String)? _onError;

  PlayerState get playerState => _pemutarAudio?.state ?? PlayerState.stopped;
  bool get isPlaying => _pemutarAudio?.state == PlayerState.playing;
  bool get isPaused => _pemutarAudio?.state == PlayerState.paused;
  bool get sedangMemutarAntrean => _sedangMemutarAntrean;

  // Gunakan suara Yasmin Melayu yang mirip 90 persen dengan Bahasa Indonesia
  static const String _suaraDefault = 'ms-MY-YasminNeural';
  static const String _localeDefault = 'ms-MY';

  // Prosody: rate 0.9 agar lebih pelan sedikit dan lebih jelas
  static const EdgeTtsProsody _prosodi = EdgeTtsProsody(rate: '0.9');

  // File cache dihapus setelah 24 jam
  static const Duration _umurMaksCache = Duration(hours: 24);

  // Batas karakter untuk memecah teks panjang agar Edge TTS tidak gagal
  static const int _batasKarakterPerBagian = 700;

  /// Inisialisasi layanan. Aman dipanggil berkali-kali (idempotent).
  Future<void> init() async {
    if (_sudahDiinisialisasi) return;

    _layananEdgeTts = FlutterEdgeTts(
      voice: _suaraDefault,
      voiceLocale: _localeDefault,
      outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
      enableLogging: kDebugMode,
    );

    _pemutarAudio = AudioPlayer();

    // Batalkan langganan lama untuk mencegah listener ganda
    await _langgananPemutar?.cancel();

    // Dengarkan perubahan status pemutaran untuk update UI dan antrean
    _langgananPemutar = _pemutarAudio!.onPlayerStateChanged.listen((status) {
      debugPrint('[TTS] Status pemutar: $status');
      if (status == PlayerState.playing) {
        _onStart?.call();
      } else if (status == PlayerState.paused) {
        _onPause?.call();
      } else if (status == PlayerState.completed) {
        // Jika sedang memutar antrean dan masih ada bagian selanjutnya, lanjutkan otomatis
        if (_sedangMemutarAntrean && _indeksAntreanSaatIni + 1 < _antreanBerkasAudio.length) {
          _indeksAntreanSaatIni++;
          final berkasSelanjutnya = _antreanBerkasAudio[_indeksAntreanSaatIni];
          debugPrint('[TTS] Antrean lanjut ke bagian ${_indeksAntreanSaatIni + 1}/${_antreanBerkasAudio.length}');
          unawaited(_pemutarAudio!.play(DeviceFileSource(berkasSelanjutnya)));
        } else {
          // Antrean selesai atau bukan mode antrean
          if (_sedangMemutarAntrean) {
            debugPrint('[TTS] Antrean selesai, total ${_antreanBerkasAudio.length} bagian');
            _sedangMemutarAntrean = false;
            _antreanBerkasAudio.clear();
            _indeksAntreanSaatIni = 0;
          }
          _onCompletion?.call();
        }
      }
    });

    _sudahDiinisialisasi = true;

    // Bersihkan file TTS lama di background tanpa memblokir
    unawaited(_bersihkanCacheLama());

    debugPrint('[TTS] EdgeTtsService siap digunakan');
  }

  void setStartHandler(Function handler) => _onStart = handler;
  void setPauseHandler(Function handler) => _onPause = handler;
  void setCompletionHandler(Function handler) => _onCompletion = handler;
  void setErrorHandler(Function(String) handler) => _onError = handler;

  /// Normalisasi teks dan hitung kunci cache-nya.
  /// Selalu gunakan metode ini agar hash konsisten antara pregenerate dan speak.
  String _normalisasi(String teks) {
    return IndonesianTextProcessor.normalizeForMalayVoice(teks);
  }

  int _kunciCache(String teksTernormalisasi) => teksTernormalisasi.hashCode.abs();

  /// Memecah teks panjang menjadi beberapa bagian di batas kalimat agar TTS tidak gagal.
  /// Pecahan dilakukan pada tanda titik atau koma terdekat sebelum batas karakter.
  List<String> _pecahTeksMenjadiBagian(String teksTernormalisasi) {
    if (teksTernormalisasi.length <= _batasKarakterPerBagian) {
      return [teksTernormalisasi];
    }

    final List<String> daftarBagian = [];
    String sisaTeks = teksTernormalisasi;

    while (sisaTeks.length > _batasKarakterPerBagian) {
      // Cari titik terdekat sebelum batas
      int posisiPotong = sisaTeks.lastIndexOf('. ', _batasKarakterPerBagian);
      if (posisiPotong == -1) {
        posisiPotong = sisaTeks.lastIndexOf(', ', _batasKarakterPerBagian);
      }
      if (posisiPotong == -1) {
        posisiPotong = sisaTeks.lastIndexOf(' ', _batasKarakterPerBagian);
      }
      if (posisiPotong == -1 || posisiPotong < 150) {
        // Jika tidak ada titik potong yang layak, potong paksa di batas
        posisiPotong = _batasKarakterPerBagian;
      } else {
        posisiPotong += 1; // Sertakan titik/koma
      }

      final String bagian = sisaTeks.substring(0, posisiPotong).trim();
      if (bagian.isNotEmpty) {
        // Pastikan setiap bagian diakhiri tanda baca agar intonasi natural
        String bagianAkhir = bagian;
        if (!RegExp(r'[.!?]$').hasMatch(bagianAkhir)) {
          bagianAkhir = '$bagianAkhir.';
        }
        daftarBagian.add(bagianAkhir);
      }
      sisaTeks = sisaTeks.substring(posisiPotong).trim();
    }

    if (sisaTeks.isNotEmpty) {
      String bagianTerakhir = sisaTeks;
      if (!RegExp(r'[.!?]$').hasMatch(bagianTerakhir)) {
        bagianTerakhir = '$bagianTerakhir.';
      }
      daftarBagian.add(bagianTerakhir);
    }

    debugPrint('[TTS] Teks dipecah menjadi ${daftarBagian.length} bagian (panjang awal ${teksTernormalisasi.length})');
    return daftarBagian;
  }

  /// Pre-generate audio di background setelah pesan bot baru tiba.
  /// Tujuan: saat pengguna menekan play, audio sudah siap sehingga pemutaran mendekati instan.
  Future<void> pregenerate(String teks) async {
    if (!_sudahDiinisialisasi) await init();
    if (_sedangPregenerate) return;

    _sedangPregenerate = true;
    try {
      // Normalisasi dulu agar hash konsisten dengan yang dipakai speak()
      final String teksTernormalisasi = _normalisasi(teks);
      if (teksTernormalisasi.trim().isEmpty) return;

      // Jika teks panjang, pregenerate setiap bagian
      if (teksTernormalisasi.length > _batasKarakterPerBagian) {
        final List<String> daftarBagian = _pecahTeksMenjadiBagian(teksTernormalisasi);
        for (final bagian in daftarBagian) {
          final int kunciBagian = _kunciCache(bagian);
          if (_cacheAudio.containsKey(kunciBagian)) {
            final berkasCache = File(_cacheAudio[kunciBagian]!);
            if (await berkasCache.exists()) continue;
          }
          final String? path = await _hasilkanBerkasAudio(bagian, kunciBagian);
          if (path != null) await _simpanKeCache(kunciBagian, path);
        }
        debugPrint('[TTS] Pre-gen teks panjang selesai (${daftarBagian.length} bagian)');
        return;
      }

      final int kunci = _kunciCache(teksTernormalisasi);

      // Lewati jika sudah ada di cache dan berkasnya masih ada
      if (_cacheAudio.containsKey(kunci)) {
        final berkasCache = File(_cacheAudio[kunci]!);
        if (await berkasCache.exists()) {
          debugPrint('[TTS] Pre-gen: sudah di cache (kunci=$kunci), lewati');
          return;
        }
      }

      debugPrint('[TTS] Pre-gen: mulai generate di background...');
      final String? pathHasil = await _hasilkanBerkasAudio(teksTernormalisasi, kunci);
      if (pathHasil != null) {
        await _simpanKeCache(kunci, pathHasil);
        debugPrint('[TTS] Pre-gen selesai: $pathHasil');
      }
    } catch (error) {
      debugPrint('[TTS] Pre-gen error: $error');
    } finally {
      _sedangPregenerate = false;
    }
  }

  /// Membaca teks dengan suara YasminNeural.
  /// Alur: Normalisasi -> Cek cache -> Generate jika belum ada -> Putar
  /// Untuk teks panjang, otomatis dipecah dan diputar sebagai antrean.
  Future<void> speak(String teks) async {
    if (!_sudahDiinisialisasi) await init();

    // Inisialisasi ulang jika pemutar atau layanan null (kasus edge setelah dispose)
    if (_pemutarAudio == null || _layananEdgeTts == null) {
      debugPrint('[TTS] Pemutar null, inisialisasi ulang...');
      _sudahDiinisialisasi = false;
      await init();
    }

    // Hentikan suara dan antrean yang sedang berjalan jika ada
    try {
      await _pemutarAudio!.stop();
    } catch (_) {}
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    _indeksAntreanSaatIni = 0;

    // Normalisasi dulu agar hash konsisten dengan pregenerate
    final String teksTernormalisasi = _normalisasi(teks);
    if (teksTernormalisasi.trim().isEmpty) {
      debugPrint('[TTS] Teks ternormalisasi kosong, batalkan speak');
      _onCompletion?.call();
      return;
    }

    debugPrint('[TTS] Teks ternormalisasi: "${IndonesianTextProcessor.ringkasUntukLog(teksTernormalisasi)}"');

    // Jika teks panjang, gunakan antrean
    if (teksTernormalisasi.length > _batasKarakterPerBagian) {
      await _bicaraDenganAntrean(teksTernormalisasi);
      return;
    }

    final int kunci = _kunciCache(teksTernormalisasi);

    try {
      String? pathAudio;

      // Cek apakah audio sudah tersedia di cache
      if (_cacheAudio.containsKey(kunci)) {
        final berkasCache = File(_cacheAudio[kunci]!);
        if (await berkasCache.exists()) {
          pathAudio = _cacheAudio[kunci];
          debugPrint('[TTS] Cache hit -> pemutaran instan');
        } else {
          // Berkas cache sudah terhapus dari storage, hapus dari map juga
          _cacheAudio.remove(kunci);
        }
      }

      // Generate baru jika tidak ada di cache
      if (pathAudio == null) {
        debugPrint('[TTS] Cache miss -> generate audio...');
        pathAudio = await _hasilkanBerkasAudio(teksTernormalisasi, kunci);
        if (pathAudio != null) {
          await _simpanKeCache(kunci, pathAudio);
        }
      }

      if (pathAudio == null) {
        throw Exception('Gagal menghasilkan audio TTS');
      }

      // Putar berkas audio
      await _pemutarAudio!.play(DeviceFileSource(pathAudio));
      debugPrint('[TTS] Pemutaran dimulai');
    } catch (error, stackTrace) {
      debugPrint('[TTS] Error saat speak: $error');
      debugPrint('[TTS] StackTrace: $stackTrace');
      _onError?.call(error.toString());
      _onCompletion?.call();
    }
  }

  /// Penanganan khusus untuk teks panjang: pecah, generate, dan putar sebagai antrean berurutan.
  Future<void> _bicaraDenganAntrean(String teksTernormalisasi) async {
    try {
      final List<String> daftarBagian = _pecahTeksMenjadiBagian(teksTernormalisasi);
      final List<String> daftarPath = [];

      for (int i = 0; i < daftarBagian.length; i++) {
        final String bagian = daftarBagian[i];
        final int kunciBagian = _kunciCache(bagian);
        String? pathBagian;

        // Cek cache per bagian
        if (_cacheAudio.containsKey(kunciBagian)) {
          final berkasCache = File(_cacheAudio[kunciBagian]!);
          if (await berkasCache.exists()) {
            pathBagian = _cacheAudio[kunciBagian];
            debugPrint('[TTS] Antrean bagian ${i + 1}: cache hit');
          } else {
            _cacheAudio.remove(kunciBagian);
          }
        }

        // Generate jika belum di cache
        if (pathBagian == null) {
          debugPrint('[TTS] Antrean bagian ${i + 1}/${daftarBagian.length}: generate...');
          pathBagian = await _hasilkanBerkasAudio(bagian, kunciBagian + i);
          if (pathBagian != null) {
            await _simpanKeCache(kunciBagian, pathBagian);
          }
        }

        if (pathBagian != null) {
          // Verifikasi berkas ada dan valid
          final berkas = File(pathBagian);
          if (await berkas.exists() && await berkas.length() >= 100) {
            daftarPath.add(pathBagian);
          }
        } else {
          debugPrint('[TTS] Antrean bagian ${i + 1} gagal, lewati');
        }
      }

      if (daftarPath.isEmpty) {
        throw Exception('Gagal menghasilkan audio untuk teks panjang');
      }

      // Simpan antrean dan mulai pemutaran bagian pertama
      _antreanBerkasAudio
        ..clear()
        ..addAll(daftarPath);
      _indeksAntreanSaatIni = 0;
      _sedangMemutarAntrean = daftarPath.length > 1;

      // Jika hanya satu bagian, simpan juga sebagai cache untuk teks penuh
      if (daftarPath.length == 1) {
        final int kunciPenuh = _kunciCache(teksTernormalisasi);
        _cacheAudio[kunciPenuh] = daftarPath.first;
      }

      debugPrint('[TTS] Mulai antrean ${daftarPath.length} bagian');
      await _pemutarAudio!.play(DeviceFileSource(daftarPath.first));
    } catch (error, stackTrace) {
      debugPrint('[TTS] Error antrean: $error');
      debugPrint('[TTS] StackTrace antrean: $stackTrace');
      _sedangMemutarAntrean = false;
      _antreanBerkasAudio.clear();
      _onError?.call(error.toString());
      _onCompletion?.call();
    }
  }

  /// Generate audio ke berkas temp, kembalikan path jika berhasil.
  /// Dilengkapi timeout dan validasi ukuran berkas.
  Future<String?> _hasilkanBerkasAudio(String teksTernormalisasi, int kunci) async {
    try {
      final Directory direktoriTemp = await getTemporaryDirectory();
      // Simpan di subfolder khusus agar mudah di-cleanup
      final Directory direktoriTts = Directory('${direktoriTemp.path}/prima_tts_cache');
      await direktoriTts.create(recursive: true);

      final String pathOutput = '${direktoriTts.path}/$kunci.mp3';

      // Generate dengan timeout 20 detik
      await _layananEdgeTts!
          .synthesizeToFile(
            teksTernormalisasi,
            audioFilePath: pathOutput,
            prosody: _prosodi,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('Timeout generate TTS 20 detik'),
          );

      // Verifikasi berkas berhasil dibuat dan tidak kosong
      final File berkasOutput = File(pathOutput);
      if (!await berkasOutput.exists()) {
        debugPrint('[TTS] Berkas audio tidak terbentuk');
        return null;
      }

      final int ukuranBerkas = await berkasOutput.length();
      if (ukuranBerkas < 100) {
        debugPrint('[TTS] Berkas audio terlalu kecil ($ukuranBerkas bytes), kemungkinan gagal');
        try {
          await berkasOutput.delete();
        } catch (_) {}
        return null;
      }

      debugPrint('[TTS] Berkas audio OK: $ukuranBerkas bytes -> $pathOutput');
      return pathOutput;
    } on TimeoutException catch (error) {
      debugPrint('[TTS] _hasilkanBerkasAudio timeout: $error');
      return null;
    } catch (error) {
      debugPrint('[TTS] _hasilkanBerkasAudio error: $error');
      return null;
    }
  }

  /// Menyimpan berkas ke cache dan menjaga agar jumlah cache tetap terbatas.
  /// Jika melebihi batas, berkas tertua akan dihapus (FIFO).
  Future<void> _simpanKeCache(int kunci, String path) async {
    _cacheAudio.remove(kunci);
    _cacheAudio[kunci] = path;

    while (_cacheAudio.length > _maksFileCache) {
      final int kunciTerdahulu = _cacheAudio.keys.first;
      final String? pathTerdahulu = _cacheAudio.remove(kunciTerdahulu);
      if (pathTerdahulu == null) continue;

      try {
        final File berkas = File(pathTerdahulu);
        if (await berkas.exists()) await berkas.delete();
      } catch (error) {
        debugPrint('[TTS] Tidak dapat menghapus cache lama: $error');
      }
    }
  }

  /// Hapus berkas cache TTS yang berusia lebih dari 24 jam.
  /// Dipanggil otomatis saat init(), berjalan di background.
  Future<void> _bersihkanCacheLama() async {
    try {
      final Directory direktoriTemp = await getTemporaryDirectory();
      final Directory direktoriTts = Directory('${direktoriTemp.path}/prima_tts_cache');

      if (!await direktoriTts.exists()) return;

      final DateTime sekarang = DateTime.now();
      int jumlahDihapus = 0;

      await for (final entitas in direktoriTts.list()) {
        if (entitas is File) {
          final FileStat status = await entitas.stat();
          final Duration umur = sekarang.difference(status.modified);

          if (umur > _umurMaksCache) {
            await entitas.delete();
            jumlahDihapus++;
            // Hapus dari cache memori juga
            _cacheAudio.removeWhere((_, path) => path == entitas.path);
          }
        }
      }

      debugPrint('[TTS] Cleanup: $jumlahDihapus berkas lama dihapus');
    } catch (error) {
      debugPrint('[TTS] Cleanup error: $error');
    }
  }

  /// Hentikan pemutaran suara dan kosongkan antrean
  Future<void> stop() async {
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    _indeksAntreanSaatIni = 0;
    await _pemutarAudio?.stop();
  }

  /// Jeda pemutaran
  Future<void> pause() async => await _pemutarAudio?.pause();

  /// Lanjutkan pemutaran yang dijeda
  Future<void> resume() async => await _pemutarAudio?.resume();

  /// Bersihkan semua resource (dipanggil saat widget di-dispose)
  Future<void> dispose() async {
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    await _langgananPemutar?.cancel();
    await _pemutarAudio?.dispose();
    await _layananEdgeTts?.close();
    _sudahDiinisialisasi = false;
    debugPrint('[TTS] EdgeTtsService di-dispose');
  }
}
