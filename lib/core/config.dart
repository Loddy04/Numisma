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

  // AI memakai OpenAI (menggantikan Gemini, keputusan Hari 4). Nama model
  // ditaruh di .env, bukan di kode, supaya ganti model tidak perlu build ulang.
  static String get openaiApiKey => _readRequired('OPENAI_API_KEY');
  static String get openaiModel => _readRequired('OPENAI_MODEL');
  static String get supabaseUrl => _readRequired('SUPABASE_URL');
  static String get supabaseAnonKey => _readRequired('SUPABASE_ANON_KEY');

  // Blockchain (Jejak Catatan dijangkarkan ke testnet Ethereum Sepolia).
  // Kunci privat adalah dompet testnet khusus proyek (tanpa nilai uang) dan
  // ikut terbundel di APK seperti kunci lain, jadi JANGAN pernah memakai
  // kunci dompet berisi uang asli.
  static String get ethPrivateKey => _readRequired('ETH_PRIVATE_KEY');
  static int get ethChainId => int.parse(_readRequired('ETH_CHAIN_ID'));
  static String get ethRpcUrl => _readRequired('ETH_RPC_URL');

  // true bila ketiga nilai blockchain terisi. Bila belum (mis. HP lain tanpa
  // .env lengkap), penjangkaran dimatikan diam-diam dan aplikasi tetap jalan.
  static bool get ethConfigured {
    for (final key in const [
      'ETH_PRIVATE_KEY',
      'ETH_CHAIN_ID',
      'ETH_RPC_URL',
    ]) {
      final v = dotenv.env[key];
      if (v == null || v.isEmpty) return false;
    }
    return int.tryParse(dotenv.env['ETH_CHAIN_ID']!) != null;
  }

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
