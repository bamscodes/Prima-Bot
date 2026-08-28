/// Daftar model Piper yang memang dibundel aplikasi.
///
/// Jangan menambahkan model melalui nama file saja: setiap entri harus memiliki
/// pasangan ONNX/config valid dan revisi aset untuk migration di perangkat.
class PiperVoiceCatalog {
  static const Map<String, String> assetRevisions = {
    'id_ID-news_tts-medium': '2025-08-20.1',
    'en_US-amy-medium': '1',
    'en_US-lessac-medium': '1',
  };

  static String modelNameFor({
    required String languageCode,
    required String voiceStyle,
  }) {
    // Piper resmi hanya memiliki satu suara Indonesia yang dibundel aplikasi.
    if (languageCode == 'id') return 'id_ID-news_tts-medium';
    return voiceStyle.startsWith('M')
        ? 'en_US-lessac-medium'
        : 'en_US-amy-medium';
  }

  static bool supportsVoiceStyle(String languageCode) => languageCode == 'en';
}
