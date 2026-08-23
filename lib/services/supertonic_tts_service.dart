// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'indonesian_text_processor.dart';

/// Layanan TTS hybrid: Supertonic (on-device high quality) + FlutterTts (sistem fallback sigap).
/// Mendukung 2 bahasa (Indonesia, English) dan 2 jenis suara (Laki-laki M1, Perempuan F1).
///
/// Strategi anti-lag:
/// - Init cepat: hanya cek modelReady tanpa download 400MB, fallback langsung siap
/// - Download model Supertonic hanya on-demand via pengaturan (background)
/// - Speak: jika model siap pakai Supertonic, jika belum pakai FlutterTts sistem yang ringan
/// - Semua operasi berat dijalankan async tanpa block UI thread
class SupertonicTtsService {
  static final SupertonicTtsService _instansi = SupertonicTtsService._internal();
  factory SupertonicTtsService() => _instansi;
  SupertonicTtsService._internal();

  SupertonicTTS? _mesinSupertonic;
  AudioPlayer? _pemutarAudio;
  FlutterTts? _ttsSistem;
  bool _sudahDiinisialisasi = false;
  bool _modelSiap = false;
  bool _sedangDownloadModel = false;
  StreamSubscription? _langgananPemutar;

  final Map<int, String> _cacheAudio = {};
  static const int _maksFileCache = 24;
  bool _sedangPregenerate = false;

  final List<String> _antreanBerkasAudio = [];
  int _indeksAntreanSaatIni = 0;
  bool _sedangMemutarAntrean = false;

  // Untuk fallback sistem
  bool _sedangPakaiFallback = false;

  Function? _onStart;
  Function? _onPause;
  Function? _onCompletion;
  Function(String)? _onError;
  Function(double)? _onModelDownloadProgress;

  PlayerState get playerState => _sedangPakaiFallback ? PlayerState.stopped : (_pemutarAudio?.state ?? PlayerState.stopped);
  bool get isPlaying {
    if (_sedangPakaiFallback) return _isFallbackPlaying;
    return _pemutarAudio?.state == PlayerState.playing;
  }
  bool get isPaused {
    if (_sedangPakaiFallback) return _isFallbackPaused;
    return _pemutarAudio?.state == PlayerState.paused;
  }
  bool get sedangMemutarAntrean => _sedangMemutarAntrean;
  bool get sudahDiinisialisasi => _sudahDiinisialisasi;
  bool get modelSiap => _modelSiap;
  bool get sedangDownloadModel => _sedangDownloadModel;

  // Fallback state tracking
  bool _isFallbackPlaying = false;
  bool _isFallbackPaused = false;

  static const String _keyBahasa = 'tts_bahasa';
  static const String _keyGayaSuara = 'tts_gaya_suara';
  static const String _keyKecepatan = 'tts_kecepatan';

  String _kodeBahasa = 'id';
  String _gayaSuara = 'F1';
  double _kecepatanBicara = 1.0;

  String get kodeBahasa => _kodeBahasa;
  String get gayaSuara => _gayaSuara;
  double get kecepatanBicara => _kecepatanBicara;
  bool get isBahasaIndonesia => _kodeBahasa == 'id';
  bool get isSuaraLakiLaki => _gayaSuara.startsWith('M');
  String get labelBahasa => _kodeBahasa == 'id' ? 'Indonesia' : 'English';
  String get labelGayaSuara => _gayaSuara.startsWith('M') ? 'Laki-laki' : 'Perempuan';

  static const int _batasKarakterPerBagian = 600;
  static const Duration _umurMaksCache = Duration(hours: 24);

