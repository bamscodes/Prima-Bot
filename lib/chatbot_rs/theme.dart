import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatbotTheme {
  static const Color primaryColor = Color(0xFF005A71);
  static const Color primaryContainer = Color(0xFF0E7490);
  static const Color secondaryColor = Color(0xFF006C49);
  static const Color backgroundColor = Color(0xFFF8F9FF);
  static const Color onSurfaceColor = Color(0xFF0B1C30);
  static const Color surfaceVariant = Color(0xFFD3E4FE);
  static const Color outlineColor = Color(0xFF6F787D);

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
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: isDark ? const Color(0xFF67E8F9) : primaryColor,
        onPrimary: isDark ? Colors.black : Colors.white,
        primaryContainer: isDark ? const Color(0xFF0891B2) : primaryContainer,
        secondary: secondaryColor,
        surface: isDark ? const Color(0xFF0F172A) : backgroundColor,
        onSurface: isDark ? Colors.white : onSurfaceColor,
        outlineVariant: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: isDark ? Colors.amber.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.5),
        selectionHandleColor: Colors.amber,
        cursorColor: Colors.amber,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : onSurfaceColor,
        ),
        displayMedium: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : onSurfaceColor,
        ),
        displaySmall: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : onSurfaceColor,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.white70 : onSurfaceColor,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.white70 : onSurfaceColor,
          height: 1.6,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
