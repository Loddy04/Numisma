// services/sync_service.dart
// Sinkron koin dan blok Jejak Catatan antara SQLite (HP) dan Supabase
// (NUMISMA_GUIDE 0.7, Bagian 7.4). Foto belum ikut di berkas ini.
//
// Dua arah, dua aturan sederhana:
// - upload  : kirim SEMUA koin dan blok yang is_synced = 0, lalu tandai 1.
//             Jalan otomatis tiap perubahan (lewat syncQuietly), tanpa
//             pengguna memilih satu per satu (menghindari kesalahan manusia).
// - restore : ambil data milik akun ini ke HP yang MASIH KOSONG (setelah
//             aplikasi dihapus lalu login lagi). Tanpa penyelesaian konflik:
//             bila ada yang bentrok, dilaporkan dan tidak ditimpa.
//
// Kunci pemilik data = email_hash (kolom `user_key` di Supabase). Tidak ada
// Supabase Auth, jadi semua baris dipisahkan hanya oleh kunci ini.
//
// Kegagalan jaringan menjadi AccountException berpesan ramah (lewat
// AccountRemote.guard). Baris yang gagal terunggah tetap is_synced = 0 dan
// dicoba lagi pada sinkron berikutnya.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
// `User` milik Supabase Auth disembunyikan: yang dipakai di sini User model
// kita (tanpa Supabase Auth).
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../core/crypto_util.dart';
import '../core/db_helper.dart';
import '../models/block.dart';
import '../models/user.dart';
import 'account_remote.dart';
import 'chain_anchor_service.dart';
import 'chain_service.dart';

// Hasil satu kali upload atau restore, untuk ditampilkan di layar Sinkron.
class SyncResult {
  final int coinsUploaded;
  final int blocksUploaded;
  final int coinsRestored;
  final int blocksRestored;
  final int photosUploaded;
  final int photosRestored;
  // Foto yang tidak dipulihkan (gagal diunduh atau hash-nya tidak cocok);
  // koinnya tetap masuk, hanya tanpa foto.
  final int photosSkipped;
  // Blok yang idx-nya sama tetapi hash-nya beda antara HP dan online.
  final List<String> conflicts;
  // Keterangan non-fatal (mis. perangkat tidak kosong, jadi tidak dipulihkan).
  final String? note;

  const SyncResult({
    this.coinsUploaded = 0,
    this.blocksUploaded = 0,
    this.coinsRestored = 0,
    this.blocksRestored = 0,
    this.photosUploaded = 0,
    this.photosRestored = 0,
    this.photosSkipped = 0,
    this.conflicts = const [],
    this.note,
  });

  bool get hasConflict => conflicts.isNotEmpty;
}

class SyncService {
  static const _table = 'chain_blocks';
  static const _pageSize = 1000; // batas baris per permintaan Supabase
  static const _chunkSize = 100; // baris per permintaan tulis
  // Foto koin di Supabase Storage, nama objek "{user_key}/{id_koin}.jpg".
  static const _bucket = 'coin-photos';
  static const _photoTimeout = Duration(seconds: 60);
  // Tanda sekali jalan: koin yang sudah terunggah SEBELUM fitur foto ada perlu
  // diunggah ulang supaya fotonya ikut.
  static const _resyncPrefix = 'photo_resync_v1_';

  static const errBlockConflict =
      'Konflik rantai: ada blok online yang berbeda dari milik HP ini. '
      'Tidak ada yang ditimpa.';
  static const noteNotEmpty =
      'Pulihkan hanya untuk perangkat yang masih kosong. '
      'Data di HP ini tidak diubah.';

  // Mencegah dua sinkron otomatis berjalan bersamaan (mis. tambah dua koin
  // berurutan). Bila ada yang masuk saat sinkron berjalan, diulang sekali
  // lagi setelah selesai supaya perubahan terbaru ikut terkirim.
  static bool _running = false;
  static bool _rerun = false;

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------
  // Pintu otomatis
  // ---------------------------------------------------------------

