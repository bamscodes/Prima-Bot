/// Daftar model Piper yang memang dibundel aplikasi.
///
/// Jangan menambahkan model melalui nama file saja: setiap entri harus memiliki
/// pasangan ONNX/config valid dan revisi aset untuk migration di perangkat.
class PiperVoiceCatalog {
  static const Map<String, String> assetRevisions = {
    'id_ID-news_tts-medium': '2025-08-20.1',
  };

  static String modelNameFor({
    required String languageCode,
    required String voiceStyle,
  }) {
    // Aplikasi ini sekarang hanya memuat 1 suara Indonesia yang dibundel
    return 'id_ID-news_tts-medium';
  }

  static bool supportsVoiceStyle(String languageCode) => false;
}
