// services/coin_repo.dart
// Satu-satunya tempat yang membaca/menulis tabel `coins`. Mengikuti
// kontrak nama fungsi di NUMISMA_GUIDE Bagian 8 -- jangan ganti nama
// fungsi ini walau menambah isinya.
//
// Alur: screen -> coin_repo -> db_helper. Layar TIDAK PERNAH memanggil
// database langsung.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/crypto_util.dart';
import '../core/db_helper.dart';
import '../models/coin.dart';
import 'chain_service.dart';
import 'package:sqflite/sqflite.dart';

class CoinRepo {
  final _chain = ChainService();

  // Kolom yang boleh dipakai untuk urutan. Nilai `sort` dari layar
  // dipetakan lewat daftar ini (bukan disambung langsung ke SQL),
  // supaya tidak ada celah SQL injection dan nilai aneh jadi 'newest'.
  static const _orderByMap = {
    'newest': 'created_at DESC',
    'year': 'year DESC',
    'denomination': 'denomination DESC',
  };

  // Menyimpan koin baru. Foto (kalau ada) ditulis ke folder aplikasi
  // dan tabel hanya menyimpan path-nya (Bagian 5.1).
  //
  // Koin dan blok ADD Jejak Catatan (K13) ditulis dalam SATU transaksi:
  // keduanya tersimpan bersama atau gagal bersama, jadi tidak pernah ada koin
  // tanpa catatan. `photoSource` ('camera' / 'gallery' / 'none') dan hash
  // byte foto ikut dicatat di blok.
  Future<void> insert(
    Coin coin, {
    Uint8List? photoBytes,
    String photoSource = 'none',
  }) async {
    final db = await DbHelper.instance.database;

    var toSave = coin;
    if (photoBytes != null) {
      final path = await _savePhoto(coin.id, photoBytes);
      toSave = coin.copyWith(photoPath: path);
    }
    final notesEnc = await _encryptNotes(toSave.notes);

    try {
      await db.transaction((txn) async {
        await txn.insert('coins', toSave.toMap(notesEnc: notesEnc));
        await _chain.addBlock(
          userId: toSave.userId,
          coinId: toSave.id,
          action: 'ADD',
          coinSnapshot: await _snapshotOfRow(txn, toSave.id),
          photoBytes: photoBytes,
          photoSource: photoSource,
          executor: txn,
        );
      });
    } catch (_) {
      // Transaksi dibatalkan: file foto yang sudah ditulis jadi yatim.
      await _deleteFile(toSave.photoPath);
      rethrow;
    }
  }

  // Mengubah koin yang sudah ada. `updated_at` diperbarui dan
  // `is_synced` dikembalikan ke 0 supaya perubahan ikut terunggah
  // pada sinkronisasi berikutnya. Satu blok UPDATE ditambahkan ke Jejak
  // Catatan dalam transaksi yang sama.
  //
  // `photoBytes` opsional: diisi hanya kalau pengguna mengganti/menambah
  // foto saat mengubah koin. File foto lama dihapus supaya tidak yatim,
  // tetapi baru SETELAH transaksi berhasil. Bila foto tidak diganti, hash
  // foto lama tetap dicatat di blok baru (dibaca dari file) dan asal fotonya
  // diwarisi dari blok sebelumnya, supaya verifikasi foto tetap cocok.
  Future<void> update(
    Coin coin, {
    Uint8List? photoBytes,
    String photoSource = 'none',
  }) async {
    final db = await DbHelper.instance.database;

    var updated = coin.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: false,
    );
    if (photoBytes != null) {
      final newPath = await _savePhoto(coin.id, photoBytes);
      updated = updated.copyWith(photoPath: newPath);
    }
    final notesEnc = await _encryptNotes(updated.notes);
    final hashedPhoto = photoBytes ?? await _readFile(coin.photoPath);

    try {
      await db.transaction((txn) async {
        await txn.update(
          'coins',
          updated.toMap(notesEnc: notesEnc),
          where: 'id = ?',
          whereArgs: [coin.id],
        );
        final source = photoBytes != null
            ? photoSource
            : (await _chain.lastBlockForCoin(
                    txn,
                    coin.userId,
                    coin.id,
                  ))?.photoSource ??
                  'none';
        await _chain.addBlock(
          userId: coin.userId,
          coinId: coin.id,
          action: 'UPDATE',
          coinSnapshot: await _snapshotOfRow(txn, coin.id),
          photoBytes: hashedPhoto,
          photoSource: source,
          executor: txn,
        );
      });
    } catch (_) {
      if (photoBytes != null) await _deleteFile(updated.photoPath);
      rethrow;
    }

