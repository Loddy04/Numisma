// services/chain_service.dart
// Jejak Catatan (K13, NUMISMA_GUIDE 7.13): setiap tambah/ubah/hapus koin
// dicatat sebagai blok yang terhubung lewat hash SHA-256 (hash chain) dengan
// proof-of-work ringan (hash harus diawali "00"). Ini hash chain pada satu
// perangkat: membuktikan catatan TIDAK DIUBAH DIAM-DIAM sejak dimasukkan,
// bukan bukti koin fisiknya ada, asli, atau milik pengguna (Bagian 1.6).
//
// Alur: screen -> chain_service -> db_helper. CoinRepo memanggil addBlock()
// di dalam transaksinya sendiri, supaya koin dan bloknya tersimpan bersama
// atau gagal bersama.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../core/crypto_util.dart';
import '../core/db_helper.dart';
import '../models/block.dart';
import '../models/coin.dart';

// Hasil verifikasi rantai untuk layar.
class ChainVerifyResult {
  // Masalah per blok: idx -> alasan. Blok yang tidak ada di sini utuh.
  final Map<int, String> blockProblems;
  // Masalah yang tidak menempel ke satu blok (koin tanpa catatan, koin
  // hilang tanpa catatan hapus, dsb.).
  final List<String> coinProblems;
  final int blockCount;

  const ChainVerifyResult({
    required this.blockProblems,
    required this.coinProblems,
    required this.blockCount,
  });

  bool get ok => blockProblems.isEmpty && coinProblems.isEmpty;
}

class ChainService {
  // Syarat proof-of-work: hash blok harus diawali teks ini.
  static const powPrefix = '00';
  // prev_hash blok genesis: 64 karakter '0'.
  static final zeroHash = '0' * 64;

  // ---------------------------------------------------------------
  // BAGIAN 1: rumus hash (murni, tanpa database, mudah diuji)
  // ---------------------------------------------------------------

  // Snapshot koin yang di-hash: HANYA field bermakna dan stabil. Sengaja
  // tanpa notes_enc, ai_summary, photo_path, dan timestamp (ciphertext AES
  // berubah tiap enkripsi karena IV acak). Tipe dijaga tetap: denomination
  // dan buy_price selalu double, year selalu int, supaya 100 dan "100" tidak
  // menghasilkan hash berbeda.
  static Map<String, dynamic> snapshotOf(Coin coin) => {
    'id': coin.id,
    'type': coin.type,
    'country': coin.country,
    'currency_code': coin.currencyCode,
    'denomination': coin.denomination,
    'year': coin.year,
    'condition': coin.condition,
    'buy_price': coin.buyPrice,
    'buy_currency': coin.buyCurrency,
  };

  // JSON kanonik: kunci diurutkan, jadi urutan penyusunan map tidak
  // memengaruhi hash. SHA-256 dari teks itu = data_hash.
  static String dataHashOf(Map<String, dynamic> snapshot) {
    final keys = snapshot.keys.toList()..sort();
    final sorted = {for (final k in keys) k: snapshot[k]};
    return CryptoUtil.sha256OfString(jsonEncode(sorted));
  }

  // Hash blok = SHA-256 dari gabungan field dengan "|". Nilai null ditulis
  // string kosong (bukan "null"); konvensi ini HARUS sama saat membuat dan
  // saat verifikasi, kalau tidak hash tidak akan pernah cocok.
  static String computeHash({
    required int idx,
    required String ts,
    required String? coinId,
    required String action,
    required String dataHash,
    required String? photoHash,
    required String? photoSource,
    required String prevHash,
    required int nonce,
  }) {
    return CryptoUtil.sha256OfString(
      [
        idx,
        ts,
        coinId ?? '',
        action,
        dataHash,
        photoHash ?? '',
        photoSource ?? '',
        prevHash,
        nonce,
      ].join('|'),
    );
  }

  // Proof-of-work: coba nonce 0,1,2,... sampai hash diawali "00" (rata-rata
  // sekitar 256 percobaan, sepersekian detik). Berlaku untuk SEMUA blok,
  // termasuk genesis.
  static ({int nonce, String hash}) mine({
    required int idx,
    required String ts,
    required String? coinId,
    required String action,
    required String dataHash,
    required String? photoHash,
    required String? photoSource,
    required String prevHash,
  }) {
    var nonce = 0;
    while (true) {
      final hash = computeHash(
        idx: idx,
        ts: ts,
        coinId: coinId,
        action: action,
        dataHash: dataHash,
        photoHash: photoHash,
        photoSource: photoSource,
        prevHash: prevHash,
        nonce: nonce,
      );
      if (hash.startsWith(powPrefix)) return (nonce: nonce, hash: hash);
      nonce++;
    }
  }

