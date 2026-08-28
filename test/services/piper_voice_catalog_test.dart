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

    test('keeps distinct bundled English voice models', () {
      final female = PiperVoiceCatalog.modelNameFor(
        languageCode: 'en',
        voiceStyle: 'F1',
      );
      final male = PiperVoiceCatalog.modelNameFor(
        languageCode: 'en',
        voiceStyle: 'M1',
      );

      expect(female, 'en_US-amy-medium');
      expect(male, 'en_US-lessac-medium');
      expect(female, isNot(male));
      expect(
        PiperVoiceCatalog.assetRevisions.keys,
        containsAll([female, male]),
      );
    });
  });
}