  /// Inisialisasi cepat tanpa download. Aman dipanggil berkali-kali.
  Future<void> init() async {
    if (_sudahDiinisialisasi) return;

    _mesinSupertonic = SupertonicTTS();
    _pemutarAudio = AudioPlayer();
    _ttsSistem = FlutterTts();

    await _muatPengaturan();
    await _setupFallbackTts();

    await _langgananPemutar?.cancel();
    _langgananPemutar = _pemutarAudio!.onPlayerStateChanged.listen((status) {
      debugPrint('[TTS] Status pemutar: $status');
      if (status == PlayerState.playing) {
        _isFallbackPlaying = false;
        _onStart?.call();
      } else if (status == PlayerState.paused) {
        _onPause?.call();
      } else if (status == PlayerState.completed) {
        if (_sedangMemutarAntrean && _indeksAntreanSaatIni + 1 < _antreanBerkasAudio.length) {
          _indeksAntreanSaatIni++;
          final berkasSelanjutnya = _antreanBerkasAudio[_indeksAntreanSaatIni];
          debugPrint('[TTS] Antrean lanjut ${ _indeksAntreanSaatIni + 1}/${_antreanBerkasAudio.length}');
          unawaited(_pemutarAudio!.play(DeviceFileSource(berkasSelanjutnya)));
        } else {
          if (_sedangMemutarAntrean) {
            debugPrint('[TTS] Antrean selesai ${ _antreanBerkasAudio.length} bagian');
            _sedangMemutarAntrean = false;
            _antreanBerkasAudio.clear();
            _indeksAntreanSaatIni = 0;
          }
          _onCompletion?.call();
        }
      }
    });

    // Setup handler untuk fallback juga
    _ttsSistem!.setStartHandler(() {
      _isFallbackPlaying = true;
      _isFallbackPaused = false;
      _onStart?.call();
    });
    _ttsSistem!.setCompletionHandler(() {
      _isFallbackPlaying = false;
      _isFallbackPaused = false;
      // Handle antrean fallback jika ada
      if (_sedangMemutarAntrean && _indeksAntreanSaatIni + 1 < _antreanBerkasAudio.length) {
        _indeksAntreanSaatIni++;
        unawaited(_bicaraFallbackAntrean());
      } else {
        _sedangMemutarAntrean = false;
        _antreanBerkasAudio.clear();
        _onCompletion?.call();
      }
    });
    _ttsSistem!.setPauseHandler(() {
      _isFallbackPaused = true;
      _onPause?.call();
    });
    _ttsSistem!.setErrorHandler((msg) {
      _isFallbackPlaying = false;
      _onError?.call(msg);
      _onCompletion?.call();
    });

    // Cek model tanpa download (cepat, tidak block UI)
    try {
      debugPrint('[TTS] Cek model Supertonic (tanpa download)...');
      _modelSiap = await SupertonicTTS.modelsReady().timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (_modelSiap) {
        // Jika model sudah ada, initialize ringan
        await _mesinSupertonic!.initialize().timeout(const Duration(seconds: 5), onTimeout: () {
          throw TimeoutException('Init Supertonic timeout');
        });
        debugPrint('[TTS] Supertonic siap');
      } else {
        debugPrint('[TTS] Model Supertonic belum ada, pakai fallback sistem (tidak download otomatis agar tidak lag)');
      }
    } catch (e) {
      debugPrint('[TTS] Cek model gagal, pakai fallback: $e');
      _modelSiap = false;
    }

    _sudahDiinisialisasi = true;
    unawaited(_bersihkanCacheLama());
    debugPrint('[TTS] Init selesai - modelSiap=$_modelSiap, bahasa=$_kodeBahasa, suara=$_gayaSuara');
  }

  Future<void> _setupFallbackTts() async {
    try {
      await _ttsSistem!.setLanguage(_kodeBahasa == 'id' ? 'id-ID' : 'en-US');
      await _ttsSistem!.setSpeechRate(_kecepatanBicara.clamp(0.0, 1.0) * 0.5);
      await _ttsSistem!.setVolume(1.0);
      await _ttsSistem!.setPitch(_gayaSuara.startsWith('M') ? 0.9 : 1.1);
      // Coba set voice berdasarkan gender jika tersedia
      try {
        final voices = await _ttsSistem!.getVoices;
        if (voices != null) {
          debugPrint('[TTS] Voices tersedia: $voices');
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[TTS] Setup fallback gagal: $e');
    }
  }

  Future<void> _muatPengaturan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _kodeBahasa = prefs.getString(_keyBahasa) ?? 'id';
      _gayaSuara = prefs.getString(_keyGayaSuara) ?? 'F1';
      _kecepatanBicara = prefs.getDouble(_keyKecepatan) ?? 1.0;
      if (_kodeBahasa != 'id' && _kodeBahasa != 'en') _kodeBahasa = 'id';
      if (_gayaSuara != 'M1' && _gayaSuara != 'F1') _gayaSuara = 'F1';
    } catch (_) {}
  }

