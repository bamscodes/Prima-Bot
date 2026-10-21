import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'chatbot_rs/theme.dart';
import 'chatbot_rs/screens/splash_screen.dart';
import 'chatbot_rs/presentation/providers/chat_provider.dart';
import 'chatbot_rs/presentation/providers/theme_provider.dart';
import 'chatbot_rs/presentation/providers/locale_provider.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'chatbot_rs/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chatbot_rs/data/datasources/seeder.dart';
import 'services/rag_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env tidak ada di production / CI — lanjut dengan String.fromEnvironment / default
  }

  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('is_first_time') ?? true;

  if (!isFirstTime) {
    // Jalankan seeding dan RAG di background tanpa memblokir UI
    DataSeeder.seedData();
    LayananRag().inisialisasi();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: PrimabotApp(isFirstTime: isFirstTime),
    ),
  );
}

class PrimabotApp extends StatelessWidget {
  final bool isFirstTime;
  const PrimabotApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'Prima Bot',
          debugShowCheckedModeBanner: false,
          theme: ChatbotTheme.lightTheme,
          darkTheme: ChatbotTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDark
                  ? SystemUiOverlayStyle.light.copyWith(
                      statusBarColor: ChatbotTheme.darkBackground,
                      systemNavigationBarColor: ChatbotTheme.darkBackground,
                    )
                  : SystemUiOverlayStyle.dark.copyWith(
                      statusBarColor: ChatbotTheme.lightBackground,
                      systemNavigationBarColor: ChatbotTheme.lightBackground,
                    ),
              child: child!,
            );
          },
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('id'),
            Locale('en'),
          ],
          home: isFirstTime ? const ChatbotSplashScreen() : const ChatScreen(),
        );
      },
    );
  }
}
