import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chatbot_rs/theme.dart';
import 'chatbot_rs/screens/splash_screen.dart';
import 'chatbot_rs/presentation/providers/chat_provider.dart';
import 'chatbot_rs/presentation/providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const PrimabotApp(),
    ),
  );
}

class PrimabotApp extends StatelessWidget {
  const PrimabotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Prima Bot',
          debugShowCheckedModeBanner: false,
          theme: ChatbotTheme.lightTheme,
          darkTheme: ChatbotTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const ChatbotSplashScreen(),
        );
      },
    );
  }
}
