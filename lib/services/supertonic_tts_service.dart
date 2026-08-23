// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import 'indonesian_text_processor.dart';

/// Layanan TTS menggunakan Supertonic 3 (on-device, gratis, tanpa API key).
/// Mendukung 2 bahasa (Indonesia, English) dan 2 jenis suara (Laki-laki M1, Perempuan F1).
///
/// Fitur:
/// - Cache audio berdasarkan hash teks + bahasa + gaya suara
/// - Pre-generate di background setelah pesan bot tiba
/// - Antrean untuk teks panjang yang dipecah
/// - Pengaturan bahasa dan jenis suara dengan persistensi SharedPreferences
/// - Pratinjau suara langsung di pengaturan
/// - Cleanup otomatis file temp lebih dari 24 jam
/// - Singleton agar konsisten di seluruh aplikasi
class SupertonicTtsService {
  static final SupertonicTtsService _instansi = SupertonicTtsService._internal();
  factory SupertonicTtsService() => _instansi;
  SupertonicTtsService._internal();

  SupertonicTTS? _mesinSupertonic;
  AudioPlayer? _pemutarAudio;
  bool _sudahDiinisialisasi = false;
  bool _modelSiap = false;
  StreamSubscription? _langgananPemutar;

  /// Cache di memori: hash (teks+b bahasa+gaya) -> path file audio
  final Map<int, String> _cacheAudio = {};
  static const int _maksFileCache = 24;

  bool _sedangPregenerate = false;

  /// Antrean untuk teks panjang
  final List<String> _antreanBerkasAudio = [];
  int _indeksAntreanSaatIni = 0;
  bool _sedangMemutarAntrean = false;

  // Callback status untuk update UI
  Function? _onStart;
  Function? _onPause;
  Function? _onCompletion;
  Function(String)? _onError;
  Function(double)? _onModelDownloadProgress;

  PlayerState get playerState => _pemutarAudio?.state ?? PlayerState.stopped;
  bool get isPlaying => _pemutarAudio?.state == PlayerState.playing;
  bool get isPaused => _pemutarAudio?.state == PlayerState.paused;
  bool get sedangMemutarAntrean => _sedangMemutarAntrean;
  bool get sudahDiinisialisasi => _sudahDiinisialisasi;
  bool get modelSiap => _modelSiap;

  // Pengaturan bahasa dan suara (persistensi)
  static const String _keyBahasa = 'tts_bahasa';
  static const String _keyGayaSuara = 'tts_gaya_suara';
  static const String _keyKecepatan = 'tts_kecepatan';

  String _kodeBahasa = 'id'; // id = Indonesia, en = English
  String _gayaSuara = 'F1'; // M1 = laki-laki, F1 = perempuan
  double _kecepatanBicara = 1.0;

  String get kodeBahasa => _kodeBahasa;
  String get gayaSuara => _gayaSuara;
  double get kecepatanBicara => _kecepatanBicara;
  bool get isBahasaIndonesia => _kodeBahasa == 'id';
  bool get isSuaraLakiLaki => _gayaSuara.startsWith('M');

  // Label untuk UI
  String get labelBahasa => _kodeBahasa == 'id' ? 'Indonesia' : 'English';
  String get labelGayaSuara => _gayaSuara.startsWith('M') ? 'Laki-laki' : 'Perempuan';

  // Batas karakter per bagian
  static const int _batasKarakterPerBagian = 600;
  static const Duration _umurMaksCache = Duration(hours: 24);

