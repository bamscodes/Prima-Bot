import 'package:flutter_test/flutter_test.dart';
import 'package:primabot/chatbot_rs/presentation/providers/chat_provider.dart';

void main() {
  group('ChatMessage isAnimated tests', () {
    test('default ChatMessage has isAnimated = true', () {
      final msg = ChatMessage(
        text: 'Hello',
        isBot: false,
        time: DateTime.now(),
      );
      expect(msg.isAnimated, isTrue);
    });

    test('bot message can be initialized with isAnimated = false', () {
      final msg = ChatMessage(
        text: 'Bot Response',
        isBot: true,
        time: DateTime.now(),
        isAnimated: false,
      );
      expect(msg.isAnimated, isFalse);

      msg.isAnimated = true;
      expect(msg.isAnimated, isTrue);
    });
  });

  group('ChatSession title state', () {
    final sessionMap = <String, dynamic>{
      'id': 'session-1',
      'title': 'Judul fallback',
      'created_at': '2026-08-21T12:00:00.000',
      'updated_at': '2026-08-21T12:00:00.000',
    };

    test('shows a pending state until the AI title is resolved', () {
      final session = ChatSession.fromMap({
        ...sessionMap,
        'title_generated': 0,
      });

      expect(session.isTitlePending, isTrue);
    });

    test(
      'uses a resolved state after an AI or fallback title is available',
      () {
        final session = ChatSession.fromMap({
          ...sessionMap,
          'title_generated': 1,
        });

        expect(session.isTitlePending, isFalse);
      },
    );
  });
}
