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
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/time_util.dart';
import 'screens/auth/splash_screen.dart';
import 'services/notif_service.dart';
import 'theme.dart';

Future<void> main() async {
  // Muat .env lebih dulu. fileName harus sama dengan nama file di
  // root proyek dan di daftar assets pubspec.yaml.
  await dotenv.load(fileName: '.env');

  // Data zona waktu (WIB/WITA/WIT/London) untuk Jam Dunia dan Acara.
  initTimeZones();

  // Supabase hanya dipakai sebagai database dan Storage (akun, sinkron,
  // foto), TANPA Supabase Auth. Harus sesudah dotenv.load karena URL dan
  // anon key dibaca dari .env. Gagal di sini (mis. .env belum diisi) tidak
  // boleh menghalangi aplikasi terbuka: fitur online akan menampilkan
  // pesan ramah saat dipakai, dan fitur offline tetap jalan.
  try {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
  } catch (_) {}

  // Siapkan notifikasi. Penjadwalan ulang pengingat TIDAK dilakukan di sini
  // karena akun yang login belum diketahui; HomeShell yang memanggilnya.
  // Gagal di sini tidak boleh menghalangi aplikasi terbuka.
  try {
    await NotifService().init();
  } catch (_) {}

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
