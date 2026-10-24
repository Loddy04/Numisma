// core/db_helper.dart
// Satu-satunya tempat yang boleh membuka koneksi SQLite dan membuat
// tabel. Service lain (auth_service, coin_repo, dst.) memanggil
// DbHelper.instance.database untuk dapat koneksinya, tidak pernah
// membuka database sendiri-sendiri.
//
// Skema tabel di bawah ini adalah KONTRAK (NUMISMA_GUIDE Bagian 5.1).
// Jangan ubah nama tabel/kolom tanpa memperbarui panduan juga.

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  DbHelper._internal();
  static final DbHelper instance = DbHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // Simpan di folder dokumen aplikasi (khusus app ini, aman dari
    // aplikasi lain), bukan di folder yang bisa diakses publik.
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'numisma.db');

    return openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        // Wajib dinyalakan manual di sqflite, beda dari SQLite
        // command-line yang sudah default ON.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Migrasi versi database (NUMISMA_GUIDE 0.7, Bagian 5.1).
  // Hanya ada satu jalur ke v4, dari versi lama mana pun (v1, v2, atau v3):
  // akun lama dibuang (keputusan pemilik proyek) karena login berpindah ke
  // email dan kolom `email_hash` tidak bisa dihitung dari akun lama
  // (email_enc dienkripsi dengan IV acak). Karena itu semua data milik
  // pengguna ikut dikosongkan, supaya tidak ada baris yatim yang merujuk
  // ke users yang sudah tidak ada.
  // - coins, chain_blocks, game_scores, feedback: skemanya tidak berubah,
  //   cukup dikosongkan.
  // - reminders, events, users: skemanya berubah (events dapat lat/lng,
  //   users dapat email_hash dan username tidak lagi unik), jadi dibuang
  //   lalu dibuat ulang agar sama persis dengan instalasi baru.
  // Urutannya mengikuti arah foreign key: anak dulu, baru induk.
  // rates_cache tidak disentuh karena bukan data pengguna.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS reminders');
      await db.execute('DROP TABLE IF EXISTS events');
      await db.execute('DELETE FROM chain_blocks');
      await db.execute('DELETE FROM coins');
      await db.execute('DELETE FROM game_scores');
      await db.execute('DELETE FROM feedback');
      await db.execute('DROP TABLE IF EXISTS users');
      await _createUsersTable(db);
      await _createEventTables(db);
    }
    // v4 -> v5: Jejak Catatan dijangkarkan ke blockchain (Sepolia); kolom
    // tx_hash menyimpan nomor transaksinya. Hanya menambah kolom, tidak ada
    // data yang hilang. Jalur dari versi lama ikut lewat sini setelah
    // pembangunan ulang di atas, karena tabel chain_blocks-nya belum punya
    // kolom ini.
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE chain_blocks ADD COLUMN tx_hash TEXT');
    }
  }

  // Dipakai onCreate (HP bersih) dan onUpgrade, supaya kedua jalur
  // menghasilkan skema yang sama.
  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email_enc TEXT NOT NULL,
        email_hash TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        photo_path TEXT,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createEventTables(Database db) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        title TEXT NOT NULL,
        start_utc TEXT NOT NULL,
        location TEXT,
        note TEXT,
        lat REAL,
        lng REAL
      )
    ''');
    await db.execute('CREATE INDEX idx_events_user ON events(user_id)');

    // Satu acara maksimal satu pengingat (dijaga kode). Id notifikasi
    // Android = events.id, jadi tidak perlu kolom sendiri.
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL REFERENCES events(id),
        remind_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createUsersTable(db);

    await db.execute('''
      CREATE TABLE coins (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id),
        type TEXT NOT NULL CHECK (type IN ('coin','banknote')),
        country TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        denomination REAL NOT NULL,
        year INTEGER,
        condition TEXT,
        buy_price REAL,
        buy_currency TEXT,
        notes_enc TEXT,
        photo_path TEXT,
        ai_summary TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_coins_user ON coins(user_id)');

    await db.execute('''
      CREATE TABLE chain_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        idx INTEGER NOT NULL,
        ts TEXT NOT NULL,
        coin_id TEXT,
        action TEXT NOT NULL,
        data_hash TEXT NOT NULL,
        photo_hash TEXT,
        photo_source TEXT,
        prev_hash TEXT NOT NULL,
        nonce INTEGER NOT NULL,
        hash TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        tx_hash TEXT,
        UNIQUE (user_id, idx)
      )
    ''');

    // events dan reminders (skema v4) dibuat di _createEventTables.
    await _createEventTables(db);

    await db.execute('''
      CREATE TABLE rates_cache (
        base TEXT NOT NULL,
        target TEXT NOT NULL,
        rate REAL NOT NULL,
        rate_date TEXT,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (base, target)
      )
    ''');

    await db.execute('''
      CREATE TABLE game_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        played_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
        saran TEXT,
        kesan TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Ditutup saat aplikasi benar-benar keluar (jarang dipanggil manual
  // di Flutter, tapi disediakan untuk kelengkapan/testing).
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
