import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_edge_tts/flutter_edge_tts.dart';
import 'package:audioplayers/audioplayers.dart';

import 'indonesian_text_processor.dart';

/// Service TTS menggunakan Microsoft Edge TTS (gratis, tanpa API key).
/// Menggunakan suara ms-MY-YasminNeural karena paling natural untuk Bahasa Indonesia.
///
/// Fitur:
/// - Cache audio berdasarkan hash teks yang sudah dinormalisasi
/// - Pre-generate audio di background setelah pesan bot tiba
/// - Cleanup otomatis file temp yang lebih dari 24 jam
/// - Singleton pattern
class EdgeTtsService {
  static final EdgeTtsService _instance = EdgeTtsService._internal();
  factory EdgeTtsService() => _instance;
  EdgeTtsService._internal();

  FlutterEdgeTts? _edgeTts;
  AudioPlayer? _player;
  bool _isInitialized = false;
  StreamSubscription? _playerSubscription;

  /// Cache in-memory: hash teks ternormalisasi → path file audio
  final Map<int, String> _audioCache = {};

  /// Flag untuk mencegah pre-generate berjalan bersamaan
  bool _isPregenerating = false;

  // Callback state untuk update UI
  Function? _onStart;
  Function? _onPause;
  Function? _onCompletion;
  Function(String)? _onError;

  PlayerState get playerState => _player?.state ?? PlayerState.stopped;
  bool get isPlaying => _player?.state == PlayerState.playing;
  bool get isPaused => _player?.state == PlayerState.paused;

  // Gunakan suara Yasmin (Melayu) — mirip 90% dengan Bahasa Indonesia
  static const String _defaultVoice = 'ms-MY-YasminNeural';
  static const String _defaultLocale = 'ms-MY';

  // Prosody: rate 0.9 agar lebih pelan sedikit dan lebih jelas
  static const EdgeTtsProsody _prosody = EdgeTtsProsody(rate: '0.9');

  // File cache dihapus setelah 24 jam
  static const Duration _cacheMaxAge = Duration(hours: 24);

  /// Inisialisasi service. Aman dipanggil berkali-kali (idempotent).
  Future<void> init() async {
    if (_isInitialized) return;

    _edgeTts = FlutterEdgeTts(
      voice: _defaultVoice,
      voiceLocale: _defaultLocale,
      outputFormat: EdgeTtsOutputFormat.audio24Khz96KbitrateMonoMp3,
      enableLogging: kDebugMode,
    );

    _player = AudioPlayer();

    // Batalkan subscription lama untuk mencegah double listener
    await _playerSubscription?.cancel();

    // Dengarkan perubahan status pemutaran untuk update UI
    _playerSubscription = _player!.onPlayerStateChanged.listen((state) {
      debugPrint('[TTS] Status player: $state');
      if (state == PlayerState.playing) {
        _onStart?.call();
      } else if (state == PlayerState.paused) {
        _onPause?.call();
      } else if (state == PlayerState.completed) {
        _onCompletion?.call();
      }
    });

    _isInitialized = true;

    // Bersihkan file TTS lama di background (non-blocking)
    unawaited(_cleanOldCacheFiles());

    debugPrint('[TTS] EdgeTtsService siap digunakan');
  }

  void setStartHandler(Function handler) => _onStart = handler;
  void setPauseHandler(Function handler) => _onPause = handler;
  void setCompletionHandler(Function handler) => _onCompletion = handler;
  void setErrorHandler(Function(String) handler) => _onError = handler;

  /// Normalisasi teks dan hitung cache key-nya.
  /// Selalu gunakan metode ini agar hash konsisten antara pregenerate dan speak.
  String _normalize(String text) {
    return IndonesianTextProcessor.normalizeForMalayVoice(text);
  }

  int _cacheKey(String normalizedText) => normalizedText.hashCode.abs();

  /// Pre-generate audio di background setelah pesan bot baru tiba.
  /// Tujuan: saat user tap play, audio sudah siap → playback mendekati instan.
  Future<void> pregenerate(String text) async {
    if (!_isInitialized) await init();
    if (_isPregenerating) return;

    _isPregenerating = true;
    try {
      // Normalisasi DULU — hash harus konsisten dengan yang dipakai speak()
      final normalized = _normalize(text);
      final key = _cacheKey(normalized);

      // Skip jika sudah ada di cache dan file-nya masih ada
      if (_audioCache.containsKey(key)) {
        final cachedFile = File(_audioCache[key]!);
        if (await cachedFile.exists()) {
          debugPrint('[TTS] Pre-gen: sudah di cache (key=$key), skip');
          return;
        }
      }

      debugPrint('[TTS] Pre-gen: mulai generate di background...');
      final outputPath = await _generateAudioFile(normalized, key);
      if (outputPath != null) {
        _audioCache[key] = outputPath;
        debugPrint('[TTS] Pre-gen selesai: $outputPath');
      }
    } catch (e) {
      debugPrint('[TTS] Pre-gen error: $e');
    } finally {
      _isPregenerating = false;
    }
  }