  /// Inisialisasi layanan Supertonic. Aman dipanggil berkali-kali (idempotent).
  /// Akan otomatis download model ~400MB jika belum ada.
  Future<void> init() async {
    if (_sudahDiinisialisasi) return;

    _mesinSupertonic = SupertonicTTS();
    _pemutarAudio = AudioPlayer();

    // Muat pengaturan tersimpan
    await _muatPengaturan();

    // Dengarkan perubahan status pemutar untuk antrean
    await _langgananPemutar?.cancel();
    _langgananPemutar = _pemutarAudio!.onPlayerStateChanged.listen((status) {
      debugPrint('[Supertonic] Status pemutar: $status');
      if (status == PlayerState.playing) {
        _onStart?.call();
      } else if (status == PlayerState.paused) {
        _onPause?.call();
      } else if (status == PlayerState.completed) {
        if (_sedangMemutarAntrean && _indeksAntreanSaatIni + 1 < _antreanBerkasAudio.length) {
          _indeksAntreanSaatIni++;
          final berkasSelanjutnya = _antreanBerkasAudio[_indeksAntreanSaatIni];
          debugPrint('[Supertonic] Antrean lanjut ${ _indeksAntreanSaatIni + 1}/${_antreanBerkasAudio.length}');
          unawaited(_pemutarAudio!.play(DeviceFileSource(berkasSelanjutnya)));
        } else {
          if (_sedangMemutarAntrean) {
            debugPrint('[Supertonic] Antrean selesai ${ _antreanBerkasAudio.length} bagian');
            _sedangMemutarAntrean = false;
            _antreanBerkasAudio.clear();
            _indeksAntreanSaatIni = 0;
          }
          _onCompletion?.call();
        }
      }
    });

    // Inisialisasi model Supertonic (auto download jika belum ada)
    try {
      debugPrint('[Supertonic] Memeriksa model...');
      // Cek apakah model sudah siap
      final bool siap = await SupertonicTTS.modelsReady();
      if (!siap) {
        debugPrint('[Supertonic] Model belum ada, mulai download ~400MB...');
        await SupertonicTTS.preDownloadModels(
          onProgress: (selesai, total, berkas, progres) {
            final double persen = progres * 100;
            debugPrint('[Supertonic] Download [$selesai/$total] $berkas: ${persen.toStringAsFixed(1)}%');
            _onModelDownloadProgress?.call(progres);
          },
        );
      }
      await _mesinSupertonic!.initialize();
      _modelSiap = true;
      _sudahDiinisialisasi = true;
      debugPrint('[Supertonic] Inisialisasi berhasil, model siap');
    } catch (error, stackTrace) {
      debugPrint('[Supertonic] Gagal inisialisasi: $error');
      debugPrint('[Supertonic] Stack: $stackTrace');
      // Tetap tandai sudah diinisialisasi agar tidak retry terus, tapi modelSiap false
      _sudahDiinisialisasi = true;
      _modelSiap = false;
      _onError?.call('Gagal inisialisasi TTS: $error');
    }

    unawaited(_bersihkanCacheLama());
  }

