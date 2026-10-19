// core/session_store.dart
// Menyimpan dan membaca status "siapa yang sedang login" di
// shared_preferences (bukan di SQLite), supaya SplashScreen bisa
// cek status login dengan cepat tanpa buka koneksi database dulu.

import 'package:shared_preferences/shared_preferences.dart';

import 'crypto_util.dart';

class SessionStore {
  SessionStore._();

  static const _keyUserId = 'session_user_id';
  static const _keyToken = 'session_token';
  static const _keyExpiresAt = 'session_expires_at';

  static const _keyBiometricEnabled = 'biometric_enabled_flag';
  static const _keyLastBiometricUserId = 'last_biometric_user_id';

  // Dipanggil setelah login/register berhasil. Token acak dibuat
  // di sini (bukan dari server, karena memang tidak ada server),
  // hanya untuk menandai "sesi ini sah" -- bukan untuk keamanan
  // tingkat produksi.
  static Future<void> createSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = CryptoUtil.randomToken();
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));

    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyExpiresAt, expiresAt.toIso8601String());
  }

  // Dipanggil dari SplashScreen. Mengembalikan user_id kalau session
  // masih ada DAN belum lewat expires_at. Mengembalikan null kalau
  // belum pernah login atau sudah kedaluwarsa (7 hari).
  static Future<int?> validUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    final expiresAtStr = prefs.getString(_keyExpiresAt);

    if (userId == null || expiresAtStr == null) return null;

    final expiresAt = DateTime.tryParse(expiresAtStr);
    if (expiresAt == null) return null;

    final stillValid = DateTime.now().toUtc().isBefore(expiresAt);
    return stillValid ? userId : null;
  }

  // Dipanggil saat logout. Hanya menghapus data session, TIDAK
  // menghapus flag biometrik -- supaya tombol "Masuk dengan sidik
  // jari" di layar login tetap muncul untuk login berikutnya.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyExpiresAt);
  }

  // --- Preferensi biometrik (dipakai mulai Hari 2, Bagian 7.3) ---
  // Disiapkan sekaligus di sini supaya session_store jadi satu-satunya
  // tempat baca/tulis shared_preferences terkait akun.

  static Future<void> setBiometricEnabled(int userId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    if (enabled) {
      await prefs.setInt(_keyLastBiometricUserId, userId);
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<int?> lastBiometricUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastBiometricUserId);
  }
}
