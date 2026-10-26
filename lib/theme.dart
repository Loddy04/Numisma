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

  // Tema global bergaya buku koleksi: latar kertas krem, tinta, aksen cokelat
  // tua logo, garis tipis, sudut lancip. Layar yang memakai widget Material
  // bawaan (AppBar, tombol, kolom isian, kartu, dialog, Snackbar, tab) ikut
  // berubah tanpa disentuh satu per satu.
  static ThemeData get light {
    const line = BorderSide(color: Color(0x401E1A14)); // tinta 25%
    const square = RoundedRectangleBorder();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.bronze,
        primary: AppColors.bronze,
        onPrimary: Colors.white,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
      ),
      // AppBar menyatu dengan kertas: teks tinta serif, garis tipis di bawah
      // (surfaceTintColor transparan supaya tidak berubah warna saat menggulir).
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        shape: const Border(bottom: line),
        titleTextStyle: AppText.serif(size: 22, weight: FontWeight.w600),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.bronze,
        unselectedLabelColor: AppColors.ink.withValues(alpha: 0.6),
        indicatorColor: AppColors.bronze,
        dividerColor: Colors.transparent,
        labelStyle: AppText.serif(size: 16, weight: FontWeight.w600),
        unselectedLabelStyle: AppText.serif(size: 16),
      ),
      // Kartu: isi transparan (warna kertas), satu garis tipis, sudut lancip.
      cardTheme: const CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(side: line),
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bronze,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: square,
          textStyle: AppText.serif(size: 16, weight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bronze,
          foregroundColor: Colors.white,
          shape: square,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.bronze,
          side: const BorderSide(color: AppColors.bronze),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: square,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.bronze,
          shape: square,
        ),
      ),
      // Kolom isian: tanpa isi putih, garis tipis tinta, garis cokelat saat
      // difokuskan, sudut lancip.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: line,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: line,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.bronze, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: AppText.serif(
          size: 16,
          color: AppColors.ink.withValues(alpha: 0.7),
        ),
        floatingLabelStyle: AppText.serif(size: 16, color: AppColors.bronze),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
      // Dialog dan Snackbar (termasuk pesan hasil login) memakai kertas dan
      // garis tipis juga.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(side: line),
        titleTextStyle: AppText.serif(size: 20, weight: FontWeight.w700),
        contentTextStyle: AppText.serif(size: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.serif(size: 15, color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: square,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.ink.withValues(alpha: 0.2),
        thickness: 1,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(color: AppColors.ink),
      ),
    );
  }
}
