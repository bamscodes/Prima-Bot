import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:primabot/main.dart';
import 'package:primabot/chatbot_rs/presentation/providers/chat_provider.dart';
import 'package:primabot/chatbot_rs/presentation/providers/theme_provider.dart';

void main() {
  testWidgets('App initializes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const PrimabotApp(),
      ),
    );

    expect(find.byType(PrimabotApp), findsOneWidget);
  });
}
