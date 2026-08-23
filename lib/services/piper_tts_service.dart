// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_piper_tts/flutter_piper_tts.dart';

import 'indonesian_text_processor.dart';

/// Layanan TTS menggunakan Piper (on-device, ringan, tidak robotik).
/// Mendukung 4 suara: Indonesia (news_tts-medium, irwan-low) dan English (amy, lessac).
///
/// Keunggulan Piper dibanding Supertonic/Edge:
/// - Model kecil (15-20MB per suara, total ~70MB bundle, bukan 400MB)
/// - Tidak perlu download 400MB, langsung pakai setelah install (copy dari assets)
/// - Tidak robotik, neural, sigap (low latency)
/// - Full Flutter, 100% offline
class PiperTtsService {
  static final PiperTtsService _instansi = PiperTtsService._internal();
  factory PiperTtsService() => _instansi;
  PiperTtsService._internal();

  PiperTTS? _mesinPiper;
  bool _sudahDiinisialisasi = false;
  bool _sedangInisialisasi = false;
  String? _modelAktifPath;
  String? _configAktifPath;
  final Map<int, String> _cacheAudio = {};

  Function? _onStart;
  Function? _onPause;
  Function? _onCompletion;
  Function(String)? _onError;

  bool _isPlaying = false;
  bool _isPaused = false;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get sedangMemutarAntrean => false;
  bool get sudahDiinisialisasi => _sudahDiinisialisasi;

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

  // Mapping bahasa+gender ke file model Piper
  // Indonesia: news_tts-medium (perempuan), irwan-low (laki-laki)
  // English: amy-medium (perempuan), lessac-medium (laki-laki)
  String get _namaModelAktif {
    if (_kodeBahasa == 'id') {
      return _gayaSuara.startsWith('M') ? 'id_ID-irwan-low' : 'id_ID-news_tts-medium';
    } else {
      return _gayaSuara.startsWith('M') ? 'en_US-lessac-medium' : 'en_US-amy-medium';
    }
  }

  String get _assetOnnx => 'assets/piper/$_namaModelAktif.onnx';
  String get _assetJson => 'assets/piper/$_namaModelAktif.onnx.json';

