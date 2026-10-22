// services/account_remote.dart
// Akun online di tabel Supabase `accounts` (NUMISMA_GUIDE 0.7, Bagian 5.2
// dan 7.2). Tujuannya: keunikan email diperiksa di satu tempat bersama, dan
// akun bisa dipulihkan setelah aplikasi dihapus.
//
// Yang dikirim hanya `email_hash`, nama tampilan, dan hash bcrypt. Email
// polos dan password polos TIDAK PERNAH dikirim. Pemeriksaan password
// dilakukan di aplikasi (bcrypt), bukan di server.
//
// Semua kegagalan jaringan diubah menjadi AccountException berpesan ramah
// supaya layar tinggal menampilkannya.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Kesalahan dengan pesan ramah, langsung ditampilkan ke pengguna.
class AccountException implements Exception {
  final String message;
  const AccountException(this.message);

  @override
  String toString() => message;
}

// Akun seperti tersimpan online. Tidak ada email di sini: email asli hanya
// diketahui pengguna (diketik saat login) dan tersimpan terenkripsi di HP.
class RemoteAccount {
  final String emailHash;
  final String username;
  final String passwordHash;
  final String createdAt; // ISO-8601 UTC

  const RemoteAccount({
    required this.emailHash,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
  });
}

class AccountRemote {
  static const _table = 'accounts';
  static const _timeout = Duration(seconds: 15);

  static const errOffline =
      'Tidak bisa terhubung ke internet. Periksa koneksi lalu coba lagi.';
  static const errTimeout = 'Server terlalu lama menjawab. Coba lagi nanti.';
  static const errGeneric = 'Layanan online sedang bermasalah. Coba lagi nanti.';
  static const errEmailTaken = 'Email sudah terdaftar. Silakan masuk.';

  SupabaseClient get _client => Supabase.instance.client;

  // Menjalankan satu panggilan Supabase dengan batas waktu, lalu
  // menerjemahkan kegagalannya. Bila Supabase belum terinisialisasi
  // (mis. .env belum diisi), `_client` melempar error yang ikut
  // tertangkap di cabang terakhir. Static dan publik karena sync_service
  // memakai penerjemah yang sama.
  //
  // `onDuplicate`: pesan bila baris sudah ada (kode 23505, unique_violation).
  // Maknanya bergantung pada tabelnya, jadi pemanggil yang menentukan;
  // tanpa itu, 23505 dianggap kesalahan umum.
  static Future<T> guard<T>(
    Future<T> Function() call, {
    String? onDuplicate,
  }) async {
    try {
      return await call().timeout(_timeout);
    } on AccountException {
      rethrow;
    } on TimeoutException {
      throw const AccountException(errTimeout);
    } on SocketException {
      throw const AccountException(errOffline);
    } on http.ClientException {
      // Dilempar paket http (dipakai Supabase) saat koneksi gagal.
      throw const AccountException(errOffline);
    } on PostgrestException catch (e) {
      if (e.code == '23505' && onDuplicate != null) {
        throw AccountException(onDuplicate);
      }
      throw const AccountException(errGeneric);
    } catch (_) {
      throw const AccountException(errGeneric);
    }
  }

  Future<bool> emailExists(String emailHash) {
    return guard(() async {
      final row = await _client
          .from(_table)
          .select('email_hash')
          .eq('email_hash', emailHash)
          .maybeSingle();
      return row != null;
    });
  }

  // `createdAt` opsional supaya waktu di HP dan online identik; bila kosong,
  // diisi sekarang.
  Future<void> createAccount({
    required String emailHash,
    required String username,
    required String passwordHash,
    String? createdAt,
  }) {
    return guard(() async {
      await _client.from(_table).insert({
        'email_hash': emailHash,
        'username': username,
        'password_hash': passwordHash,
        'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
      });
    }, onDuplicate: errEmailTaken);
  }

  // null = tidak ada akun dengan hash email itu.
  Future<RemoteAccount?> fetchAccount(String emailHash) {
    return guard(() async {
      final row = await _client
          .from(_table)
          .select()
          .eq('email_hash', emailHash)
          .maybeSingle();
      if (row == null) return null;
      return RemoteAccount(
        emailHash: row['email_hash'] as String,
        username: row['username'] as String,
        passwordHash: row['password_hash'] as String,
        // Nilai timestamptz dari server dinormalkan ke UTC ISO-8601 sama
        // seperti kolom TEXT di SQLite.
        createdAt: DateTime.parse(row['created_at'] as String)
            .toUtc()
            .toIso8601String(),
      );
    });
  }

  Future<void> updateUsername(String emailHash, String username) {
    return guard(() async {
      await _client
          .from(_table)
          .update({'username': username}).eq('email_hash', emailHash);
    });
  }
}
