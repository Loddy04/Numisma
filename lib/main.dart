// main.dart
// Titik masuk aplikasi. Urutan di sini penting: .env HARUS sudah
// termuat sebelum widget apa pun mencoba membaca Config, karena
// Config membaca dari dotenv.env yang baru terisi setelah load().
//
// main() dibuat `async` karena dotenv.load() adalah operasi I/O
// (baca file .env yang dibundel sebagai asset).
//
// Catatan: ini kerangka Hari 1 sebatas .env. Inisialisasi SQLite,
// Supabase, notifikasi, dan timezone akan ditambahkan di sini saat
// file-file service terkait dibuat (lihat NUMISMA_GUIDE Bagian 4.2).

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config.dart';

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
      theme: ThemeData(useMaterial3: true),
      // Layar sementara Hari 1: hanya membuktikan .env terbaca.
      // Nanti diganti SplashScreen yang mengecek SessionStore
      // (lihat Bagian 7.2).
      home: const _EnvCheckScreen(),
    );
  }
}

// Layar sementara untuk memverifikasi .env terbaca dengan benar.
// Dihapus/diganti saat SplashScreen dibuat.
class _EnvCheckScreen extends StatelessWidget {
  const _EnvCheckScreen();

  @override
  Widget build(BuildContext context) {
    // Jangan tampilkan key asli di UI, cukup status ada/tidaknya.
    final geminiOk = dotenv.env['GEMINI_API_KEY']?.isNotEmpty ?? false;
    final supabaseUrlOk = dotenv.env['SUPABASE_URL']?.isNotEmpty ?? false;
    final supabaseKeyOk = dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Numisma — cek .env')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GEMINI_API_KEY terisi: $geminiOk'),
            Text('SUPABASE_URL terisi: $supabaseUrlOk'),
            Text('SUPABASE_ANON_KEY terisi: $supabaseKeyOk'),
            const SizedBox(height: 16),
            const Text(
              'Isi .env dengan key asli, lalu hot restart untuk melihat '
              'status berubah menjadi true.',
            ),
          ],
        ),
      ),
    );
  }
}
