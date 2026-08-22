import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/widgets/app_motion.dart';

class ChatbotTheme {
  // Light Mode Figma Redesign
  static const Color lightBackground = Color(0xFFF7F9F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBrandPrimary = Color(0xFF53B3A7);
  static const Color lightTextMain = Color(0xFF3C3D3F);
  static const Color lightTextSubtitle = Color(0xFF9D9D9D);

  // Dark Mode Figma Redesign
  static const Color darkBackground = Color(0xFF16181A);
  static const Color darkSurface = Color(0xFF3C3D3F);
  static const Color brandPrimary = Color(0xFF53B3A7);
  static const Color textMain = Color(0xFFFFFFFF);
  static const Color textSubtitle = Color(0xFF9D9D9D);
  static const Color buttonNo = Color(0xFFF7F9F9);

  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: isDark ? brandPrimary : lightBrandPrimary,
        brightness: brightness,
        primary: isDark ? brandPrimary : lightBrandPrimary,
        onPrimary: isDark ? Colors.white : Colors.white,
        primaryContainer: isDark
            ? brandPrimary.withValues(alpha: 0.2)
            : lightBrandPrimary.withValues(alpha: 0.2),
        secondary: isDark ? darkSurface : lightSurface,
        surface: isDark ? darkBackground : lightBackground,
        onSurface: isDark ? textMain : lightTextMain,
        outlineVariant: isDark ? darkSurface : const Color(0xFFE2E8F0),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: isDark
            ? brandPrimary.withValues(alpha: 0.4)
            : lightBrandPrimary.withValues(alpha: 0.4),
        selectionHandleColor: isDark ? brandPrimary : lightBrandPrimary,
        cursorColor: isDark ? brandPrimary : lightBrandPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: isDark ? textMain : lightTextMain,
        ),
        displayMedium: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: isDark ? textMain : lightTextMain,
        ),
        displaySmall: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? textMain : lightTextMain,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: isDark ? textMain : lightTextMain,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: isDark ? textMain : lightTextMain,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: isDark ? textSubtitle : lightTextSubtitle,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
          color: isDark ? textSubtitle : lightTextSubtitle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? brandPrimary : lightBrandPrimary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              28,
            ), // Fully rounded for Let's Chat Now
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : lightSurface,
        hintStyle: GoogleFonts.manrope(
          color: isDark ? textSubtitle : lightTextSubtitle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkSurface : lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? darkBackground : lightBackground,
        elevation: 0,
      ),
    );
  }
}
