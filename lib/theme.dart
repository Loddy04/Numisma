// theme.dart
// Satu tempat untuk semua warna, font, bayangan, dan gaya komponen aplikasi.
// Kenapa dipisah dari main.dart: kalau nanti ganti warna tema,
// cukup ubah di sini, tidak perlu menyentuh layar manapun.
//
// Cara mengubah tampilan:
//  - Satu warna untuk seluruh aplikasi: ubah nilainya di AppColors.
//  - Gaya komponen (tombol, kolom isian, kartu, dialog, AppBar): ubah di
//    AppTheme.light.
//  - Satu elemen saja: timpa langsung di widget-nya (mis. `fillColor:` pada
//    satu TextFormField); elemen lain tetap mengikuti tema.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna utama bertema "koin tua" — perunggu/emas gelap, cocok
  // untuk aplikasi numismatik (koleksi koin dan uang kertas).
  static const bronze = Color(0xFF8C6239); // cokelat tua logo: aksen utama
  static const gold = Color(0xFFC9A66B); // emas logo
  static const background = Color(0xFFFAF6EE);
  // Cokelat susu lembut untuk kartu dan ubin.
  static const latte = Color(0xFFEADBC8);
  static const surface = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF2A2117);
  static const danger = Color(0xFFB3261E);
  static const success = Color(0xFF2E7D32);

  // Palet lama "buku koleksi"; sebagian layar masih memakainya.
  static const paper = Color(0xFFF1E6D0);
  static const ink = Color(0xFF1E1A14);
  static const maroon = Color(0xFF7A2E24);

  // Palet "elegan modern": latar krem bergradasi halus, kartu hero
  // bergradasi cokelat, latar ikon nav yang aktif.
  static const creamTop = Color(0xFFFBF5EA);
  static const creamBottom = Color(0xFFF2E6D2);
  static const heroDark = Color(0xFF45301F);
  static const heroLight = Color(0xFF9A6B3A);
  static const tileActive = Color(0xFFEDE0CB);

  // Peran warna komponen, supaya mudah ditunjuk saat ingin diubah.
  static const card = Colors.white; // isi kartu dan kolom isian
  static const cardBorder = Color(0xFFEADBC4); // garis tepi tipis
  static const fieldLabel = bronze; // label kecil di atas kolom isian
  static const chipOk = Color(0xFFE1E8D0); // chip syarat terpenuhi
  static const chipOkText = Color(0xFF2E6B2E);
  static const chipOff = Color(0xFFEADFCE); // chip syarat belum terpenuhi
  static const chipOffText = Color(0xFF6B5A44);
  static const dialogBarrier = Color(0xCC2A1A0E); // latar gelap di balik dialog
}

// Bayangan lembut yang dipakai kartu dan tombol: cokelat susu, blur lebar,
// spread negatif supaya mengikuti sudut bulat dan tidak melebar di sisi.
class AppShadows {
  AppShadows._();

  static final soft = [
    BoxShadow(
      color: AppColors.bronze.withValues(alpha: 0.20),
      blurRadius: 22,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  // Kartu hero dan tombol utama: lebih pekat.
  static final strong = [
    BoxShadow(
      color: AppColors.heroDark.withValues(alpha: 0.38),
      blurRadius: 28,
      spreadRadius: -6,
      offset: const Offset(0, 14),
    ),
  ];
}

// Gradasi yang dipakai berulang.
class AppGradients {
  AppGradients._();

  // Latar halaman krem: dari atas ke bawah.
  static const page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.creamTop, AppColors.creamBottom],
  );

  // Cokelat tua ke perunggu: kartu hero, kepala halaman login, tombol utama.
  static const brown = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.heroLight, AppColors.heroDark],
  );
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

  // Tema global "elegan modern": latar krem, kartu putih bersudut bulat dengan
  // bayangan lembut, aksen cokelat tua logo. Layar yang memakai widget Material
  // bawaan (AppBar, tombol, kolom isian, kartu, dialog, Snackbar, tab) ikut
  // berubah tanpa disentuh satu per satu.
  static ThemeData get light {
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.creamTop,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.bronze,
        primary: AppColors.bronze,
        onPrimary: Colors.white,
        surface: AppColors.creamTop,
        onSurface: AppColors.ink,
      ),
      // AppBar menyatu dengan latar krem: judul serif tebal di kiri, ikon
      // cokelat, tanpa garis dan tanpa bayangan.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.creamTop,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.bronze),
        titleTextStyle: AppText.serif(size: 24, weight: FontWeight.w700),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.bronze,
        unselectedLabelColor: AppColors.ink.withValues(alpha: 0.55),
        indicatorColor: AppColors.bronze,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Kartu: putih, sudut bulat, garis krem tipis, bayangan lembut.
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shadowColor: AppColors.bronze.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bronze,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bronze,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.bronze,
          backgroundColor: AppColors.card,
          side: const BorderSide(color: AppColors.cardBorder),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.bronze,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // Kolom isian: putih, sudut bulat, garis krem tipis, garis cokelat saat
      // difokuskan.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: field(AppColors.cardBorder),
        enabledBorder: field(AppColors.cardBorder),
        focusedBorder: field(AppColors.bronze, 1.5),
        errorBorder: field(AppColors.danger),
        focusedErrorBorder: field(AppColors.danger, 1.5),
        hintStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.4)),
        labelStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.65)),
        floatingLabelStyle: const TextStyle(color: AppColors.bronze),
        prefixIconColor: AppColors.bronze,
        suffixIconColor: AppColors.bronze,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 18,
        ),
      ),
      // Dialog dan Snackbar (termasuk pesan hasil login) ikut gaya lembut.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.creamTop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: AppText.serif(size: 24, weight: FontWeight.w700),
        contentTextStyle: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: AppColors.ink.withValues(alpha: 0.75),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.heroDark,
        contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // Lembar bawah (filter, pemilih mata uang, pertanyaan cepat): latar krem
      // dengan sudut atas sangat bulat.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.creamTop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      // Tombol mengambang (mis. "Tambah" di Koleksi): pil cokelat.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.bronze,
        foregroundColor: Colors.white,
        elevation: 4,
        extendedTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.ink.withValues(alpha: 0.12),
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