  /// Inisialisasi cepat: copy model dari assets ke support dir jika belum ada, lalu buat engine.
  /// Tidak perlu download, langsung pakai.
  Future<void> init() async {
    if (_sudahDiinisialisasi || _sedangInisialisasi) return;
    _sedangInisialisasi = true;
    try {
      await _muatPengaturan();
      await _siapkanModel();
      _sudahDiinisialisasi = true;
      debugPrint('[Piper] Init selesai - model=$_namaModelAktif bahasa=$_kodeBahasa suara=$_gayaSuara');
    } catch (e, st) {
      debugPrint('[Piper] Init gagal: $e $st');
      _onError?.call(e.toString());
    } finally {
      _sedangInisialisasi = false;
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
    if (_kodeBahasa == kodeBahasa) return;
    _kodeBahasa = kodeBahasa;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBahasa, kodeBahasa);
    } catch (_) {}
    _cacheAudio.clear();
    // Ganti model sesuai bahasa+gender baru
    _sudahDiinisialisasi = false;
    await init();
    debugPrint('[Piper] Bahasa diubah ke $kodeBahasa model=$_namaModelAktif');
  }

  Future<void> setGayaSuara(String gaya) async {
    String gayaNormal = 'F1';
    if (gaya.startsWith('M')) gayaNormal = 'M1';
    else if (gaya.startsWith('F')) gayaNormal = 'F1';
    else if (gaya == 'Laki-laki') gayaNormal = 'M1';
    else if (gaya == 'Perempuan') gayaNormal = 'F1';
    if (_gayaSuara == gayaNormal) return;
    _gayaSuara = gayaNormal;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGayaSuara, gayaNormal);
    } catch (_) {}
    _cacheAudio.clear();
    _sudahDiinisialisasi = false;
    await init();
    debugPrint('[Piper] Gaya suara diubah ke $gayaNormal model=$_namaModelAktif');
  }

  Future<void> setKecepatan(double kecepatan) async {
    _kecepatanBicara = kecepatan.clamp(0.8, 1.3);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyKecepatan, _kecepatanBicara);
    } catch (_) {}
    // Piper flutter_piper_tts belum support speed adjust, simpan saja untuk future
  }

  void setStartHandler(Function handler) => _onStart = handler;
  void setPauseHandler(Function handler) => _onPause = handler;
  void setCompletionHandler(Function handler) => _onCompletion = handler;
  void setErrorHandler(Function(String) handler) => _onError = handler;
  void setModelProgressHandler(Function(double) handler) {}

  String _normalisasi(String teks) {
    return IndonesianTextProcessor.normalizeForMalayVoice(teks);
  }

  /// Siapkan file model: copy dari assets ke support dir jika belum ada
  Future<void> _siapkanModel() async {
    final dirSupport = await getApplicationSupportDirectory();
    final modelPath = p.join(dirSupport.path, '$_namaModelAktif.onnx');
    final configPath = p.join(dirSupport.path, '$_namaModelAktif.onnx.json');

    final fileModel = File(modelPath);
    final fileConfig = File(configPath);

    // Jika sudah ada dan valid, langsung pakai
    if (await fileModel.exists() && await fileConfig.exists()) {
      final lenModel = await fileModel.length();
      final lenConfig = await fileConfig.length();
      if (lenModel > 1000 && lenConfig > 100) {
        _modelAktifPath = modelPath;
        _configAktifPath = configPath;
        // Buat engine jika belum atau ganti model
        if (_mesinPiper == null) {
          _mesinPiper = await PiperTTS.create(modelPath: modelPath, configPath: configPath);
        } else {
          // Jika model berganti, dispose lama dan buat baru
          try { await _mesinPiper!.dispose(); } catch (_) {}
          _mesinPiper = await PiperTTS.create(modelPath: modelPath, configPath: configPath);
        }
        return;
      }
    }

    // Copy dari assets
    debugPrint('[Piper] Copy model $_namaModelAktif dari assets...');
    try {
      final dataModel = await rootBundle.load(_assetOnnx);
      final bytesModel = dataModel.buffer.asUint8List(dataModel.offsetInBytes, dataModel.lengthInBytes);
      await fileModel.writeAsBytes(bytesModel, flush: true);

      final dataConfig = await rootBundle.load(_assetJson);
      final bytesConfig = dataConfig.buffer.asUint8List(dataConfig.offsetInBytes, dataConfig.lengthInBytes);
      await fileConfig.writeAsBytes(bytesConfig, flush: true);

      _modelAktifPath = modelPath;
      _configAktifPath = configPath;
      if (_mesinPiper != null) try { await _mesinPiper!.dispose(); } catch (_) {}
      _mesinPiper = await PiperTTS.create(modelPath: modelPath, configPath: configPath);
      debugPrint('[Piper] Model siap: $modelPath');
    } catch (e, st) {
      debugPrint('[Piper] Gagal copy model $_namaModelAktif: $e $st');
      // Fallback: coba cari file di assets tanpa subfolder piper (untuk backward compat)
      rethrow;
    }
  }

  Future<void> pregenerate(String teks) async {
    // Piper sangat cepat, tidak perlu pregenerate file, cukup no-op
    // Tetap panggil init agar model siap
    if (!_sudahDiinisialisasi) await init();
  }

  Future<void> speak(String teks) async {
    if (!_sudahDiinisialisasi) await init();
    if (_mesinPiper == null) {
      await _siapkanModel();
    }
    final String normal = _normalisasi(teks);
    if (normal.trim().isEmpty) {
      _onCompletion?.call();
      return;
    }
    // Jika teks panjang, piper bisa handle langsung, tapi kita pecah agar tidak terlalu lama
    // Piper catatan: tidak support angka, tapi sudah di-normalisasi jadi kata
    try {
      _isPlaying = true;
      _isPaused = false;
      _onStart?.call();
      // Pilih strategi phonemizer yang cepat dan akurat: dictionaryWithNeuralFallback
      await _mesinPiper!.speak(
        normal,
        phonemizerStrategy: PhonemizerStrategy.dictionaryWithNeuralFallback,
        waitForCompletion: true,
      );
      _isPlaying = false;
      _onCompletion?.call();
    } catch (e, st) {
      debugPrint('[Piper] speak error: $e $st');
      _isPlaying = false;
      _onError?.call(e.toString());
      _onCompletion?.call();
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

  Future<void> stop() async {
    try { await _mesinPiper?.stop(); } catch (_) {}
    _isPlaying = false;
    _isPaused = false;
  }

  Future<void> pause() async {
    try { await _mesinPiper?.pause(); _isPaused = true; _onPause?.call(); } catch (_) {}
  }

  Future<void> resume() async {
    try { await _mesinPiper?.resume(); _isPaused = false; _onStart?.call(); } catch (_) {}
  }

  Future<void> dispose() async {
    try { await _mesinPiper?.dispose(); } catch (_) {}
    _sudahDiinisialisasi = false;
    _isPlaying = false;
    _isPaused = false;
  }

  bool get sedangDownloadModel => false;
  bool get modelSiap => _sudahDiinisialisasi;
}
