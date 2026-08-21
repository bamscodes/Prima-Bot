import 'package:flutter_test/flutter_test.dart';
import 'package:primabot/chatbot_rs/data/datasources/ai_datasource.dart';

void main() {
  group('Intent classification', () {
    test('keeps general questions out of the schedule flow', () async {
      final result = await AIService.classifyIntent(
        'Apakah rumah sakit menerima BPJS?',
      );

      expect(result['intent'], 'Umum');
    });

    test('detects a doctor schedule request locally', () async {
      final result = await AIService.classifyIntent('besok dokter gigi');

      expect(result['intent'], 'Cari_Jadwal');
      expect(result['entitas'], 'Gigi');
    });
  });
}
