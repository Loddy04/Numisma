// theme.dart
// Satu tempat untuk semua warna, font, dan gaya kartu aplikasi.
// Kenapa dipisah dari main.dart: kalau nanti ganti warna tema,
// cukup ubah di sini, tidak perlu menyentuh layar manapun.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna utama bertema "koin tua" — perunggu/emas gelap, cocok
  // untuk aplikasi numismatik (koleksi koin dan uang kertas).
  static const bronze = Color(0xFF8C6239);
  static const gold = Color(0xFFC9A66B);
  static const background = Color(0xFFFAF6EE);
  // Cokelat susu lembut untuk kartu dan ubin di Beranda.
  static const latte = Color(0xFFEADBC8);
  static const surface = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF2A2117);
  static const danger = Color(0xFFB3261E);
  static const success = Color(0xFF2E7D32);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.bronze,
        primary: AppColors.bronze,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bronze,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // Gaya kartu seragam dipakai di coin_card, coin_face, dsb.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bronze,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        bodyMedium: TextStyle(color: AppColors.textDark),
      ),
    );
  }
}
