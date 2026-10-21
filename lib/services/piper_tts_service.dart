import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_piper_tts/flutter_piper_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'indonesian_text_processor.dart';
import 'piper_voice_catalog.dart';

/// TTS Piper yang seluruhnya berjalan di perangkat.
///
/// Piper resmi saat ini hanya menyediakan satu model Bahasa Indonesia,
/// [id_ID-news_tts-medium]. Karena itu pilihan jenis suara hanya tersedia
/// untuk Bahasa Inggris; aplikasi tidak lagi menyamarkan model yang sama
/// sebagai dua suara Indonesia berbeda.
class PiperTtsService {
  static final PiperTtsService _instance = PiperTtsService._internal();

  factory PiperTtsService() => _instance;

  PiperTtsService._internal();

  static const String _languagePreferenceKey = 'tts_bahasa';
  static const String _voiceStylePreferenceKey = 'tts_gaya_suara';

  PiperTTS? _engine;
  Future<void>? _initialization;
  bool _isInitialized = false;
  bool _settingsLoaded = false;
  String? _activeModelPath;
  String? _activeConfigPath;
  String? _lastError;
  int _playbackGeneration = 0;
  bool _isReloading = false;

  VoidCallback? _onStart;
  VoidCallback? _onPause;
  VoidCallback? _onCompletion;
  ValueChanged<String>? _onError;

  bool _isPlaying = false;
  bool _isPaused = false;
  String _languageCode = 'id';
  String _voiceStyle = 'F1';
  SharedPreferences? _prefsCache;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get sedangMemutarAntrean => false;
  bool get sudahDiinisialisasi => _isInitialized;
  bool get sedangDownloadModel => false;
  bool get modelSiap => _isInitialized && _activeModelPath != null && _engine != null;
  bool get supportsVoiceStyle =>
      PiperVoiceCatalog.supportsVoiceStyle(_languageCode);
  String? get modelAktifPath => _activeModelPath;
  String? get configAktifPath => _activeConfigPath;
  String? get lastError => _lastError;
  String get kodeBahasa => _languageCode;
  String get gayaSuara => _voiceStyle;
  bool get isBahasaIndonesia => _languageCode == 'id';
  bool get isSuaraLakiLaki => _voiceStyle.startsWith('M');
  String get labelBahasa => _languageCode == 'id' ? 'Indonesia' : 'English';
  String get labelGayaSuara => supportsVoiceStyle
      ? (isSuaraLakiLaki ? 'Laki-laki' : 'Perempuan')
      : 'Piper News';
  String get namaModelAktif => PiperVoiceCatalog.modelNameFor(
    languageCode: _languageCode,
    voiceStyle: _voiceStyle,
  );

  String get _assetOnnx => 'assets/piper/$namaModelAktif.onnx';
  String get _assetJson => 'assets/piper/$namaModelAktif.onnx.json';
  String get _assetRevision =>
      PiperVoiceCatalog.assetRevisions[namaModelAktif] ?? '1';

  Future<SharedPreferences> _prefs() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  Future<void> init() {
    if (_isInitialized && _engine != null) return Future.value();
    // Jika sedang reload, tunggu reload selesai dulu
    if (_isReloading && _initialization != null) return _initialization!;
    if (_initialization != null) return _initialization!;
    _initialization = _initialize().whenComplete(
      () => _initialization = null,
    );
    return _initialization!;
  }

  Future<void> _initialize() async {
    try {
      if (!_settingsLoaded) {
        await _loadSettings();
      }
      await _prepareModel();
      _isInitialized = true;
      _lastError = null;
      debugPrint('[Piper] Model siap: $namaModelAktif');
    } catch (error, stackTrace) {
      _isInitialized = false;
      _lastError = error.toString();
      debugPrint('[Piper] Inisialisasi gagal: $error\n$stackTrace');
      _onError?.call(_lastError!);
      rethrow;
    }
  }

