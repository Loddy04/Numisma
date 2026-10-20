// services/biometric_service.dart
// Login dengan sidik jari (K3, NUMISMA_GUIDE Bagian 7.3). Mengikuti
// kontrak nama fungsi di Bagian 8: isAvailable, authenticate,
// loginWithBiometric.
//
// Alurnya: pengguna login dengan password dulu, lalu menyalakan
// "Masuk dengan sidik jari" di Profil (enable). Sejak itu, layar Login
// menampilkan tombol sidik jari yang membuat session untuk akun
// tersebut tanpa mengetik password.
//
// Hanya SATU akun per HP yang bisa memakai sidik jari (mengikuti
// `last_biometric_user_id` di shared_preferences). Menyalakannya untuk
// akun lain otomatis mematikannya di akun sebelumnya.

import 'package:local_auth/local_auth.dart';

import '../core/db_helper.dart';
import '../core/session_store.dart';
import '../models/user.dart';

class BiometricService {
  final _auth = LocalAuthentication();

  // True bila HP punya sensor biometrik DAN sudah ada sidik jari/wajah
  // yang terdaftar. canCheckBiometrics saja hanya menandakan perangkat
  // kerasnya ada, belum tentu ada yang terdaftar.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Memunculkan dialog sistem untuk memindai sidik jari. biometricOnly
  // memastikan yang diterima hanya biometrik, bukan PIN/pola layar,
  // supaya "login sidik jari" benar-benar sidik jari. Gagal, dibatalkan,
  // atau error apa pun dianggap false (tanpa crash).
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Pindai sidik jari untuk melanjutkan',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  // Menyalakan login sidik jari untuk [user]. Pengguna HARUS lolos
  // pemindaian dulu, supaya orang lain yang memegang HP yang sedang
  // login tidak bisa mendaftarkan sidik jarinya sendiri.
  // Mengembalikan false bila pemindaian gagal; pengaturan tidak berubah.
  Future<bool> enable(User user) async {
    if (!await authenticate()) return false;

    final db = await DbHelper.instance.database;
    // Satu akun per HP: matikan di akun lain, lalu nyalakan di akun ini.
    await db.update(
      'users',
      {'biometric_enabled': 0},
      where: 'id != ?',
      whereArgs: [user.id],
    );
    await db.update(
      'users',
      {'biometric_enabled': 1},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await SessionStore.setBiometricEnabled(user.id!, true);
    return true;
  }

  // Mematikan tidak perlu pemindaian: mematikan fitur keamanan
  // tambahan bukan tindakan berisiko.
  Future<void> disable(User user) async {
    final db = await DbHelper.instance.database;
    await db.update(
      'users',
      {'biometric_enabled': 0},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    // Flag di shared_preferences hanya dimatikan bila memang akun ini
    // yang terdaftar sebagai akun sidik jari.
    if (await SessionStore.lastBiometricUserId() == user.id) {
      await SessionStore.setBiometricEnabled(user.id!, false);
    }
  }

  // Dipakai layar Login untuk memutuskan perlu menampilkan tombol
  // sidik jari atau tidak.
  Future<bool> canLoginWithBiometric() async {
    if (!await SessionStore.isBiometricEnabled()) return false;
    if (await SessionStore.lastBiometricUserId() == null) return false;
    return isAvailable();
  }

  // Login lewat sidik jari untuk akun yang tadi didaftarkan
  // (last_biometric_user_id). Mengembalikan null bila fitur belum
  // dinyalakan, akunnya sudah tidak ada, atau pemindaian ditolak.
  Future<User?> loginWithBiometric() async {
    final userId = await SessionStore.lastBiometricUserId();
    if (userId == null || !await SessionStore.isBiometricEnabled()) {
      return null;
    }

    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ? AND biometric_enabled = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    if (!await authenticate()) return null;

    await SessionStore.createSession(userId);
    return User.fromMap(rows.first);
  }
}
