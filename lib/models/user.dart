// models/user.dart
// Model data untuk tabel `users` (lihat NUMISMA_GUIDE Bagian 5.1).
// Hanya menyimpan bentuk data, tidak ada logika bisnis di sini
// (logika ada di auth_service.dart dan crypto_util.dart).

class User {
  final int? id; // null sebelum disimpan (AUTOINCREMENT)
  final String username; // nama tampilan bebas, bukan untuk login
  final String emailEnc; // sudah terenkripsi AES, bukan email asli
  final String emailHash; // SHA-256 email: pencarian, keunikan, kunci sinkron
  final String passwordHash; // bcrypt, bukan password asli
  final String? photoPath;
  final bool biometricEnabled;
  final String createdAt; // ISO-8601 UTC

  const User({
    this.id,
    required this.username,
    required this.emailEnc,
    required this.emailHash,
    required this.passwordHash,
    this.photoPath,
    this.biometricEnabled = false,
    required this.createdAt,
  });

  // Dipakai saat menulis ke SQLite (db.insert / db.update).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email_enc': emailEnc,
      'email_hash': emailHash,
      'password_hash': passwordHash,
      'photo_path': photoPath,
      // SQLite tidak punya tipe boolean asli, jadi disimpan 0/1.
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'created_at': createdAt,
    };
  }

  // Dipakai saat membaca baris dari SQLite (hasil db.query).
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      emailEnc: map['email_enc'] as String,
      emailHash: map['email_hash'] as String,
      passwordHash: map['password_hash'] as String,
      photoPath: map['photo_path'] as String?,
      biometricEnabled: (map['biometric_enabled'] as int) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  // copyWith supaya bisa buat salinan User dengan sedikit perubahan
  // (misal setelah toggle biometrik) tanpa menulis ulang semua field.
  User copyWith({
    int? id,
    String? username,
    String? emailEnc,
    String? emailHash,
    String? passwordHash,
    String? photoPath,
    bool? biometricEnabled,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      emailEnc: emailEnc ?? this.emailEnc,
      emailHash: emailHash ?? this.emailHash,
      passwordHash: passwordHash ?? this.passwordHash,
      photoPath: photoPath ?? this.photoPath,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
