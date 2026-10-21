// services/event_repo.dart
// Membaca tabel `events` (acara kolektor CONTOH, NUMISMA_GUIDE Bagian 7.7b).
//
// Seed dari assets/seed/events_seed.json dimasukkan saat tabel pertama kali
// dibaca dan masih kosong, bukan lewat onCreate di db_helper. Alasannya:
// onCreate hanya jalan di instalasi baru, sedangkan database yang sudah ada
// di HP tidak akan menjalankannya lagi. Cara ini juga tidak mengubah versi
// atau skema database.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../core/db_helper.dart';
import '../models/event.dart';

class EventRepo {
  // Acara terdekat di atas.
  Future<List<Event>> list() async {
    final db = await DbHelper.instance.database;
    await _seedIfEmpty(db);
    final rows = await db.query('events', orderBy: 'start_utc ASC');
    return rows.map(Event.fromMap).toList();
  }

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events'),
    );
    if (count != null && count > 0) return;

    final text = await rootBundle.loadString('assets/seed/events_seed.json');
    final items = jsonDecode(text) as List<dynamic>;
    // Satu batch = satu transaksi: seed masuk semua atau tidak sama sekali.
    final batch = db.batch();
    for (final item in items) {
      final e = item as Map<String, dynamic>;
      batch.insert('events', {
        'title': e['title'],
        'start_utc': e['start_utc'],
        'location': e['location'],
        'note': e['note'],
      });
    }
    await batch.commit(noResult: true);
  }
}
