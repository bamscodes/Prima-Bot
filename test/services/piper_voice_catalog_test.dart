import 'package:flutter_test/flutter_test.dart';
import 'package:primabot/services/piper_voice_catalog.dart';

void main() {
  group('PiperVoiceCatalog', () {
    test('uses the single official Indonesian Piper model for every style', () {
      expect(
        PiperVoiceCatalog.modelNameFor(languageCode: 'id', voiceStyle: 'F1'),
        'id_ID-news_tts-medium',
      );
      expect(
        PiperVoiceCatalog.modelNameFor(languageCode: 'id', voiceStyle: 'M1'),
        'id_ID-news_tts-medium',
      );
    });

    test('falls back to the bundled Indonesian model for unsupported languages', () {
      final englishFemale = PiperVoiceCatalog.modelNameFor(
        languageCode: 'en',
        voiceStyle: 'F1',
      );
      final englishMale = PiperVoiceCatalog.modelNameFor(
        languageCode: 'en',
        voiceStyle: 'M1',
      );

      expect(englishFemale, 'id_ID-news_tts-medium');
      expect(englishMale, 'id_ID-news_tts-medium');
      expect(PiperVoiceCatalog.supportsVoiceStyle('en'), isFalse);
      expect(PiperVoiceCatalog.assetRevisions.keys, contains(englishFemale));
    });
  });
}
