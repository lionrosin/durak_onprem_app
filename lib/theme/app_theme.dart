import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Durak app theme — dark casino aesthetic with rich green felt and gold accents.
class AppTheme {
  AppTheme._();

  // ── Color Palette ───────────────────────────────────────────────

  // Primary: Deep emerald green (casino felt)
  static const Color feltGreen = Color(0xFF1B4332);
  static const Color feltGreenLight = Color(0xFF2D6A4F);
  static const Color feltGreenDark = Color(0xFF081C15);

  // Accent: Warm gold
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFF0D78C);
  static const Color goldDark = Color(0xFFA67C2E);

  // Cards
  static const Color cardWhite = Color(0xFFF8F4E8);
  static const Color cardShadow = Color(0x40000000);

  // Suits
  static const Color suitRed = Color(0xFFCF2020);
  static const Color suitBlack = Color(0xFF1A1A2E);

  // Surface / Background
  static const Color surfaceDark = Color(0xFF0D1B0F);
  static const Color surfaceCard = Color(0xFF163020);
  static const Color surfaceDialog = Color(0xFF1E3A28);

  // Text
  static const Color textPrimary = Color(0xFFF0EAD6);
  static const Color textSecondary = Color(0xFFA8B5A0);
  static const Color textGold = Color(0xFFD4A843);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFF9800);

  // ── Gradients ───────────────────────────────────────────────────

  static const LinearGradient feltGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [feltGreenDark, feltGreen, feltGreenLight],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldDark, gold, goldLight],
  );

  static const RadialGradient tableGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [feltGreenLight, feltGreen, feltGreenDark],
  );

  static const LinearGradient cardFaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFDF5), cardWhite, Color(0xFFE8E0CC)],
  );

  static const LinearGradient cardBackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF1A237E)],
  );

  // ── Shadows ─────────────────────────────────────────────────────

  static List<BoxShadow> cardShadows = [
    const BoxShadow(
      color: Color(0x60000000),
      blurRadius: 8,
      offset: Offset(2, 4),
    ),
    const BoxShadow(
      color: Color(0x20000000),
      blurRadius: 20,
      offset: Offset(4, 8),
    ),
  ];

  static List<BoxShadow> glowShadows(Color color) => [
        BoxShadow(
          color: color.withAlpha(80),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];

  // ── Glassmorphism ───────────────────────────────────────────────

  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = 16,
    double opacity = 0.15,
  }) {
    final baseColor = color ?? Colors.white;
    return BoxDecoration(
      color: baseColor.withAlpha((opacity * 255).toInt()),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: baseColor.withAlpha(30),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(25),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ── Theme Data ──────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: feltGreenDark,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: feltGreenDark,
        secondary: feltGreenLight,
        onSecondary: textPrimary,
        surface: surfaceCard,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
      ),
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: feltGreenDark,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: goldLight,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withAlpha(50)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withAlpha(50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceCard,
        contentTextStyle: GoogleFonts.outfit(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -1,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    );
  }
}