  Future<void> setBahasa(String kodeBahasa) async {
    if (kodeBahasa != 'id' && kodeBahasa != 'en') return;
    _kodeBahasa = kodeBahasa;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBahasa, kodeBahasa);
      await _ttsSistem!.setLanguage(kodeBahasa == 'id' ? 'id-ID' : 'en-US');
    } catch (_) {}
    _cacheAudio.clear();
    debugPrint('[TTS] Bahasa diubah ke $kodeBahasa');
  }

  Future<void> setGayaSuara(String gaya) async {
    String gayaNormal = 'F1';
    if (gaya.startsWith('M')) gayaNormal = 'M1';
    else if (gaya.startsWith('F')) gayaNormal = 'F1';
    else if (gaya == 'Laki-laki') gayaNormal = 'M1';
    else if (gaya == 'Perempuan') gayaNormal = 'F1';
    _gayaSuara = gayaNormal;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGayaSuara, gayaNormal);
      await _ttsSistem!.setPitch(gayaNormal.startsWith('M') ? 0.9 : 1.1);
    } catch (_) {}
    _cacheAudio.clear();
    debugPrint('[TTS] Gaya suara diubah ke $gayaNormal');
  }

  Future<void> setKecepatan(double kecepatan) async {
    _kecepatanBicara = kecepatan.clamp(0.8, 1.3);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyKecepatan, _kecepatanBicara);
      await _ttsSistem!.setSpeechRate(_kecepatanBicara.clamp(0.0, 1.0) * 0.5);
      await _ttsSistem!.setPitch(_gayaSuara.startsWith('M') ? 0.9 : 1.1);
    } catch (_) {}
  }

  /// Download model Supertonic secara manual (dipanggil dari pengaturan). Berjalan di background.
  Future<bool> downloadModel({Function(double)? onProgress}) async {
    if (_sedangDownloadModel) return false;
    _sedangDownloadModel = true;
    try {
      debugPrint('[TTS] Mulai download model Supertonic 400MB...');
      await SupertonicTTS.preDownloadModels(
        onProgress: (selesai, total, berkas, progres) {
          _onModelDownloadProgress?.call(progres);
          onProgress?.call(progres);
          debugPrint('[TTS] Download [$selesai/$total] $berkas ${(progres*100).toStringAsFixed(1)}%');
        },
      );
      await _mesinSupertonic!.initialize();
      _modelSiap = true;
      debugPrint('[TTS] Download selesai, model siap');
      return true;
    } catch (e) {
      debugPrint('[TTS] Download gagal: $e');
      _modelSiap = false;
      return false;
    } finally {
      _sedangDownloadModel = false;
    }
  }

  void setStartHandler(Function handler) => _onStart = handler;
  void setPauseHandler(Function handler) => _onPause = handler;
  void setCompletionHandler(Function handler) => _onCompletion = handler;
  void setErrorHandler(Function(String) handler) => _onError = handler;
  void setModelProgressHandler(Function(double) handler) => _onModelDownloadProgress = handler;

  String _normalisasi(String teks) {
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
    return bagian;
  }

  Future<void> pregenerate(String teks) async {
    if (!_sudahDiinisialisasi) await init();
    if (_sedangPregenerate) return;
    // Jika model belum siap, tidak perlu pregenerate supertonic, fallback tidak butuh file
    if (!_modelSiap) return;
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
      debugPrint('[TTS] pregenerate error: $e');
    } finally {
      _sedangPregenerate = false;
    }
  }

  Future<void> speak(String teks) async {
    if (!_sudahDiinisialisasi) await init();
    if (_pemutarAudio == null || _mesinSupertonic == null) {
      _sudahDiinisialisasi = false;
      await init();
    }
    // Hentikan yang sedang berjalan
    try {
      await _pemutarAudio!.stop();
      await _ttsSistem!.stop();
    } catch (_) {}
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    _indeksAntreanSaatIni = 0;
    _isFallbackPlaying = false;
    _isFallbackPaused = false;

    final String normal = _normalisasi(teks);
    if (normal.trim().isEmpty) {
      _onCompletion?.call();
      return;
    }

    // Jika model siap, pakai Supertonic (high quality, tapi butuh file)
    if (_modelSiap) {
      try {
        if (normal.length > _batasKarakterPerBagian) {
          await _bicaraAntreanSupertonic(normal);
          return;
        }
        final int kunci = _kunciCache(normal, _kodeBahasa, _gayaSuara);
        String? path;
        if (_cacheAudio.containsKey(kunci) && await File(_cacheAudio[kunci]!).exists()) {
          path = _cacheAudio[kunci];
        }
        if (path == null) {
          path = await _hasilkanBerkas(normal, kunci);
          if (path != null) await _simpanCache(kunci, path);
        }
        if (path != null) {
          _sedangPakaiFallback = false;
          await _pemutarAudio!.play(DeviceFileSource(path));
          return;
        }
        // Jika gagal generate supertonic, fallback
        debugPrint('[TTS] Supertonic gagal, fallback ke sistem');
      } catch (e) {
        debugPrint('[TTS] Supertonic speak error, fallback: $e');
      }
    }

    // Fallback ke FlutterTts sistem (sigap, ringan, tidak lag)
    await _bicaraFallback(normal);
  }

  Future<void> _bicaraFallback(String normal) async {
    _sedangPakaiFallback = true;
    // Untuk teks panjang, pecah dan antre via fallback juga
    if (normal.length > _batasKarakterPerBagian) {
      final parts = _pecahTeks(normal);
      _antreanBerkasAudio.clear();
      _antreanBerkasAudio.addAll(parts);
      _indeksAntreanSaatIni = 0;
      _sedangMemutarAntrean = parts.length > 1;
      await _ttsSistem!.speak(parts.first);
    } else {
      _sedangMemutarAntrean = false;
      await _ttsSistem!.speak(normal);
    }
  }

  Future<void> _bicaraFallbackAntrean() async {
    if (_indeksAntreanSaatIni < _antreanBerkasAudio.length) {
      await _ttsSistem!.speak(_antreanBerkasAudio[_indeksAntreanSaatIni]);
    }
  }

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

  Future<void> _bicaraAntreanSupertonic(String normal) async {
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
      _antreanBerkasAudio..clear()..addAll(paths);
      _indeksAntreanSaatIni = 0;
      _sedangMemutarAntrean = paths.length > 1;
      _sedangPakaiFallback = false;
      if (paths.length == 1) {
        final kFull = _kunciCache(normal, _kodeBahasa, _gayaSuara);
        _cacheAudio[kFull] = paths.first;
      }
      await _pemutarAudio!.play(DeviceFileSource(paths.first));
    } catch (e, st) {
      debugPrint('[TTS] antrean supertonic error $e $st, fallback');
      await _bicaraFallback(normal);
    }
  }

  Future<String?> _hasilkanBerkas(String teksNormal, int kunci) async {
    if (!_modelSiap) return null;
    try {
      final dirTemp = await getTemporaryDirectory();
      final dirTts = Directory('${dirTemp.path}/prima_supertonic_cache');
      await dirTts.create(recursive: true);
      final path = '${dirTts.path}/$kunci.wav';
      final fileExisting = File(path);
      if (await fileExisting.exists() && await fileExisting.length() > 100) {
        return path;
      }
      final config = TTSConfig(speechSpeed: _kecepatanBicara, denoisingSteps: 5);
      final hasil = await _mesinSupertonic!
          .synthesize(teksNormal, language: _kodeBahasa, voiceStyle: _gayaSuara, config: config)
          .timeout(const Duration(seconds: 30), onTimeout: () => throw TimeoutException('Timeout synthesize 30s'));
      final wavBytes = hasil.toWavBytes();
      final file = File(path);
      await file.writeAsBytes(wavBytes);
      final size = await file.length();
      if (size < 100) {
        try { await file.delete(); } catch (_) {}
        return null;
      }
      return path;
    } on TimeoutException catch (e) {
      debugPrint('[TTS] timeout $e');
      return null;
    } catch (e) {
      debugPrint('[TTS] generate error $e');
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
        debugPrint('[TTS] hapus cache gagal $e');
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
      debugPrint('[TTS] cleanup $hapus file');
    } catch (e) {
      debugPrint('[TTS] cleanup error $e');
    }
  }

  Future<void> stop() async {
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    _indeksAntreanSaatIni = 0;
    _isFallbackPlaying = false;
    _isFallbackPaused = false;
    try { await _pemutarAudio?.stop(); } catch (_) {}
    try { await _ttsSistem?.stop(); } catch (_) {}
  }

  Future<void> pause() async {
    if (_sedangPakaiFallback) {
      try { await _ttsSistem?.pause(); } catch (_) {}
      _isFallbackPaused = true;
    } else {
      await _pemutarAudio?.pause();
    }
  }

  Future<void> resume() async {
    if (_sedangPakaiFallback) {
      // FlutterTts tidak support resume sempurna, speak ulang dari awal jika perlu
      _isFallbackPaused = false;
    } else {
      await _pemutarAudio?.resume();
    }
  }

  Future<void> dispose() async {
    _sedangMemutarAntrean = false;
    _antreanBerkasAudio.clear();
    await _langgananPemutar?.cancel();
    await _pemutarAudio?.dispose();
    _sudahDiinisialisasi = false;
    _modelSiap = false;
  }

  bool get sedangDownloadModelFallback => _sedangDownloadModel;
}
