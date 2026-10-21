import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:primabot/main.dart';
import 'package:primabot/chatbot_rs/presentation/providers/chat_provider.dart';
import 'package:primabot/chatbot_rs/presentation/providers/theme_provider.dart';
import 'package:primabot/chatbot_rs/presentation/providers/locale_provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App initializes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const PrimabotApp(isFirstTime: true),
      ),
    );

    expect(find.byType(PrimabotApp), findsOneWidget);
  });
}