  // Dipanggil tanpa `await` dari tempat yang tidak boleh terganggu (setelah
  // menyimpan koin, saat Beranda dibuka). Semua kegagalan ditelan: offline
  // bukan kesalahan, barisnya tetap is_synced = 0 dan dicoba lagi nanti.
  static Future<void> syncQuietly(int userId) async {
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        final user = await _userById(userId);
        if (user == null) break;
        final result = await SyncService().upload(user);
        // Setelah data aman di Supabase, blok terakhir dijangkarkan ke
        // blockchain (Sepolia). Bila ada konflik rantai, jangan menjangkarkan
        // rantai yang sedang bermasalah. Kegagalan di sini ditelan di dalam
        // anchorQuietly dan dicoba lagi nanti.
        if (!result.hasConflict) await ChainAnchorService.anchorQuietly(user);
      } while (_rerun);
    } catch (_) {
      // Sengaja diam; lihat komentar di atas.
    } finally {
      _running = false;
    }
  }

  static Future<User?> _userById(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  // ---------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------

  // "N belum diunggah": koin dan blok yang is_synced = 0.
  Future<int> pendingCount(User user) async {
    final db = await DbHelper.instance.database;
    final n = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT (SELECT COUNT(*) FROM coins WHERE user_id = ? AND is_synced = 0)'
        ' + (SELECT COUNT(*) FROM chain_blocks WHERE user_id = ? AND is_synced = 0)',
        [user.id, user.id],
      ),
    );
    return n ?? 0;
  }

  // ---------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------

  Future<SyncResult> upload(User user) async {
    final db = await DbHelper.instance.database;
    final key = user.emailHash;

    await _ensurePhotoResync(user);

    final coinRows = await db.query(
      'coins',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [user.id],
    );
    final blockRows = await db.query(
      _table,
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [user.id],
      orderBy: 'idx ASC',
    );
    if (coinRows.isEmpty && blockRows.isEmpty) return const SyncResult();

    // 1. Koin: upsert (koin yang diubah menimpa versi lamanya). Ditandai
    // terunggah hanya bila updated_at-nya masih sama dengan yang dikirim,
    // supaya koin yang diubah di tengah sinkron tidak salah ditandai.
    //
    // Foto diunggah lebih dulu supaya `has_photo` di baris koin akurat. Foto
    // yang gagal terunggah TIDAK menghalangi sinkron teks: koinnya tetap
    // diunggah, tetapi tidak ditandai tersinkron, jadi fotonya dicoba lagi
    // pada sinkron berikutnya.
    final photoFailed = <String>{};
    var photosUp = 0;
    if (coinRows.isNotEmpty) {
      final payloads = <Map<String, dynamic>>[];
      for (final r in coinRows) {
        final up = await _uploadPhoto(key, r);
        if (up == null) {
          photoFailed.add(r['id'] as String);
        } else if (up) {
          photosUp++;
        }
        payloads.add(_coinPayload(r, key, hasPhoto: up == true));
      }
      for (final chunk in _chunks(payloads)) {
        await AccountRemote.guard(
          () => _client.from('coins').upsert(chunk, onConflict: 'id'),
        );
      }
      final batch = db.batch();
      for (final r in coinRows) {
        if (photoFailed.contains(r['id'])) continue;
        batch.update(
          'coins',
          {'is_synced': 1},
          where: 'id = ? AND updated_at = ?',
          whereArgs: [r['id'], r['updated_at']],
        );
      }
      await batch.commit(noResult: true);
    }

    // 2. Blok. Blok yang sudah ada online dengan hash sama hanya ditandai;
    // yang hash-nya BEDA adalah konflik: dilaporkan, dan blok itu beserta
    // yang sesudahnya tidak diunggah (rantai online tidak boleh bercabang).
    final blocks = blockRows.map(ChainBlock.fromMap).toList();
    final conflicts = <String>[];
    final toInsert = <ChainBlock>[];
    final alreadyThere = <ChainBlock>[];

    if (blocks.isNotEmpty) {
      final remote = await _remoteHashes(key, [for (final b in blocks) b.idx]);
      for (final b in blocks) {
        final remoteHash = remote[b.idx];
        if (remoteHash == null) {
          toInsert.add(b);
        } else if (remoteHash == b.hash) {
          alreadyThere.add(b);
        } else {
          conflicts.add('Blok #${b.idx} berbeda dari yang tersimpan online.');
          break;
        }
      }

      // `insert`, bukan upsert: blok tidak boleh menimpa blok online. Bila
      // ada yang menyelip di antara pengecekan dan penulisan (kode 23505),
      // itu juga konflik.
      for (final chunk in _chunks(toInsert)) {
        await AccountRemote.guard(
          () => _client.from(_table).insert([
            for (final b in chunk) _blockPayload(b, key),
          ]),
          onDuplicate: errBlockConflict,
        );
      }

      final batch = db.batch();
      for (final b in [...toInsert, ...alreadyThere]) {
        batch.update(
          _table,
          {'is_synced': 1},
          where: 'user_id = ? AND idx = ?',
          whereArgs: [user.id, b.idx],
        );
      }
      await batch.commit(noResult: true);

      // Koin yang sudah dihapus tidak perlu tinggal online, begitu pula
      // fotonya. Gagal di sini tidak apa-apa: restore tetap melewati koin
      // yang blok terakhirnya DELETE.
      for (final b in toInsert) {
        if (b.action == 'DELETE' && b.coinId != null) {
          try {
            await AccountRemote.guard(
              () => _client
                  .from('coins')
                  .delete()
                  .eq('id', b.coinId!)
                  .eq('user_key', key),
            );
          } catch (_) {}
          try {
            await AccountRemote.guard(
              () => _client.storage.from(_bucket).remove([
                _photoObject(key, b.coinId!),
              ]),
            );
          } catch (_) {}
        }
      }
    }

    return SyncResult(
      coinsUploaded: coinRows.length - photoFailed.length,
      blocksUploaded: toInsert.length,
      photosUploaded: photosUp,
      conflicts: conflicts,
    );
  }

  // Nama objek foto di Storage.
  String _photoObject(String key, String coinId) => '$key/$coinId.jpg';

  // Mengunggah foto satu koin. Hasil: true = foto terunggah, false = koin ini
  // tidak punya foto (atau filenya sudah hilang), null = gagal (offline,
  // timeout, atau ditolak server).
  Future<bool?> _uploadPhoto(String key, Map<String, Object?> row) async {
    final path = row['photo_path'] as String?;
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists()) return false;
    try {
      final bytes = await file.readAsBytes();
      await AccountRemote.guard(
        () => _client.storage
            .from(_bucket)
            .uploadBinary(
              _photoObject(key, row['id'] as String),
              bytes,
              // upsert: foto yang diganti menimpa foto lama dengan nama sama.
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            ),
        timeout: _photoTimeout,
      );
      return true;
    } catch (_) {
      return null;
    }
  }

  // Koin yang sudah terunggah sebelum fitur foto ada ditandai belum
  // tersinkron SEKALI per akun (bila punya foto lokal), supaya fotonya ikut
  // terunggah. Setelah itu tanda ini tidak dijalankan lagi.
  Future<void> _ensurePhotoResync(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flag = '$_resyncPrefix${user.id}';
      if (prefs.getBool(flag) ?? false) return;
      final db = await DbHelper.instance.database;
      await db.update(
        'coins',
        {'is_synced': 0},
        where: 'user_id = ? AND photo_path IS NOT NULL',
        whereArgs: [user.id],
      );
      await prefs.setBool(flag, true);
    } catch (_) {
      // Gagal menandai tidak fatal; dicoba lagi pada sinkron berikutnya.
    }
  }

  // ---------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------

  // Memulihkan koin dan blok ke HP yang masih kosong. Aturan (Guide 7.4):
  // - HP tidak kosong -> tidak ada yang ditulis; hanya konflik dilaporkan.
  // - Rantai online diperiksa dulu (hash, proof-of-work, sambungan); yang
  //   rusak tidak dipulihkan.
  // - Koin yang blok terakhirnya DELETE tidak dihidupkan lagi.
  // - Online belum punya blok sama sekali -> baru dibuat genesis.
  // Semua penulisan dalam satu transaksi: berhasil seluruhnya atau tidak
  // sama sekali. Foto belum dipulihkan di sini.
  Future<SyncResult> restore(User user) async {
    final db = await DbHelper.instance.database;
    final key = user.emailHash;

    final remoteBlocks = await _fetchBlocks(key, user.id!);

    final localBlocks = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [user.id],
    );
    final localCoinCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM coins WHERE user_id = ?', [
            user.id,
          ]),
        ) ??
        0;

    if (localBlocks.isNotEmpty || localCoinCount > 0) {
      final remoteByIdx = {for (final b in remoteBlocks) b.idx: b.hash};
      final conflicts = <String>[
        for (final r in localBlocks)
          if (remoteByIdx[r['idx'] as int] != null &&
              remoteByIdx[r['idx'] as int] != r['hash'])
            'Blok #${r['idx']} berbeda dari yang tersimpan online.',
      ];
      return SyncResult(conflicts: conflicts, note: noteNotEmpty);
    }

    if (remoteBlocks.isEmpty) {
      // Belum ada apa pun online: rantai baru boleh dimulai.
      await ChainService().createGenesis(user.id!);
      return const SyncResult();
    }

    final problems = ChainService.checkBlocks(remoteBlocks);
    if (problems.isNotEmpty) {
      final first = problems.entries.first;
      throw AccountException(
        'Catatan online tidak utuh (blok #${first.key}: ${first.value}). '
        'Pemulihan dibatalkan.',
      );
    }

    // Aksi terakhir per koin (blok sudah urut idx, yang terakhir menang).
    final lastAction = <String, String>{};
    for (final b in remoteBlocks) {
      if (b.coinId != null) lastAction[b.coinId!] = b.action;
    }

    final remoteCoins = await _fetchCoins(key);
    final toRestore = [
      for (final c in remoteCoins)
        if (lastAction[c['id'] as String] != 'DELETE') c,
    ];

    await db.transaction((txn) async {
      for (final c in toRestore) {
        await txn.insert('coins', _coinRowFromRemote(c, user.id!));
      }
      for (final b in remoteBlocks) {
        await txn.insert(_table, b.toMap());
      }
    });

    // Foto dipulihkan SESUDAH data teks tersimpan, satu per satu. Tiap foto
    // dicek dengan photo_hash di blok terakhir koin itu (SHA-256 byte foto);
    // yang gagal diunduh atau hash-nya beda dilewati tanpa menggagalkan
    // apa pun, karena data teks sudah aman di HP.
    final expectedHash = <String, String?>{};
    for (final b in remoteBlocks) {
      if (b.coinId != null) expectedHash[b.coinId!] = b.photoHash;
    }
    var photosRestored = 0;
    var photosSkipped = 0;
    for (final c in toRestore) {
      if (c['has_photo'] != true) continue;
      final id = c['id'] as String;
      final expected = expectedHash[id];
      if (expected == null) continue; // blok tidak mencatat foto
      if (await _restorePhoto(db, key, id, expected)) {
        photosRestored++;
      } else {
        photosSkipped++;
      }
    }

    return SyncResult(
      coinsRestored: toRestore.length,
      blocksRestored: remoteBlocks.length,
      photosRestored: photosRestored,
      photosSkipped: photosSkipped,
    );
  }

  // Mengunduh satu foto, mencocokkannya dengan hash di Jejak Catatan, lalu
  // menyimpannya ke folder aplikasi dan mencatat path-nya di baris koin.
  // Mengembalikan false untuk kegagalan apa pun (tidak pernah melempar).
  Future<bool> _restorePhoto(
    Database db,
    String key,
    String coinId,
    String expectedHash,
  ) async {
    try {
      final bytes = await AccountRemote.guard(
        () => _client.storage.from(_bucket).download(_photoObject(key, coinId)),
        timeout: _photoTimeout,
      );
      if (CryptoUtil.sha256OfBytes(bytes) != expectedHash) return false;

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'coin_photos'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(dir.path, '${coinId}_$stamp.jpg'));
      await file.writeAsBytes(bytes);

      await db.update(
        'coins',
        {'photo_path': file.path},
        where: 'id = ?',
        whereArgs: [coinId],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------

  Iterable<List<T>> _chunks<T>(List<T> items) sync* {
    for (var i = 0; i < items.length; i += _chunkSize) {
      final end = i + _chunkSize < items.length ? i + _chunkSize : items.length;
      yield items.sublist(i, end);
    }
  }

  // idx -> hash blok yang sudah ada online untuk idx-idx ini.
  Future<Map<int, String>> _remoteHashes(String key, List<int> idxs) async {
    final result = <int, String>{};
    for (final chunk in _chunks(idxs)) {
      final rows = await AccountRemote.guard(
        () => _client
            .from(_table)
            .select('idx, hash')
            .eq('user_key', key)
            .inFilter('idx', chunk),
      );
      for (final r in rows) {
        result[r['idx'] as int] = r['hash'] as String;
      }
    }
    return result;
  }

  // Semua blok milik kunci ini, urut idx. Diambil per halaman karena Supabase
  // membatasi jumlah baris per permintaan.
  Future<List<ChainBlock>> _fetchBlocks(String key, int localUserId) async {
    final blocks = <ChainBlock>[];
    for (var from = 0; ; from += _pageSize) {
      final rows = await AccountRemote.guard(
        () => _client
            .from(_table)
            .select()
            .eq('user_key', key)
            .order('idx', ascending: true)
            .range(from, from + _pageSize - 1),
      );
      for (final r in rows) {
        blocks.add(
          ChainBlock(
            userId: localUserId,
            idx: r['idx'] as int,
            // Dinormalkan ke UTC ISO-8601 seperti yang ditulis HP. Nilai ts
            // ikut dalam hash blok, jadi bentuknya harus sama persis.
            ts: _isoUtc(r['ts'] as String),
            coinId: r['coin_id'] as String?,
            action: r['action'] as String,
            dataHash: r['data_hash'] as String,
            photoHash: r['photo_hash'] as String?,
            photoSource: r['photo_source'] as String?,
            prevHash: r['prev_hash'] as String,
            nonce: (r['nonce'] as num).toInt(),
            hash: r['hash'] as String,
            isSynced: true,
            // Ada bila kolom tx_hash sudah ditambahkan di Supabase; bila
            // belum, nilainya kosong dan tidak mengganggu.
            txHash: r['tx_hash'] as String?,
          ),
        );
      }
      if (rows.length < _pageSize) break;
    }
    return blocks;
  }

  Future<List<Map<String, dynamic>>> _fetchCoins(String key) async {
    final coins = <Map<String, dynamic>>[];
    for (var from = 0; ; from += _pageSize) {
      final rows = await AccountRemote.guard(
        () => _client
            .from('coins')
            .select()
            .eq('user_key', key)
            .order('created_at', ascending: true)
            .range(from, from + _pageSize - 1),
      );
      coins.addAll(rows);
      if (rows.length < _pageSize) break;
    }
    return coins;
  }

  // Waktu dari Supabase (timestamptz, mis. "...+00:00") -> teks UTC
  // ISO-8601 seperti kolom TEXT di SQLite.
  static String _isoUtc(String value) =>
      DateTime.parse(value).toUtc().toIso8601String();

  // Baris SQLite -> payload Supabase. photo_path tidak ikut (path hanya
  // berarti di HP ini); has_photo menandai ada foto di Storage.
  Map<String, dynamic> _coinPayload(
    Map<String, Object?> r,
    String key, {
    required bool hasPhoto,
  }) => {
    'id': r['id'],
    'user_key': key,
    'type': r['type'],
    'country': r['country'],
    'currency_code': r['currency_code'],
    'denomination': r['denomination'],
    'year': r['year'],
    'condition': r['condition'],
    'buy_price': r['buy_price'],
    'buy_currency': r['buy_currency'],
    'notes_enc': r['notes_enc'],
    'ai_summary': r['ai_summary'],
    'has_photo': hasPhoto,
    'created_at': r['created_at'],
    'updated_at': r['updated_at'],
  };

  Map<String, dynamic> _blockPayload(ChainBlock b, String key) => {
    'id': '$key:${b.idx}',
    'user_key': key,
    'idx': b.idx,
    'ts': b.ts,
    'coin_id': b.coinId,
    'action': b.action,
    'data_hash': b.dataHash,
    'photo_hash': b.photoHash,
    'photo_source': b.photoSource,
    'prev_hash': b.prevHash,
    'nonce': b.nonce,
    'hash': b.hash,
  };

  // Baris Supabase -> baris SQLite. is_synced = 1 karena data ini memang
  // berasal dari online; photo_path kosong sampai foto dipulihkan.
  Map<String, dynamic> _coinRowFromRemote(Map<String, dynamic> c, int userId) =>
      {
        'id': c['id'],
        'user_id': userId,
        'type': c['type'],
        'country': c['country'],
        'currency_code': c['currency_code'],
        'denomination': (c['denomination'] as num).toDouble(),
        'year': c['year'],
        'condition': c['condition'],
        'buy_price': (c['buy_price'] as num?)?.toDouble(),
        'buy_currency': c['buy_currency'],
        'notes_enc': c['notes_enc'],
        'photo_path': null,
        'ai_summary': c['ai_summary'],
        'created_at': _isoUtc(c['created_at'] as String),
        'updated_at': _isoUtc(c['updated_at'] as String),
        'is_synced': 1,
      };
}
