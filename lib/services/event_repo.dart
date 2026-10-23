// services/event_repo.dart
// Membaca dan menulis tabel `events`: acara kolektor buatan pengguna, satu
// set per akun (NUMISMA_GUIDE 0.5, Bagian 7.7b). Tidak ada seed acara;
// daftar awalnya kosong sampai pengguna menambahkan sendiri.
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

  Future<Event?> getById(int eventId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
    );
    return rows.isEmpty ? null : Event.fromMap(rows.first);
  }

  // Lokasi dan catatan kosong disimpan NULL, supaya kolom jelas menandai
  // "tidak diisi".
  Future<Event> add({
    required int userId,
    required String title,
    required DateTime startUtc,
    String? location,
    String? note,
    double? lat,
    double? lng,
  }) async {
    final db = await DbHelper.instance.database;
    final cleanTitle = title.trim();
    final cleanLocation = _nullIfBlank(location);
    final cleanNote = _nullIfBlank(note);
    // Titik hanya berarti bila lat DAN lng ada; satu saja dianggap tanpa titik.
    final hasPoint = lat != null && lng != null;
    final cleanLat = hasPoint ? lat : null;
    final cleanLng = hasPoint ? lng : null;

    final id = await db.insert('events', {
      'user_id': userId,
      'title': cleanTitle,
      'start_utc': startUtc.toUtc().toIso8601String(),
      'location': cleanLocation,
      'note': cleanNote,
      'lat': cleanLat,
      'lng': cleanLng,
    });
    return Event(
      id: id,
      userId: userId,
      title: cleanTitle,
      startUtc: startUtc.toUtc(),
      location: cleanLocation,
      note: cleanNote,
      lat: cleanLat,
      lng: cleanLng,
    );
  }

  // Mengubah acara. Bila WAKTU MULAI berubah, baris pengingatnya ikut
  // dihapus dalam transaksi yang sama (pengingat lama dihitung dari waktu
  // lama sehingga tidak berlaku lagi; pengguna memasang ulang). Alarm di
  // sistem Android dibatalkan oleh pemanggil lewat NotifService.
  Future<Event> update(Event event) async {
    final db = await DbHelper.instance.database;
    final hasPoint = event.lat != null && event.lng != null;
    final cleaned = Event(
      id: event.id,
      userId: event.userId,
      title: event.title.trim(),
      startUtc: event.startUtc.toUtc(),
      location: _nullIfBlank(event.location),
      note: _nullIfBlank(event.note),
      lat: hasPoint ? event.lat : null,
      lng: hasPoint ? event.lng : null,
    );

    await db.transaction((txn) async {
      final rows = await txn.query(
        'events',
        columns: ['start_utc'],
        where: 'id = ?',
        whereArgs: [cleaned.id],
      );
      if (rows.isEmpty) throw StateError('Acara tidak ditemukan');
      final oldStart = DateTime.parse(rows.first['start_utc'] as String);

      await txn.update(
        'events',
        {
          'title': cleaned.title,
          'start_utc': cleaned.startUtc.toIso8601String(),
          'location': cleaned.location,
          'note': cleaned.note,
          'lat': cleaned.lat,
          'lng': cleaned.lng,
        },
        where: 'id = ?',
        whereArgs: [cleaned.id],
      );
      if (!oldStart.isAtSameMomentAs(cleaned.startUtc)) {
        await txn.delete(
          'reminders',
          where: 'event_id = ?',
          whereArgs: [cleaned.id],
        );
      }
    });
    return cleaned;
  }

  // Baris pengingat acara ini ikut dihapus dalam satu transaksi, karena
  // reminders merujuk ke events (foreign key menolak menghapus acara yang
  // masih punya pengingat). Alarm di sistem Android dibatalkan oleh
  // pemanggil lewat NotifService.
  Future<void> delete(int eventId) async {
    final db = await DbHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'reminders',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      await txn.delete('events', where: 'id = ?', whereArgs: [eventId]);
    });
  }

  String? _nullIfBlank(String? text) {
    final t = text?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
