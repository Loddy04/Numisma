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

  // Palet "buku koleksi" (kertas krem, tinta, merah marun). Dipakai mulai
  // dari Beranda; layar lain masih memakai warna di atas dan dipindah
  // bertahap, jadi warna lama sengaja belum dihapus.
  static const paper = Color(0xFFF1E6D0);
  static const ink = Color(0xFF1E1A14);
  static const maroon = Color(0xFF7A2E24);
}

// Gaya teks bergaya buku lama memakai font bawaan Android (tanpa berkas
// font tambahan): `serif` untuk judul dan nama, `monospace` untuk label
// bergaya mesin ketik. Kesan vintage dibangun dari huruf kapital dengan
// jarak antarhuruf lebar, huruf miring, dan garis, bukan dari font khusus.
class AppText {
  AppText._();

  static TextStyle serif({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: spacing,
    color: color,
  );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color,
  );
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