    if (photoBytes != null) await _deleteFile(coin.photoPath);
  }

  // Menghapus koin beserta file fotonya, supaya tidak ada file yatim
  // yang menumpuk di folder aplikasi.
  //
  // Data koin dibaca DULU, sebelum barisnya dihapus: blok DELETE di Jejak
  // Catatan menyimpan hash data terakhir koin itu. Tanpa blok DELETE, koin
  // yang hilang terlihat seperti kecurangan saat verifikasi, dan nanti
  // "hidup lagi" saat Pulihkan dari Supabase (Bagian 7.4).
  Future<void> delete(String coinId) async {
    final db = await DbHelper.instance.database;

    final rows = await db.query(
      'coins',
      where: 'id = ?',
      whereArgs: [coinId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final coin = Coin.fromMap(rows.first);

    await db.transaction((txn) async {
      await _chain.addBlock(
        userId: coin.userId,
        coinId: coin.id,
        action: 'DELETE',
        coinSnapshot: ChainService.snapshotOf(coin),
        executor: txn,
      );
      await txn.delete('coins', where: 'id = ?', whereArgs: [coinId]);
    });

    await _deleteFile(coin.photoPath);
  }

  // Daftar koin milik satu pengguna, dengan cari/filter/urut (K11).
  //
  // Catatan (`notes`) SENGAJA tidak didekripsi di sini: daftar tidak
  // menampilkannya, dan dekripsi per baris berarti membaca secure
  // storage berkali-kali (lambat kalau koleksi besar). Catatan baru
  // dibaca lewat getById() saat layar detail/edit dibuka.
  //
  // Pencarian hanya mencakup negara, nominal, dan tahun -- tidak
  // mencakup notes_enc karena isinya ciphertext (Bagian 5.1).
  Future<List<Coin>> list(
    int userId, {
    String? query,
    String? type,
    String? condition,
    int? yearFrom,
    int? yearTo,
    String sort = 'newest',
  }) async {
    final db = await DbHelper.instance.database;

    final where = <String>['user_id = ?'];
    final args = <Object>[userId];

    if (query != null && query.trim().isNotEmpty) {
      // CAST ke TEXT supaya nominal & tahun (angka) bisa dicari dengan LIKE.
      where.add(
        '(country LIKE ? OR CAST(denomination AS TEXT) LIKE ? '
        'OR CAST(year AS TEXT) LIKE ?)',
      );
      final like = '%${query.trim()}%';
      args.addAll([like, like, like]);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (condition != null) {
      where.add('condition = ?');
      args.add(condition);
    }
    if (yearFrom != null) {
      where.add('year >= ?');
      args.add(yearFrom);
    }
    if (yearTo != null) {
      where.add('year <= ?');
      args.add(yearTo);
    }

    final rows = await db.query(
      'coins',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: _orderByMap[sort] ?? _orderByMap['newest'],
    );

    return rows.map((row) => Coin.fromMap(row)).toList();
  }

  // Satu koin lengkap, termasuk catatan yang sudah didekripsi.
  Future<Coin?> getById(String id) async {
    final db = await DbHelper.instance.database;

    final rows = await db.query(
      'coins',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final notesEnc = row['notes_enc'] as String?;
    final notes = notesEnc == null
        ? null
        : await CryptoUtil.decryptText(notesEnc);
    return Coin.fromMap(row, notes: notes);
  }

  // ---------------------------------------------------------------
  // Helper internal
  // ---------------------------------------------------------------

  // Catatan kosong disimpan sebagai NULL (bukan ciphertext dari teks
  // kosong), supaya kolom jelas menandai "tidak ada catatan".
  Future<String?> _encryptNotes(String? notes) async {
    if (notes == null || notes.trim().isEmpty) return null;
    return CryptoUtil.encryptText(notes);
  }

  // Snapshot untuk hash diambil dari baris yang BENAR-BENAR tersimpan (bukan
  // dari objek di memori), supaya hash blok dan hash saat verifikasi dihitung
  // dari data yang sama persis, termasuk field yang dikosongkan jadi null.
  Future<Map<String, dynamic>> _snapshotOfRow(
    DatabaseExecutor ex,
    String coinId,
  ) async {
    final rows = await ex.query(
      'coins',
      where: 'id = ?',
      whereArgs: [coinId],
      limit: 1,
    );
    return ChainService.snapshotOf(Coin.fromMap(rows.first));
  }

  Future<Uint8List?> _readFile(String? path) async {
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  // Menulis foto ke <folder dokumen>/coin_photos/ dan mengembalikan
  // path-nya. Nama file memuat cap waktu supaya mengganti foto selalu
  // menghasilkan path BARU -- kalau namanya sama, Flutter bisa terus
  // menampilkan gambar lama dari cache.
  Future<String> _savePhoto(String coinId, Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'coin_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, '${coinId}_$stamp.jpg'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