  // Pemeriksaan struktur rantai (tanpa melihat tabel koin): urutan idx, hash
  // yang dihitung ulang, proof-of-work, dan sambungan prev_hash. Mengembalikan
  // idx -> alasan untuk blok yang bermasalah.
  static Map<int, String> checkBlocks(List<ChainBlock> blocks) {
    final problems = <int, String>{};
    void add(int idx, String why) => problems[idx] = problems.containsKey(idx)
        ? '${problems[idx]}; $why'
        : why;

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.idx != i) add(b.idx, 'Urutan blok tidak runtut');

      final recomputed = computeHash(
        idx: b.idx,
        ts: b.ts,
        coinId: b.coinId,
        action: b.action,
        dataHash: b.dataHash,
        photoHash: b.photoHash,
        photoSource: b.photoSource,
        prevHash: b.prevHash,
        nonce: b.nonce,
      );
      if (recomputed != b.hash) add(b.idx, 'Isi blok tidak cocok dengan hash');
      if (!b.hash.startsWith(powPrefix)) add(b.idx, 'Bukan proof-of-work');

      final expectedPrev = i == 0 ? zeroHash : blocks[i - 1].hash;
      if (b.prevHash != expectedPrev) {
        add(b.idx, 'Tidak tersambung ke blok sebelumnya');
      }
      if (i == 0 && b.action != 'GENESIS') {
        add(b.idx, 'Blok pertama bukan genesis');
      }
    }
    return problems;
  }

  // ---------------------------------------------------------------
  // BAGIAN 2: menulis blok
  // ---------------------------------------------------------------

  Future<ChainBlock?> _lastBlock(DatabaseExecutor ex, int userId) async {
    final rows = await ex.query(
      'chain_blocks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'idx DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChainBlock.fromMap(rows.first);
  }

  // Menambah satu blok di ujung rantai: cari nonce (PoW), lalu simpan.
  Future<ChainBlock> _append(
    DatabaseExecutor ex, {
    required int userId,
    required String? coinId,
    required String action,
    required String dataHash,
    required String? photoHash,
    required String? photoSource,
  }) async {
    final last = await _lastBlock(ex, userId);
    final idx = last == null ? 0 : last.idx + 1;
    final prev = last == null ? zeroHash : last.hash;
    final ts = DateTime.now().toUtc().toIso8601String();

    final found = mine(
      idx: idx,
      ts: ts,
      coinId: coinId,
      action: action,
      dataHash: dataHash,
      photoHash: photoHash,
      photoSource: photoSource,
      prevHash: prev,
    );
    final block = ChainBlock(
      userId: userId,
      idx: idx,
      ts: ts,
      coinId: coinId,
      action: action,
      dataHash: dataHash,
      photoHash: photoHash,
      photoSource: photoSource,
      prevHash: prev,
      nonce: found.nonce,
      hash: found.hash,
    );
    await ex.insert('chain_blocks', block.toMap());
    return block;
  }

  // data_hash blok genesis: tetap (tidak ada koin), supaya kolom NOT NULL
  // terisi dan hasilnya sama untuk semua akun.
  static String get _genesisDataHash => CryptoUtil.sha256OfString('GENESIS');

  Future<void> _ensureGenesis(DatabaseExecutor ex, int userId) async {
    if (await _lastBlock(ex, userId) != null) return;
    await _append(
      ex,
      userId: userId,
      coinId: null,
      action: 'GENESIS',
      dataHash: _genesisDataHash,
      photoHash: null,
      photoSource: 'none',
    );
  }

  // Dibuat saat registrasi. Aman dipanggil ulang: akun yang sudah punya
  // rantai tidak dibuatkan genesis kedua.
  Future<void> createGenesis(int userId) async {
    final db = await DbHelper.instance.database;
    await db.transaction((txn) => _ensureGenesis(txn, userId));
  }

  // Dipanggil CoinRepo di dalam transaksinya (`executor`), supaya koin dan
  // bloknya satu kesatuan. Tanpa `executor`, ia membuka transaksi sendiri.
  // Genesis dibuat otomatis bila akun belum punya rantai.
  Future<void> addBlock({
    required int userId,
    required String coinId,
    required String action,
    required Map<String, dynamic> coinSnapshot,
    Uint8List? photoBytes,
    String photoSource = 'none',
    DatabaseExecutor? executor,
  }) async {
    Future<void> run(DatabaseExecutor ex) async {
      await _ensureGenesis(ex, userId);
      await _append(
        ex,
        userId: userId,
        coinId: coinId,
        action: action,
        dataHash: dataHashOf(coinSnapshot),
        photoHash: photoBytes == null
            ? null
            : CryptoUtil.sha256OfBytes(photoBytes),
        photoSource: photoSource,
      );
    }

    if (executor != null) {
      await run(executor);
    } else {
      final db = await DbHelper.instance.database;
      await db.transaction(run);
    }
  }

  // Blok terakhir untuk satu koin (dipakai CoinRepo.update untuk mewarisi
  // photo_source bila foto tidak diganti).
  Future<ChainBlock?> lastBlockForCoin(
    DatabaseExecutor ex,
    int userId,
    String coinId,
  ) async {
    final rows = await ex.query(
      'chain_blocks',
      where: 'user_id = ? AND coin_id = ?',
      whereArgs: [userId, coinId],
      orderBy: 'idx DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChainBlock.fromMap(rows.first);
  }

  // Untuk akun yang dibuat sebelum fitur ini ada (belum punya rantai sama
  // sekali): buat genesis, lalu catat koin yang sudah ada sebagai blok ADD
  // (waktu blok = waktu pencatatan, bukan waktu koin dibuat). Hanya berjalan
  // sekali per akun; setelah punya rantai, koin tanpa catatan dianggap
  // masalah oleh verify().
  Future<void> ensureChain(int userId) async {
    final db = await DbHelper.instance.database;
    await db.transaction((txn) async {
      if (await _lastBlock(txn, userId) != null) return;
      await _ensureGenesis(txn, userId);

      final rows = await txn.query(
        'coins',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at ASC',
      );
      for (final row in rows) {
        final coin = Coin.fromMap(row);
        final photo = await _readPhoto(coin.photoPath);
        await _append(
          txn,
          userId: userId,
          coinId: coin.id,
          action: 'ADD',
          dataHash: dataHashOf(snapshotOf(coin)),
          photoHash: photo == null ? null : CryptoUtil.sha256OfBytes(photo),
          // Asal fotonya (kamera/galeri) tidak tercatat sebelum fitur ini.
          photoSource: photo == null ? 'none' : 'unknown',
        );
      }
    });
  }

  Future<Uint8List?> _readPhoto(String? path) async {
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<List<ChainBlock>> blocksOf(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'chain_blocks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'idx ASC',
    );
    return rows.map(ChainBlock.fromMap).toList();
  }

  // ---------------------------------------------------------------
  // BAGIAN 3: verifikasi
  // ---------------------------------------------------------------

  // 1) Struktur rantai (checkBlocks). 2) Tiap koin yang masih ada dicocokkan
  // dengan blok TERAKHIR-nya: data_hash dihitung ulang dari baris koin saat
  // ini, dan foto (bila ada di perangkat ini) dibandingkan dengan photo_hash.
  // 3) Koin yang hilang tanpa blok DELETE juga dilaporkan.
  Future<ChainVerifyResult> verify(int userId) async {
    final db = await DbHelper.instance.database;
    final blocks = await blocksOf(userId);
    final problems = checkBlocks(blocks);
    final coinProblems = <String>[];

    void addTo(int idx, String why) => problems[idx] = problems.containsKey(idx)
        ? '${problems[idx]}; $why'
        : why;

    final lastByCoin = <String, ChainBlock>{};
    for (final b in blocks) {
      final id = b.coinId;
      if (id != null) lastByCoin[id] = b; // urut idx, jadi yang terakhir menang
    }

    final rows = await db.query(
      'coins',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final existingIds = <String>{};

    for (final row in rows) {
      final coin = Coin.fromMap(row);
      existingIds.add(coin.id);
      final label = '${coin.country} ${coin.denominationLabel}';
      final last = lastByCoin[coin.id];

      if (last == null) {
        coinProblems.add('$label tidak punya catatan di rantai.');
        continue;
      }
      if (last.action == 'DELETE') {
        coinProblems.add('$label tercatat dihapus, tetapi masih ada.');
        continue;
      }
      if (dataHashOf(snapshotOf(coin)) != last.dataHash) {
        addTo(last.idx, 'Data koin berbeda dari catatan ($label)');
      }

      // Foto dibandingkan hanya bila file-nya ada di perangkat ini. Koin hasil
      // Pulihkan tidak membawa foto (foto tidak ikut sinkron), jadi
      // ketiadaan foto bukan tanda perubahan.
      final photo = await _readPhoto(coin.photoPath);
      if (photo != null && CryptoUtil.sha256OfBytes(photo) != last.photoHash) {
        addTo(last.idx, 'Foto koin berbeda dari catatan ($label)');
      }
    }

    for (final entry in lastByCoin.entries) {
      if (entry.value.action != 'DELETE' && !existingIds.contains(entry.key)) {
        coinProblems.add(
          'Koin ${entry.key.substring(0, 8)}… hilang tanpa catatan hapus.',
        );
      }
    }

    return ChainVerifyResult(
      blockProblems: problems,
      coinProblems: coinProblems,
      blockCount: blocks.length,
    );
  }
}
