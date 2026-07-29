import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ultra-premium OLED Black palette - Vercel/Stripe inspired
  static const Color background = Color(0xFF000000);
  static const Color surface =
      Color(0xFF000000); // Pure black for seamless depth
  static const Color accent = Color(0xFF00D1FF); // Electric Cyan (Vibe Coder)
  static const Color primary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF888888);
  static const Color error = Color(0xFFFF453A); // Electric Red (Danger)
  static const Color warning = Color(0xFFFF9F0A); // Electric Orange (Warning)
  
  // Premium Technical Palette
  static const Color terminalGreen = Color(0xFF00FF94);
  static const Color terminalDim = Color(0xFF00442D);
  static const Color surfaceLighter = Color(0xFF111111);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: accent,
        onPrimary: background,
        secondary: primary,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            color: primary,
            fontSize: 32,
            fontWeight: FontWeight.w800, // Extra bold for that premium look
            letterSpacing: -1.2,
          ),
          displayMedium: TextStyle(
            color: primary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          bodyLarge: TextStyle(
            color: primary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.4,
          ),
          bodyMedium: TextStyle(
            color: secondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8), // Sharper corners like Vercel
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: Colors.white.withOpacity(0.08)), // Subtle border
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