  /// Baca teks dengan suara YasminNeural.
  /// Alur: Normalize → Cek cache → Generate jika belum ada → Putar
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();

    // Reinit jika player atau edgeTts null (edge case setelah dispose)
    if (_player == null || _edgeTts == null) {
      debugPrint('[TTS] Player null, reinit...');
      _isInitialized = false;
      await init();
    }

    // Hentikan suara yang sedang berjalan jika ada
    try {
      await _player!.stop();
    } catch (_) {}

    // Normalisasi DULU — hash harus sama dengan pregenerate
    final normalized = _normalize(text);
    final key = _cacheKey(normalized);

    debugPrint('[TTS] Teks ternormalisasi (key=$key): "$normalized"');

    try {
      String? audioPath;

      // Cek apakah audio sudah tersedia di cache
      if (_audioCache.containsKey(key)) {
        final cachedFile = File(_audioCache[key]!);
        if (await cachedFile.exists()) {
          audioPath = _audioCache[key];
          debugPrint('[TTS] Cache hit → playback instan');
        } else {
          // File cache sudah terhapus dari storage, hapus dari map juga
          _audioCache.remove(key);
        }
      }

      // Generate baru jika tidak ada di cache
      if (audioPath == null) {
        debugPrint('[TTS] Cache miss → generating audio...');
        audioPath = await _generateAudioFile(normalized, key);
        if (audioPath != null) {
          _audioCache[key] = audioPath;
        }
      }

      if (audioPath == null) {
        throw Exception('Gagal menghasilkan audio TTS');
      }

      // Putar file audio
      await _player!.play(DeviceFileSource(audioPath));
      debugPrint('[TTS] Pemutaran dimulai');
    } catch (e, stackTrace) {
      debugPrint('[TTS] Error saat speak: $e');
      debugPrint('[TTS] StackTrace: $stackTrace');
      _onError?.call(e.toString());
      _onCompletion?.call();
    }
  }

  /// Generate audio ke file temp, kembalikan path jika berhasil.
  Future<String?> _generateAudioFile(String normalizedText, int key) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Simpan di subfolder khusus agar mudah di-cleanup
      final ttsDir = Directory('${tempDir.path}/prima_tts_cache');
      await ttsDir.create(recursive: true);

      final outputPath = '${ttsDir.path}/$key.mp3';

      await _edgeTts!.synthesizeToFile(
        normalizedText,
        audioFilePath: outputPath,
        prosody: _prosody,
      );

      // Verifikasi file berhasil dibuat dan tidak kosong
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        debugPrint('[TTS] File audio tidak terbentuk');
        return null;
      }

      final fileSize = await outputFile.length();
      if (fileSize < 100) {
        debugPrint('[TTS] File audio terlalu kecil ($fileSize bytes)');
        return null;
      }

      debugPrint('[TTS] File audio OK: $fileSize bytes → $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('[TTS] _generateAudioFile error: $e');
      return null;
    }
  }

  /// Hapus file TTS cache yang berusia lebih dari 24 jam.
  /// Dipanggil otomatis saat init(), berjalan di background.
  Future<void> _cleanOldCacheFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ttsDir = Directory('${tempDir.path}/prima_tts_cache');

      if (!await ttsDir.exists()) return;

      final now = DateTime.now();
      int deletedCount = 0;

      await for (final entity in ttsDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age > _cacheMaxAge) {
            await entity.delete();
            deletedCount++;
            // Hapus dari in-memory cache juga
            _audioCache.removeWhere((_, path) => path == entity.path);
          }
        }
      }

      debugPrint('[TTS] Cleanup: $deletedCount file lama dihapus');
    } catch (e) {
      debugPrint('[TTS] Cleanup error: $e');
    }
  }

  /// Hentikan pemutaran suara
  Future<void> stop() async {
    await _player?.stop();
  }

  /// Jeda pemutaran
  Future<void> pause() async => await _player?.pause();

  /// Lanjutkan pemutaran yang dijeda
  Future<void> resume() async => await _player?.resume();

  /// Bersihkan semua resource (dipanggil saat widget di-dispose)
  Future<void> dispose() async {
    await _playerSubscription?.cancel();
    await _player?.dispose();
    await _edgeTts?.close();
    _isInitialized = false;
    debugPrint('[TTS] EdgeTtsService di-dispose');
  }
}
