// services/auth_service.dart
// Logika register/login/logout. Mengikuti kontrak nama fungsi di
// NUMISMA_GUIDE Bagian 8 -- jangan ganti nama fungsi ini walau
// menambah isinya.
//
// Login memakai EMAIL + password. Nama tampilan (username) hanya untuk
// sapaan dan Profil, bebas dan tidak harus unik.
//
// Akun disimpan di dua tempat: SQLite di HP dan tabel `accounts` di
// Supabase (lewat AccountRemote). Yang ke Supabase hanya email_hash, nama
// tampilan, dan hash bcrypt, tidak pernah email atau password polos.
//
// Alur: screen -> auth_service -> db_helper / account_remote. Layar
// (login_screen, register_screen) TIDAK PERNAH memanggil database langsung.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/crypto_util.dart';
import '../core/db_helper.dart';
import '../core/session_store.dart';
import '../models/user.dart';
import 'account_remote.dart';
import 'chain_service.dart';
import 'notif_service.dart';

class AuthService {
  // --- Pesan error dalam bahasa Indonesia, dibaca langsung oleh UI ---
  static const errNameInvalid = 'Nama tampilan harus 1-30 karakter.';
  static const errEmailInvalid = 'Format email tidak valid.';
  static const errEmailTaken = AccountRemote.errEmailTaken;
  static const errPasswordLength = 'Password harus 8-64 karakter.';
  static const errLoginFailed = 'Email atau password salah.';

  static const maxNameLength = 30;
  static const minPasswordLength = 8;
  static const maxPasswordLength = 64;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // Email dinormalkan (huruf kecil, tanpa spasi di ujung) sebelum diproses,
  // supaya sama dengan yang dihitung emailHash dan yang disimpan.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) =>
      _emailPattern.hasMatch(normalizeEmail(email));

  // null = nama valid. Nama bebas (spasi dan simbol boleh), hanya panjangnya
  // yang dibatasi dan tidak boleh kosong.
  static String? displayNameProblem(String name) {
    final n = name.trim();
    if (n.isEmpty || n.length > maxNameLength) return errNameInvalid;
    return null;
  }

