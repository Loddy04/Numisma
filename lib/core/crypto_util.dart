// core/crypto_util.dart
// Semua fungsi kriptografi dikumpulkan di satu file ini, supaya
// pembedanya jelas untuk laporan:
// - bcrypt  -> HASH satu arah, khusus PASSWORD (tidak bisa dibalik)
// - AES     -> ENKRIPSI dua arah, untuk data yang perlu dibaca lagi
//              (email, catatan koin)
// - SHA-256 -> HASH satu arah, dipakai nanti di Jejak Catatan (K13)

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoUtil {
  CryptoUtil._();

  static const _secureStorage = FlutterSecureStorage();
  static const _aesKeyStorageKey = 'numisma_aes_key_v1';

  // ---------------------------------------------------------------
  // BAGIAN 1: PASSWORD (bcrypt, satu arah)
  // ---------------------------------------------------------------

  // Membuat hash dari password mentah. bcrypt sudah memuat salt
  // acak di dalam hasilnya (diawali "$2"), jadi tidak perlu
  // menyimpan salt terpisah.
  static String hashPassword(String plainPassword) {
    return BCrypt.hashpw(plainPassword, BCrypt.gensalt());
  }

  // Membandingkan password yang diketik pengguna saat login dengan
  // hash yang tersimpan di database. TIDAK PERNAH mendekripsi hash
  // (memang tidak bisa) -- bcrypt hanya bisa dicocokkan, bukan dibalik.
  static bool verifyPassword(String plainPassword, String storedHash) {
    return BCrypt.checkpw(plainPassword, storedHash);
  }

  // ---------------------------------------------------------------
  // BAGIAN 2: AES (dua arah, untuk email dan catatan)
  // ---------------------------------------------------------------

  // Mengambil kunci AES dari secure storage. Kalau belum ada
  // (pertama kali aplikasi dipakai), buat kunci acak baru dan
  // simpan sekali untuk seterusnya. Dengan begini satu kunci yang
  // sama dipakai untuk semua enkripsi di HP ini.
  static Future<enc.Key> _getOrCreateAesKey() async {
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      return enc.Key.fromBase64(existing);
    }
    final newKey = enc.Key.fromSecureRandom(32); // AES-256
    await _secureStorage.write(key: _aesKeyStorageKey, value: newKey.base64);
    return newKey;
  }

  // Mengenkripsi teks biasa. IV (initialization vector) dibuat acak
  // setiap kali fungsi ini dipanggil -- ini sebabnya ciphertext dari
  // teks yang sama akan selalu berbeda tiap kali dienkripsi ulang.
  // Hasil akhir yang disimpan ke DB = base64(iv + ciphertext),
  // supaya satu kolom TEXT cukup untuk menyimpan keduanya sekaligus.
  static Future<String> encryptText(String plainText) async {
    final key = await _getOrCreateAesKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return base64Encode(combined);
  }

  // Mendekripsi teks yang dihasilkan encryptText(). Membaca 16 byte
  // pertama sebagai IV, sisanya sebagai ciphertext -- urutan ini
  // harus persis sama dengan cara encryptText() menggabungkannya.
  static Future<String> decryptText(String encryptedBase64) async {
    final key = await _getOrCreateAesKey();
    final combined = base64Decode(encryptedBase64);

    final ivBytes = combined.sublist(0, 16);
    final cipherBytes = combined.sublist(16);

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
  }

  // ---------------------------------------------------------------
  // BAGIAN 3: SHA-256 (satu arah, dipakai Jejak Catatan nanti di K13)
  // ---------------------------------------------------------------

  static String sha256OfString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String sha256OfBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  // "Sidik jari" email untuk mencari akun, menjaga keunikan, dan jadi kunci
  // sinkron. Email dinormalkan dulu (huruf kecil, tanpa spasi di ujung)
  // supaya "Budi@Mail.com " dan "budi@mail.com" dianggap sama. Awalan
  // konstan "numisma:" membuat hasilnya berbeda dari tabel hash email umum.
  // Ini HASH, bukan enkripsi: tidak bisa dibalik, tetapi email yang mudah
  // ditebak tetap bisa dicocokkan (keterbatasan Guide 1.6). AES tidak bisa
  // dipakai untuk ini karena ciphertext-nya berbeda tiap kali (IV acak).
  static String emailHash(String email) {
    return sha256OfString('numisma:${email.trim().toLowerCase()}');
  }

  // ---------------------------------------------------------------
  // Helper umum
  // ---------------------------------------------------------------

  // Dipakai untuk token session acak (lihat session_store.dart).
  // Bukan untuk enkripsi, hanya string acak biasa.
  static String randomToken({int length = 32}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
