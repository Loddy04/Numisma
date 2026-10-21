// services/auth_service.dart
// Logika register/login/logout. Mengikuti kontrak nama fungsi di
// NUMISMA_GUIDE Bagian 8 -- jangan ganti nama fungsi ini walau
// menambah isinya.
//
// Alur: screen -> auth_service -> db_helper. Layar (login_screen,
// register_screen) TIDAK PERNAH memanggil database langsung.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/crypto_util.dart';
import '../core/db_helper.dart';
import '../core/session_store.dart';
import '../models/user.dart';
import 'notif_service.dart';

class AuthService {
  // --- Pesan error dalam bahasa Indonesia, dibaca langsung oleh UI ---
  static const errUsernameTaken = 'Username sudah dipakai, coba yang lain.';
  static const errUsernameInvalid =
      'Username harus 4-20 karakter: huruf, angka, atau garis bawah.';
  static const errEmailInvalid = 'Format email tidak valid.';
  static const errPasswordTooShort = 'Password minimal 8 karakter.';
  static const errLoginFailed = 'Username atau password salah.';

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{4,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Dipanggil dari register_screen. Melempar Exception dengan pesan
  // yang sudah ramah (langsung ditampilkan ke pengguna lewat SnackBar),
  // supaya layar tidak perlu menerjemahkan error teknis.
  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (!_usernamePattern.hasMatch(username)) {
      throw Exception(errUsernameInvalid);
    }
    if (!_emailPattern.hasMatch(email)) {
      throw Exception(errEmailInvalid);
    }
    if (password.length < 8) {
      throw Exception(errPasswordTooShort);
    }

    final db = await DbHelper.instance.database;

    // Cek keunikan username dulu, sebelum proses hash/enkripsi yang
    // lebih berat -- gagal cepat lebih baik daripada gagal di akhir.
    final existing = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception(errUsernameTaken);
    }

    final passwordHash = CryptoUtil.hashPassword(password);
    final emailEnc = await CryptoUtil.encryptText(email);
    final now = DateTime.now().toUtc().toIso8601String();

    final newUser = User(
      username: username,
      emailEnc: emailEnc,
      passwordHash: passwordHash,
      createdAt: now,
    );

    final insertedId = await db.insert('users', newUser.toMap()..remove('id'));

    // TODO (Hari 4, Bagian 7.13): panggil ChainService.createGenesis()
    // di sini begitu chain_service.dart dibuat, supaya setiap akun
    // baru langsung punya blok genesis.

    // Sengaja TIDAK membuat session di sini -- setelah daftar,
    // pengguna diarahkan kembali ke layar Login dan harus login
    // manual dulu (lihat register_screen.dart).
    return newUser.copyWith(id: insertedId);
  }

  // Dipanggil dari login_screen. Mengembalikan null kalau username
  // tidak ditemukan ATAU password salah -- sengaja digabung jadi satu
  // pesan error (errLoginFailed), supaya orang luar tidak bisa menebak
  // "username ada tapi password salah" vs "username tidak ada".
  Future<User?> login(String username, String password) async {
    final db = await DbHelper.instance.database;

    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final user = User.fromMap(rows.first);
    final passwordMatches = CryptoUtil.verifyPassword(
      password,
      user.passwordHash,
    );
    if (!passwordMatches) return null;

    await SessionStore.createSession(user.id!);
    return user;
  }

  Future<void> logout() async {
    // Alarm pengingat milik akun ini dibatalkan lebih dulu: alarm Android
    // per perangkat, sedangkan acara per akun. Gagal membatalkan tidak boleh
    // menghalangi logout.
    try {
      final user = await currentUser();
      if (user != null) await NotifService().cancelAllForUser(user.id!);
    } catch (_) {}
    await SessionStore.clearSession();
  }

  // Dipanggil dari SplashScreen untuk cek "siapa yang login sekarang",
  // dan dari layar lain (Profil, dll.) yang butuh data user aktif.
  Future<User?> currentUser() async {
    final userId = await SessionStore.validUserId();
    if (userId == null) return null;

    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    return User.fromMap(rows.first);
  }

  // Dipakai Profil untuk menampilkan email asli (didekripsi untuk
  // ditampilkan di layar, tidak pernah ditulis balik ke DB sebagai
  // teks biasa).
  Future<String> decryptedEmail(User user) {
    return CryptoUtil.decryptText(user.emailEnc);
  }

  // Menyimpan foto profil: byte foto ditulis sebagai file di folder
  // aplikasi, lalu path-nya disimpan ke users.photo_path (tabel hanya
  // menyimpan path, bukan gambarnya -- Bagian 5.1). Nama file memuat
  // cap waktu supaya foto yang diganti tidak tampil dari cache lama,
  // dan file foto sebelumnya dihapus agar tidak menumpuk.
  Future<User> updateProfilePhoto(User user, Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'profile_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, '${user.id}_$stamp.jpg'));
    await file.writeAsBytes(bytes);

    final db = await DbHelper.instance.database;
    await db.update(
      'users',
      {'photo_path': file.path},
      where: 'id = ?',
      whereArgs: [user.id],
    );

    final old = user.photoPath;
    if (old != null) {
      final oldFile = File(old);
      if (await oldFile.exists()) await oldFile.delete();
    }

    return user.copyWith(photoPath: file.path);
  }
}