  /// Memuat pengaturan bahasa dan suara dari SharedPreferences
  Future<void> _muatPengaturan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _kodeBahasa = prefs.getString(_keyBahasa) ?? 'id';
      _gayaSuara = prefs.getString(_keyGayaSuara) ?? 'F1';
      _kecepatanBicara = prefs.getDouble(_keyKecepatan) ?? 1.0;
      // Validasi
      if (_kodeBahasa != 'id' && _kodeBahasa != 'en') _kodeBahasa = 'id';
      if (_gayaSuara != 'M1' && _gayaSuara != 'F1') _gayaSuara = 'F1';
      debugPrint('[Supertonic] Pengaturan dimuat: bahasa=$_kodeBahasa, suara=$_gayaSuara, kecepatan=$_kecepatanBicara');
    } catch (e) {
      debugPrint('[Supertonic] Gagal muat pengaturan: $e');
    }
  }

  /// Menyimpan pengaturan bahasa
  Future<void> setBahasa(String kodeBahasa) async {
    if (kodeBahasa != 'id' && kodeBahasa != 'en') return;
    _kodeBahasa = kodeBahasa;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBahasa, kodeBahasa);
    } catch (_) {}
    // Hapus cache karena bahasa berubah, audio lama tidak relevan
    _cacheAudio.clear();
    debugPrint('[Supertonic] Bahasa diubah ke $kodeBahasa');
  }

  /// Menyimpan pengaturan gaya suara
  Future<void> setGayaSuara(String gaya) async {
    // Normalisasi ke M1 atau F1
    String gayaNormal = 'F1';
    if (gaya.startsWith('M')) gayaNormal = 'M1';
    else if (gaya.startsWith('F')) gayaNormal = 'F1';
    else if (gaya == 'Laki-laki') gayaNormal = 'M1';
    else if (gaya == 'Perempuan') gayaNormal = 'F1';

    _gayaSuara = gayaNormal;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGayaSuara, gayaNormal);
    } catch (_) {}
    _cacheAudio.clear();
    debugPrint('[Supertonic] Gaya suara diubah ke $gayaNormal');
  }

  /// Mengatur kecepatan bicara (0.8 - 1.3)
  Future<void> setKecepatan(double kecepatan) async {
    _kecepatanBicara = kecepatan.clamp(0.8, 1.3);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyKecepatan, _kecepatanBicara);
    } catch (_) {}
    debugPrint('[Supertonic] Kecepatan diubah ke $_kecepatanBicara');
  }

  void setStartHandler(Function handler) => _onStart = handler;
  void setPauseHandler(Function handler) => _onPause = handler;
  void setCompletionHandler(Function handler) => _onCompletion = handler;
  void setErrorHandler(Function(String) handler) => _onError = handler;
  void setModelProgressHandler(Function(double) handler) => _onModelDownloadProgress = handler;

  String _normalisasi(String teks) {
    // Untuk bahasa Inggris, tetap gunakan processor tapi tanpa ekspansi jam Indonesia?
    // Saat ini processor mendukung Indonesia, untuk English kita tetap pakai tapi hasilnya masih oke
    return IndonesianTextProcessor.normalizeForMalayVoice(teks);
  }

  int _kunciCache(String teksNormal, String bahasa, String gaya) {
    return '$teksNormal|$bahasa|$gaya|$_kecepatanBicara'.hashCode.abs();
  }

  List<String> _pecahTeks(String teksNormal) {
    if (teksNormal.length <= _batasKarakterPerBagian) return [teksNormal];
    final List<String> bagian = [];
    String sisa = teksNormal;
    while (sisa.length > _batasKarakterPerBagian) {
      int potong = sisa.lastIndexOf('. ', _batasKarakterPerBagian);
      if (potong == -1) potong = sisa.lastIndexOf(', ', _batasKarakterPerBagian);
      if (potong == -1) potong = sisa.lastIndexOf(' ', _batasKarakterPerBagian);
      if (potong == -1 || potong < 150) potong = _batasKarakterPerBagian;
      else potong += 1;
      final String potongan = sisa.substring(0, potong).trim();
      if (potongan.isNotEmpty) {
        String akhir = potongan;
        if (!RegExp(r'[.!?]$').hasMatch(akhir)) akhir = '$akhir.';
        bagian.add(akhir);
      }
      sisa = sisa.substring(potong).trim();
    }
    if (sisa.isNotEmpty) {
      String akhir = sisa;
      if (!RegExp(r'[.!?]$').hasMatch(akhir)) akhir = '$akhir.';
      bagian.add(akhir);
    }
    debugPrint('[Supertonic] Teks dipecah ${bagian.length} bagian');
    return bagian;
  }

  /// Pre-generate di background agar playback instan
  Future<void> pregenerate(String teks) async {
    if (!_sudahDiinisialisasi) await init();
    if (_sedangPregenerate || !_modelSiap) return;
    _sedangPregenerate = true;
    try {
      final String normal = _normalisasi(teks);
      if (normal.trim().isEmpty) return;
      if (normal.length > _batasKarakterPerBagian) {
        final parts = _pecahTeks(normal);
        for (final p in parts) {
          final k = _kunciCache(p, _kodeBahasa, _gayaSuara);
          if (_cacheAudio.containsKey(k) && await File(_cacheAudio[k]!).exists()) continue;
          final path = await _hasilkanBerkas(p, k);
          if (path != null) await _simpanCache(k, path);
        }
        return;
      }
      final k = _kunciCache(normal, _kodeBahasa, _gayaSuara);
      if (_cacheAudio.containsKey(k) && await File(_cacheAudio[k]!).exists()) return;
      final path = await _hasilkanBerkas(normal, k);
      if (path != null) await _simpanCache(k, path);
    } catch (e) {
      debugPrint('[Supertonic] pregenerate error: $e');
    } finally {
      _sedangPregenerate = false;
    }
  }

  /// Ucapkan teks dengan bahasa dan suara saat ini
  Future<void> speak(String teks) async {
    if (!_sudahDiinisialisasi) await init();
    if (_pemutarAudio == null || _mesinSupertonic == null) {
      _sudahDiinisialisasi = false;
      await init();
    }
    try {
      await _pemutarAudio!.stop();
    } catch (_) {}
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    _indeksAntreanSaatIni = 0;

    final String normal = _normalisasi(teks);
    if (normal.trim().isEmpty) {
      _onCompletion?.call();
      return;
    }

    if (!_modelSiap) {
      debugPrint('[Supertonic] Model belum siap, coba init ulang');
      _onError?.call('Model TTS belum siap, silakan tunggu download selesai');
      _onCompletion?.call();
      return;
    }

    if (normal.length > _batasKarakterPerBagian) {
      await _bicaraAntrean(normal);
      return;
    }

    final int kunci = _kunciCache(normal, _kodeBahasa, _gayaSuara);
    try {
      String? path;
      if (_cacheAudio.containsKey(kunci) && await File(_cacheAudio[kunci]!).exists()) {
        path = _cacheAudio[kunci];
        debugPrint('[Supertonic] Cache hit');
      }
      if (path == null) {
        path = await _hasilkanBerkas(normal, kunci);
        if (path != null) await _simpanCache(kunci, path);
      }
      if (path == null) throw Exception('Gagal generate audio');
      await _pemutarAudio!.play(DeviceFileSource(path));
      debugPrint('[Supertonic] Play dimulai: $path');
    } catch (e, st) {
      debugPrint('[Supertonic] speak error: $e $st');
      _onError?.call(e.toString());
      _onCompletion?.call();
    }
  }

  /// Pratinjau suara untuk pengaturan (teks pendek sesuai bahasa)
  Future<void> pratinjauSuara({String? teksKustom}) async {
    String teksPratinjau;
    if (teksKustom != null && teksKustom.trim().isNotEmpty) {
      teksPratinjau = teksKustom;
    } else if (_kodeBahasa == 'id') {
      teksPratinjau = _gayaSuara.startsWith('M')
          ? 'Halo, saya Prima asisten Rumah Sakit Prima Insan Mulia. Saya siap membantu Anda.'
          : 'Halo, saya Prima asisten Rumah Sakit Prima Insan Mulia. Ada yang bisa saya bantu?';
    } else {
      teksPratinjau = _gayaSuara.startsWith('M')
          ? 'Hello, I am Prima, your hospital assistant. How can I help you today?'
          : 'Hello, I am Prima, your hospital assistant. How may I assist you?';
    }
    await speak(teksPratinjau);
  }

  Future<void> _bicaraAntrean(String normal) async {
    try {
      final parts = _pecahTeks(normal);
      final List<String> paths = [];
      for (int i = 0; i < parts.length; i++) {
        final p = parts[i];
        final k = _kunciCache(p, _kodeBahasa, _gayaSuara);
        String? path;
        if (_cacheAudio.containsKey(k) && await File(_cacheAudio[k]!).exists()) {
          path = _cacheAudio[k];
        }
        if (path == null) {
          path = await _hasilkanBerkas(p, k + i);
          if (path != null) await _simpanCache(k, path);
        }
        if (path != null && await File(path).exists() && await File(path).length() >= 100) {
          paths.add(path);
        }
      }
      if (paths.isEmpty) throw Exception('Gagal antrean');
      _antreanBerkasAudio
        ..clear()
        ..addAll(paths);
      _indeksAntreanSaatIni = 0;
      _sedangMemutarAntrean = paths.length > 1;
      if (paths.length == 1) {
        final kFull = _kunciCache(normal, _kodeBahasa, _gayaSuara);
        _cacheAudio[kFull] = paths.first;
      }
      await _pemutarAudio!.play(DeviceFileSource(paths.first));
    } catch (e, st) {
      debugPrint('[Supertonic] antrean error $e $st');
      _sedangMemutarAntrean = false;
      _antreanBerkasAudio.clear();
      _onError?.call(e.toString());
      _onCompletion?.call();
    }
  }

  Future<String?> _hasilkanBerkas(String teksNormal, int kunci) async {
    try {
      final dirTemp = await getTemporaryDirectory();
      final dirTts = Directory('${dirTemp.path}/prima_supertonic_cache');
      await dirTts.create(recursive: true);
      final path = '${dirTts.path}/$kunci.wav';

      // Jika file sudah ada dan valid, langsung pakai
      final fileExisting = File(path);
      if (await fileExisting.exists() && await fileExisting.length() > 100) {
        return path;
      }

      // Synthesize via Supertonic
      final config = TTSConfig(
        speechSpeed: _kecepatanBicara,
        denoisingSteps: 5,
      );

      final hasil = await _mesinSupertonic!
          .synthesize(
            teksNormal,
            language: _kodeBahasa,
            voiceStyle: _gayaSuara,
            config: config,
          )
          .timeout(const Duration(seconds: 30), onTimeout: () => throw TimeoutException('Timeout synthesize 30s'));

      final wavBytes = hasil.toWavBytes();
      final file = File(path);
      await file.writeAsBytes(wavBytes);
      final size = await file.length();
      if (size < 100) {
        debugPrint('[Supertonic] file terlalu kecil $size');
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      debugPrint('[Supertonic] file OK $size bytes $path');
      return path;
    } on TimeoutException catch (e) {
      debugPrint('[Supertonic] timeout $e');
      return null;
    } catch (e) {
      debugPrint('[Supertonic] generate error $e');
      return null;
    }
  }

  Future<void> _simpanCache(int kunci, String path) async {
    _cacheAudio.remove(kunci);
    _cacheAudio[kunci] = path;
    while (_cacheAudio.length > _maksFileCache) {
      final k = _cacheAudio.keys.first;
      final p = _cacheAudio.remove(k);
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('[Supertonic] hapus cache gagal $e');
      }
    }
  }

  Future<void> _bersihkanCacheLama() async {
    try {
      final dirTemp = await getTemporaryDirectory();
      final dirTts = Directory('${dirTemp.path}/prima_supertonic_cache');
      if (!await dirTts.exists()) return;
      final now = DateTime.now();
      int hapus = 0;
      await for (final e in dirTts.list()) {
        if (e is File) {
          final stat = await e.stat();
          if (now.difference(stat.modified) > _umurMaksCache) {
            await e.delete();
            hapus++;
            _cacheAudio.removeWhere((_, v) => v == e.path);
          }
        }
      }
      debugPrint('[Supertonic] cleanup $hapus file');
    } catch (e) {
      debugPrint('[Supertonic] cleanup error $e');
    }
  }

  Future<void> stop() async {
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    _indeksAntreanSaatIni = 0;
    await _pemutarAudio?.stop();
  }

  Future<void> pause() async => await _pemutarAudio?.pause();
  Future<void> resume() async => await _pemutarAudio?.resume();

  Future<void> dispose() async {
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    await _langgananPemutar?.cancel();
    await _pemutarAudio?.dispose();
    // Supertonic tidak perlu close explicit, tapi bersihkan
    _sudahDiinisialisasi = false;
    _modelSiap = false;
    debugPrint('[Supertonic] disposed');
  }

  /// Untuk menampilkan progres download model di UI
  bool get sedangDownloadModel => !_modelSiap && _sudahDiinisialisasi == false;
}
