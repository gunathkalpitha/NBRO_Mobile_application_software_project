import 'package:flutter/material.dart';

/// NBRO Branding Color Scheme
class NBROColors {
  // Primary Navy Blue
  static const Color primary = Color(0xFF003366);
  static const Color primaryLight = Color(0xFF1A5A96);
  static const Color primaryDark = Color(0xFF001F3F);

  // Accent Colors
  static const Color accent = Color(0xFFFF6B35);
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color light = Color(0xFFF5F5F5);
  static const Color grey = Color(0xFF9CA3AF);
  static const Color darkGrey = Color(0xFF4B5563);
  static const Color black = Color(0xFF1F2937);
}

/// App Theme Configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: NBROColors.primary,
        primary: NBROColors.primary,
        secondary: NBROColors.accent,
        error: NBROColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NBROColors.primary,
        foregroundColor: NBROColors.white,
        elevation: 4,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: NBROColors.accent,
        foregroundColor: NBROColors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NBROColors.primary,
          foregroundColor: NBROColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NBROColors.primary,
          side: const BorderSide(color: NBROColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: NBROColors.black,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: NBROColors.black,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: NBROColors.black,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: NBROColors.darkGrey,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NBROColors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NBROColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: NBROColors.darkGrey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