  Future<void> loadSettingsOnly() async {
    if (!_settingsLoaded) {
      await _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final preferences = await _prefs();
    _languageCode = preferences.getString(_languagePreferenceKey) ?? 'id';
    _voiceStyle = preferences.getString(_voiceStylePreferenceKey) ?? 'F1';
    if (_languageCode != 'id' && _languageCode != 'en') _languageCode = 'id';
    if (_voiceStyle != 'M1' && _voiceStyle != 'F1') _voiceStyle = 'F1';
    // Indonesia hanya punya satu suara — paksa F1 agar tidak ada state nyasar M1
    if (_languageCode == 'id') _voiceStyle = 'F1';
    _settingsLoaded = true;
  }

  Future<void> setBahasa(String languageCode) async {
    if (languageCode != 'id' && languageCode != 'en') return;
    await init();
    if (_languageCode == languageCode) return;

    final previousLanguage = _languageCode;
    final previousStyle = _voiceStyle;
    // Jika pindah ke id, paksa F1
    _languageCode = languageCode;
    if (_languageCode == 'id') _voiceStyle = 'F1';

    try {
      await _reloadModel();
      final preferences = await _prefs();
      await preferences.setString(_languagePreferenceKey, languageCode);
      // Simpan gaya juga jika berubah karena pindah ke id
      if (previousStyle != _voiceStyle) {
        await preferences.setString(_voiceStylePreferenceKey, _voiceStyle);
      }
      _lastError = null;
    } catch (e) {
      _languageCode = previousLanguage;
      _voiceStyle = previousStyle;
      // Coba kembalikan model sebelumnya — jangan rethrow tanpa coba restore
      try {
        await _reloadModel();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> setGayaSuara(String voiceStyle) async {
    if (!supportsVoiceStyle) {
      debugPrint('[Piper] setGayaSuara diabaikan: bahasa $_languageCode tidak dukung varian suara');
      return;
    }
    final normalizedStyle = voiceStyle.startsWith('M') ? 'M1' : 'F1';
    await init();
    if (_voiceStyle == normalizedStyle) return;

    final previousStyle = _voiceStyle;
    _voiceStyle = normalizedStyle;
    try {
      await _reloadModel();
      final preferences = await _prefs();
      await preferences.setString(_voiceStylePreferenceKey, normalizedStyle);
      _lastError = null;
    } catch (e) {
      _voiceStyle = previousStyle;
      try {
        await _reloadModel();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _reloadModel() async {
    if (_isReloading) return;
    _isReloading = true;
    try {
      await stop();
      await _disposeEngine();
      _isInitialized = false;
      _activeModelPath = null;
      _activeConfigPath = null;
      // Reset initialization future agar init() benar-benar rebuild
      _initialization = null;
      await init();
    } finally {
      _isReloading = false;
    }
  }

  void setStartHandler(VoidCallback handler) => _onStart = handler;
  void setPauseHandler(VoidCallback handler) => _onPause = handler;
  void setCompletionHandler(VoidCallback handler) => _onCompletion = handler;
  void setErrorHandler(ValueChanged<String> handler) => _onError = handler;
  void setModelProgressHandler(ValueChanged<double> handler) {}

  /// Hapus semua handler — dipanggil saat ChatProvider dispose agar tidak retain.
  void clearHandlers() {
    _onStart = null;
    _onPause = null;
    _onCompletion = null;
    _onError = null;
  }

  String _normalize(String text) {
    if (_languageCode == 'id') {
      return IndonesianTextProcessor.normalizeForMalayVoice(text);
    }
    // English juga perlu dibersihkan minimal (trim + hapus markdown kasar)
    // agar URL/link tidak terbaca aneh
    var t = text.trim();
    // hapus markdown link/image singkat untuk EN
    t = t.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
    t = t.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    t = t.replaceAll(RegExp(r'https?://\S+'), ' ');
    return t.trim();
  }

  Future<void> _prepareModel() async {
    final supportDirectory = await getApplicationSupportDirectory();
    await _removeLegacyIndonesianModel(supportDirectory);
    final modelPath = p.join(supportDirectory.path, '$namaModelAktif.onnx');
    final configPath = p.join(
      supportDirectory.path,
      '$namaModelAktif.onnx.json',
    );
    final modelFile = File(modelPath);
    final configFile = File(configPath);
    final preferences = await _prefs();
    final revisionKey = 'piper_model_revision_$namaModelAktif';
    final shouldCopy =
        preferences.getString(revisionKey) != _assetRevision ||
        !await modelFile.exists() ||
        !await configFile.exists() ||
        await modelFile.length() < 1000 ||
        await configFile.length() < 100;

    if (shouldCopy) {
      debugPrint('[Piper] Memperbarui aset model $namaModelAktif (rev $_assetRevision)');
      try {
        final modelData = await rootBundle.load(_assetOnnx);
        final configData = await rootBundle.load(_assetJson);
        // Tulis file — lakukan sequential agar I/O tidak double memory sekaligus
        await modelFile.writeAsBytes(
          modelData.buffer.asUint8List(
            modelData.offsetInBytes,
            modelData.lengthInBytes,
          ),
          flush: true,
        );
        await configFile.writeAsBytes(
          configData.buffer.asUint8List(
            configData.offsetInBytes,
            configData.lengthInBytes,
          ),
          flush: true,
        );
        await preferences.setString(revisionKey, _assetRevision);
        debugPrint('[Piper] Aset $namaModelAktif berhasil disalin');
      } catch (e) {
        debugPrint('[Piper] Gagal menyalin aset $namaModelAktif: $e');
        // Bersihkan file setengah jadi
        try { if (await modelFile.exists()) await modelFile.delete(); } catch (_) {}
        try { if (await configFile.exists()) await configFile.delete(); } catch (_) {}
        rethrow;
      }
    }

    // Validasi file ada sebelum create engine
    if (!await modelFile.exists() || !await configFile.exists()) {
      throw StateError('Model file tidak ditemukan: $modelPath');
    }

    _activeModelPath = modelPath;
    _activeConfigPath = configPath;
    try {
      _engine = await PiperTTS.create(
        modelPath: modelPath,
        configPath: configPath,
      );
    } catch (e) {
      _activeModelPath = null;
      _activeConfigPath = null;
      rethrow;
    }
  }

  Future<void> _removeLegacyIndonesianModel(Directory directory) async {
    for (final filename in const [
      'id_ID-irwan-low.onnx',
      'id_ID-irwan-low.onnx.json',
    ]) {
      final file = File(p.join(directory.path, filename));
      try {
        if (await file.exists()) {
          await file.delete();
          debugPrint('[Piper] Menghapus aset legacy $filename');
        }
      } catch (error) {
        // File legacy tidak boleh menggagalkan pemuatan model aktif.
        debugPrint('[Piper] Gagal menghapus aset legacy $filename: $error');
      }
    }
  }

  Future<void> pregenerate(String text) async {
    await init();
  }

  Future<void> speak(String text) async {
    final playbackGeneration = ++_playbackGeneration;
    // Hindari pemanggilan stop() beruntun jika tidak sedang memutar, karena dapat merusak audio stream.
    if (_isPlaying || _isPaused) {
      await stop(invalidatePlayback: false);
    }
    try {
      await init();
    } catch (e) {
      if (playbackGeneration == _playbackGeneration) {
        _isPlaying = false;
        _isPaused = false;
        _lastError = e.toString();
        _onError?.call(_lastError!);
      }
      rethrow;
    }
    final engine = _engine;
    final normalizedText = _normalize(text);
    if (engine == null || normalizedText.isEmpty) {
      debugPrint('[Piper] speak dibatalkan: engine null atau teks kosong (normalized len ${normalizedText.length})');
      if (playbackGeneration == _playbackGeneration) _onCompletion?.call();
      return;
    }

    try {
      _isPlaying = true;
      _isPaused = false;
      _onStart?.call();

      // Trik Stream Kickstart:
      // Oboe di Android sering mengalami starvation di frame pertama jika disuruh memutar teks baru.
      // Melakukan pause kilat lalu resume akan memaksa stream untuk memulai ulang aliran datanya
      // tanpa menghentikan buffer yang sedang digenerate.
      unawaited((() async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (playbackGeneration == _playbackGeneration && _isPlaying && !_isPaused) {
          try {
            await engine.pause();
            await Future.delayed(const Duration(milliseconds: 15));
            await engine.resume();
          } catch (_) {}
        }
      })());

      await engine.speak(
        normalizedText,
        phonemizerStrategy: PhonemizerStrategy.dictionaryWithNeuralFallback,
        phonemeChunkSize: 255, // Max chunk size to avoid starvation without blocking
        waitForCompletion: true,
      );

      if (playbackGeneration == _playbackGeneration) {
        _isPlaying = false;
        _onCompletion?.call();
      }
    } catch (error, stackTrace) {
      debugPrint('[Piper] Speak gagal: $error\n$stackTrace');
      if (playbackGeneration == _playbackGeneration) {
        _isPlaying = false;
        _isPaused = false;
        _lastError = error.toString();
        _onError?.call(_lastError!);
      }
    }
  }

  Future<void> pratinjauSuara({String? teksKustom}) async {
    final previewText = teksKustom?.trim().isNotEmpty == true
        ? teksKustom!
        : _languageCode == 'id'
        ? 'Halo, saya Prima, asisten Rumah Sakit Prima Insan Mulia. Ada yang bisa saya bantu?'
        : isSuaraLakiLaki
        ? 'Hello, I am Prima, your hospital assistant. How can I help you today?'
        : 'Hello, I am Prima, your hospital assistant. How may I assist you?';
    await speak(previewText);
  }

  Future<void> stop({bool invalidatePlayback = true}) async {
    if (invalidatePlayback) ++_playbackGeneration;
    try {
      await _engine?.stop();
    } catch (error) {
      debugPrint('[Piper] Stop gagal: $error');
    }
    _isPlaying = false;
    _isPaused = false;
  }

  Future<void> pause() async {
    if (!_isPlaying || _isPaused) return;
    try {
      await _engine?.pause();
      _isPaused = true;
      _onPause?.call();
    } catch (e) {
      debugPrint('[Piper] Pause gagal: $e');
    }
  }

  Future<void> resume() async {
    if (!_isPlaying || !_isPaused) return;
    try {
      await _engine?.resume();
      _isPaused = false;
      _onStart?.call();
    } catch (e) {
      debugPrint('[Piper] Resume gagal: $e');
    }
  }

  Future<void> _disposeEngine() async {
    try {
      await _engine?.dispose();
    } catch (error) {
      debugPrint('[Piper] Dispose gagal: $error');
    } finally {
      _engine = null;
    }
  }

  Future<void> dispose() async {
    await stop();
    await _disposeEngine();
    _isInitialized = false;
    _activeModelPath = null;
    _activeConfigPath = null;
    clearHandlers();
  }
}
