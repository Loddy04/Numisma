// main.dart
// Titik masuk aplikasi. Urutan di sini penting: .env HARUS sudah
// termuat sebelum widget apa pun mencoba membaca Config, karena
// Config membaca dari dotenv.env yang baru terisi setelah load().
//
// main() dibuat `async` karena dotenv.load() adalah operasi I/O
// (baca file .env yang dibundel sebagai asset).
//
// Status Hari 1: SQLite + auth (register/login/session) sudah jalan.
// Inisialisasi Supabase, notifikasi, dan timezone akan ditambahkan
// di sini saat fitur-fitur terkait dibuat (Hari 3-5).

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/auth/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  // Muat .env lebih dulu. fileName harus sama dengan nama file di
  // root proyek dan di daftar assets pubspec.yaml.
  await dotenv.load(fileName: '.env');

  runApp(const NumismaApp());
}

class NumismaApp extends StatelessWidget {
  const NumismaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Numisma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // SplashScreen yang menentukan tujuan berikutnya: Login (belum
      // pernah daftar / session habis) atau Home (session masih valid).
      home: const SplashScreen(),
    );
  }
}
