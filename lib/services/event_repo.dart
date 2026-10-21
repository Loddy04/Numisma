// services/event_repo.dart
// Membaca tabel `events`: acara kolektor buatan pengguna, satu set per
// akun (NUMISMA_GUIDE 0.5, Bagian 7.7b). Tidak ada seed acara; daftar
// awalnya kosong sampai pengguna menambahkan sendiri.
//
// Seperti service lain, layar tidak menyentuh database langsung:
// screen -> event_repo -> db_helper.

import '../core/db_helper.dart';
import '../models/event.dart';

class EventRepo {
  // Acara milik satu pengguna, yang terdekat waktunya di atas.
  Future<List<Event>> list(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_utc ASC',
    );
    return rows.map(Event.fromMap).toList();
  }
}
