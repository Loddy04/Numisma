// core/config.dart
// Tempat TUNGGAL untuk membaca rahasia (API key, URL) dari file .env.
// Kenapa di satu file: kalau nanti nama variabel .env berubah, cukup
// diubah di sini, tidak perlu mencari ke semua service.
//
// Nilainya dibaca saat RUNTIME lewat flutter_dotenv (bukan `const`),
// jadi file ini wajib dipakai SETELAH dotenv.load() selesai di main.dart.
// Lihat NUMISMA_GUIDE_0.1.md Bagian 3.1.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Private constructor: class ini hanya kumpulan getter statis,
  // tidak pernah di-instantiate (new Config() tidak masuk akal).
  Config._();

  static String get geminiApiKey => _readRequired('GEMINI_API_KEY');
  static String get supabaseUrl => _readRequired('SUPABASE_URL');
  static String get supabaseAnonKey => _readRequired('SUPABASE_ANON_KEY');

  // Helper kecil: kalau key belum diisi di .env, lempar error yang
  // jelas sekarang juga, daripada error samar "null" di tengah proses
  // scan AI atau sinkronisasi nanti.
  static String _readRequired(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception(
        'Key "$key" belum diisi di file .env. '
        'Salin .env.example ke .env lalu isi nilainya.',
      );
    }
    return value;
  }
}
