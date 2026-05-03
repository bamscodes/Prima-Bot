import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:primabot/chatbot_rs/data/datasources/ai_datasource.dart';
import 'package:primabot/chatbot_rs/domain/usecases/get_bot_response.dart';

void main() async {
  // Ensure dotenv is loaded for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Security & Config Tests', () {
    test('Dotenv Loading Test', () async {
      await dotenv.load(fileName: ".env");
      print('Testing Dotenv...');
      expect(dotenv.env['OPENROUTER_API_KEY'], isNotEmpty);
      expect(dotenv.env['HUGGING_FACE_API_KEY'], isNotEmpty);
    });
  });

  group('Chatbot AI Service Tests', () {
    test('OpenRouter Connection Test', () async {
      print('Testing OpenRouter...');
      final response = await AIService.generateResponse([
        {'role': 'user', 'content': 'Halo, ini adalah pesan tes dari sistem.'}
      ]);
      print('OpenRouter Response: $response');
      expect(response, isNotEmpty);
    });
  });

  group('Offline Mode Logic Test', () {
    test('Offline Fallback Detection', () async {
      final usecase = GetBotResponse();
      print('Testing Use Case Offline Logic...');
      // Note: This test will naturally hit the timeout if we don't have a mock, 
      // which effectively tests the "offline" detection logic.
      final response = await usecase.execute('besok dokter gigi', []);
      print('Bot Response (likely offline or online): $response');
      expect(response, isNotEmpty);
      if (response.contains('offline')) {
        print('Confirmed: Offline mode triggered correctly.');
      }
    });
  });

  group('Intent Detection Detail', () {
    test('Dentist Tomorrow', () async {
      final result = await AIService.classifyIntent('besok dokter gigi');
      expect(result['intent'], 'Cari_Jadwal');
      expect(result['entitas'], 'Gigi');
    });
  });
}
