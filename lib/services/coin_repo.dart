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

class CoinRepo {
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
  // `photoSource` ('camera' / 'gallery' / 'none') belum dipakai di
  // sini: ia baru dibutuhkan saat blok Jejak Catatan dibuat (Hari 4).
  // Parameternya sudah disediakan sekarang supaya tanda tangan fungsi
  // tidak berubah nanti.
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

    await db.insert(
      'coins',
      toSave.toMap(notesEnc: await _encryptNotes(toSave.notes)),
    );
  }

  // Mengubah koin yang sudah ada. `updated_at` diperbarui dan
  // `is_synced` dikembalikan ke 0 supaya perubahan ikut terunggah
  // pada sinkronisasi berikutnya.
  Future<void> update(Coin coin) async {
    final db = await DbHelper.instance.database;

    final updated = coin.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      isSynced: false,
    );

    await db.update(
      'coins',
      updated.toMap(notesEnc: await _encryptNotes(updated.notes)),
      where: 'id = ?',
      whereArgs: [coin.id],
    );
  }

  // Menghapus koin beserta file fotonya, supaya tidak ada file yatim
  // yang menumpuk di folder aplikasi.
  Future<void> delete(String coinId) async {
    final db = await DbHelper.instance.database;

    final rows = await db.query(
      'coins',
      columns: ['photo_path'],
      where: 'id = ?',
      whereArgs: [coinId],
      limit: 1,
    );
    final photoPath = rows.isEmpty ? null : rows.first['photo_path'] as String?;

    await db.delete('coins', where: 'id = ?', whereArgs: [coinId]);

    if (photoPath != null) {
      final file = File(photoPath);
      if (await file.exists()) await file.delete();
    }
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
      where.add('(country LIKE ? OR CAST(denomination AS TEXT) LIKE ? '
          'OR CAST(year AS TEXT) LIKE ?)');
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
    final notes =
        notesEnc == null ? null : await CryptoUtil.decryptText(notesEnc);
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

  // Menulis foto ke <folder dokumen>/coin_photos/<id>.jpg dan
  // mengembalikan path-nya. Nama file = id koin, jadi satu koin
  // selalu punya paling banyak satu file foto.
  Future<String> _savePhoto(String coinId, Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'coin_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File(p.join(dir.path, '$coinId.jpg'));
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
