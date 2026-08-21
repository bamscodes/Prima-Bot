import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primabot/chatbot_rs/screens/chat_screen.dart';

void main() {
  testWidgets('uses lightweight text until the typewriter is complete', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TypewriterMarkdownBody(
            fullText: '**Halo** dunia',
            theme: ThemeData.light(),
            animate: true,
            onComplete: () => completed = true,
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.byType(Text), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));

    expect(completed, isTrue);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('renders the history title loading skeleton', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HistoryTitleSkeleton())),
    );

    expect(
      find.byKey(const ValueKey('history_title_skeleton')),
      findsOneWidget,
    );
  });
}