  // null = password memenuhi syarat. Batas atas 64 karena bcrypt hanya
  // membaca 72 byte pertama: password yang sangat panjang akan terpotong
  // diam-diam. Simbol = karakter selain huruf dan angka (spasi tidak
  // dihitung). Pesannya menyebut syarat yang BELUM terpenuhi.
  static String? passwordProblem(String password) {
    final length = password.length;
    if (length < minPasswordLength || length > maxPasswordLength) {
      return errPasswordLength;
    }
    final missing = <String>[
      if (!RegExp(r'[A-Z]').hasMatch(password)) 'huruf besar',
      if (!RegExp(r'[a-z]').hasMatch(password)) 'huruf kecil',
      if (!RegExp(r'[0-9]').hasMatch(password)) 'angka',
      if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) 'simbol',
    ];
    if (missing.isEmpty) return null;
    return 'Password belum memuat ${missing.join(', ')}.';
  }

  final AccountRemote _remote = AccountRemote();

  // Dipanggil dari register_screen. Melempar Exception dengan pesan
  // yang sudah ramah (langsung ditampilkan ke pengguna lewat SnackBar),
  // supaya layar tidak perlu menerjemahkan error teknis.
  //
  // Daftar WAJIB internet: keunikan email diperiksa online dan akun ditulis
  // ke Supabase lebih dulu. Tanpa internet pendaftaran ditolak sebelum
  // apa pun ditulis ke HP, jadi tidak ada akun setengah jadi.
  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final nameProblem = displayNameProblem(username);
    if (nameProblem != null) throw Exception(nameProblem);
    if (!isValidEmail(email)) throw Exception(errEmailInvalid);
    final passProblem = passwordProblem(password);
    if (passProblem != null) throw Exception(passProblem);

    final name = username.trim();
    final normalizedEmail = normalizeEmail(email);
    final emailHash = CryptoUtil.emailHash(normalizedEmail);

    final db = await DbHelper.instance.database;

    // Cek lokal dulu (cepat), baru online. Gagal cepat lebih baik daripada
    // gagal di akhir, sesudah hash bcrypt yang lambat.
    final existing = await db.query(
      'users',
      where: 'email_hash = ?',
      whereArgs: [emailHash],
      limit: 1,
    );
    if (existing.isNotEmpty) throw const AccountException(errEmailTaken);
    if (await _remote.emailExists(emailHash)) {
      throw const AccountException(errEmailTaken);
    }

    final passwordHash = CryptoUtil.hashPassword(password);
    final emailEnc = await CryptoUtil.encryptText(normalizedEmail);
    final now = DateTime.now().toUtc().toIso8601String();

    // Online lebih dulu: kalau gagal, HP belum berubah.
    await _remote.createAccount(
      emailHash: emailHash,
      username: name,
      passwordHash: passwordHash,
      createdAt: now,
    );

    final newUser = User(
      username: name,
      emailEnc: emailEnc,
      emailHash: emailHash,
      passwordHash: passwordHash,
      createdAt: now,
    );
    final insertedId = await db.insert('users', newUser.toMap()..remove('id'));

    // Setiap akun baru langsung punya blok genesis Jejak Catatan. Gagal di
    // sini tidak boleh membatalkan pendaftaran: rantai dibuat otomatis saat
    // koin pertama disimpan atau saat Jejak Catatan dibuka (ensureChain).
    try {
      await ChainService().createGenesis(insertedId);
    } catch (_) {}

    // Sengaja TIDAK membuat session di sini -- setelah daftar,
    // pengguna diarahkan kembali ke layar Login dan harus login
    // manual dulu (lihat register_screen.dart).
    return newUser.copyWith(id: insertedId);
  }

  // Dipanggil dari login_screen. Mengembalikan null kalau email tidak
  // ditemukan ATAU password salah -- sengaja digabung jadi satu pesan error
  // (errLoginFailed), supaya orang luar tidak bisa menebak "email terdaftar
  // tapi password salah" vs "email tidak terdaftar".
  //
  // Urutan: cari di HP dulu. Bila akun tidak ada di HP (mis. aplikasi baru
  // dihapus lalu dipasang lagi), periksa tabel `accounts` di Supabase
  // (butuh internet), cocokkan bcrypt, lalu buat akun lokal dari situ.
  Future<User?> login(String email, String password) async {
    if (!isValidEmail(email)) return null;
    final normalizedEmail = normalizeEmail(email);
    final emailHash = CryptoUtil.emailHash(normalizedEmail);
    final db = await DbHelper.instance.database;

    final rows = await db.query(
      'users',
      where: 'email_hash = ?',
      whereArgs: [emailHash],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final user = User.fromMap(rows.first);
      if (!CryptoUtil.verifyPassword(password, user.passwordHash)) return null;
      await SessionStore.createSession(user.id!);
      return user;
    }

    final remote = await _remote.fetchAccount(emailHash);
    if (remote == null) return null;
    if (!CryptoUtil.verifyPassword(password, remote.passwordHash)) return null;

    // Email yang baru diketik dienkripsi dengan kunci AES HP ini.
    final emailEnc = await CryptoUtil.encryptText(normalizedEmail);
    final restored = User(
      username: remote.username,
      emailEnc: emailEnc,
      emailHash: emailHash,
      passwordHash: remote.passwordHash,
      createdAt: remote.createdAt,
    );
    final id = await db.insert('users', restored.toMap()..remove('id'));

    // Genesis TIDAK dibuat di sini: Jejak Catatan milik akun ini mungkin
    // sudah ada online, dan genesis baru akan bentrok dengan blok #0 yang
    // lama. Pulihkan dulu (sync_service), genesis baru dibuat hanya bila
    // online belum punya blok sama sekali.
    await SessionStore.createSession(id);
    return restored.copyWith(id: id);
  }

  // Mengganti nama tampilan: online lebih dulu supaya HP dan Supabase tetap
  // sama. Tanpa internet, perubahan ditolak dengan pesan ramah.
  Future<User> updateDisplayName(User user, String name) async {
    final problem = displayNameProblem(name);
    if (problem != null) throw Exception(problem);
    final clean = name.trim();

    await _remote.updateUsername(user.emailHash, clean);

    final db = await DbHelper.instance.database;
    await db.update(
      'users',
      {'username': clean},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return user.copyWith(username: clean);
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
