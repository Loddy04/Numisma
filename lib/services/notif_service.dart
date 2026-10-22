// services/notif_service.dart
// Notifikasi lokal pengingat acara (NUMISMA_GUIDE 0.5, Bagian 7.12).
//
// Penjadwalan memakai zonedSchedule: jadwal diserahkan ke sistem Android
// (AlarmManager), jadi notifikasi tetap muncul walau aplikasi ditutup.
// Tanpa Firebase/FCM: semuanya lokal.
//
// Aturan penting:
// - Satu acara maksimal satu pengingat. Id notifikasi Android = events.id.
// - Pengingat disimpan di tabel `reminders` (event_id, remind_at UTC) supaya
//   bisa dijadwalkan ulang saat aplikasi dibuka: force-stop membatalkan semua
//   alarm, tetapi tabel ini tetap ada.
// - Alarm eksak butuh izin yang di Android 14+ diaktifkan pengguna sendiri.
//   Bila belum aktif, jadwal turun ke mode tidak eksak (bisa terlambat
//   beberapa menit), tidak gagal diam-diam.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/db_helper.dart';
import '../core/time_util.dart';
import '../models/event.dart';

// Kesalahan yang pesannya sudah ramah dan boleh langsung ditampilkan.
class NotifException implements Exception {
  final String message;
  const NotifException(this.message);
  @override
  String toString() => message;
}

class NotifService {
  // Satu instance plugin untuk seluruh aplikasi.
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Id notifikasi uji dibuat jauh di atas id acara (events.id kecil) supaya
  // tidak bentrok dengan pengingat acara.
  static const _testNowId = 2000000001;
  static const _testLaterId = 2000000002;

  static const _smallIcon = 'ic_stat_numisma';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'numisma_events',
      'Pengingat acara',
      channelDescription: 'Pengingat acara kolektor',
      importance: Importance.high,
      priority: Priority.high,
      // Ikon kecil di bilah status harus MONOKROM (Android membuang
      // warnanya): koin putih dengan huruf N dilubangi, dibuat dari logo.
      // Aksen perunggu mewarnai ikon kecil di panel notifikasi. Berkas ada di
      // android/app/src/main/res/. Tanpa ikon besar: logo cukup sekali.
      icon: _smallIcon,
      color: Color(0xFF8C6239),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // Dipanggil sekali di main() sebelum runApp. Izin TIDAK diminta di sini
  // (supaya pengguna tidak ditodong izin sebelum login); izin diminta saat
  // pertama kali dibutuhkan.
  Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
      ),
    );
    _initialized = true;
  }

  // Izin menampilkan notifikasi (Android 13+). Melempar NotifException bila
  // pengguna menolak.
  Future<void> _requireNotificationPermission() async {
    final android = _android;
    if (android == null) return;
    var granted = await android.areNotificationsEnabled() ?? true;
    if (!granted) {
      granted = await android.requestNotificationsPermission() ?? false;
    }
    if (!granted) {
      throw const NotifException(
        'Izin notifikasi belum diberikan. Aktifkan di Pengaturan HP '
        'agar pengingat bisa muncul.',
      );
    }
  }

  // Apakah alarm eksak boleh dipakai sekarang.
  Future<bool> canScheduleExact() async {
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  // Meminta izin alarm eksak bila belum aktif, lalu memeriksa ulang.
  // Meminta berarti membuka halaman pengaturan sistem; hasilnya bisa baru
  // berlaku setelah pengguna kembali, jadi jadwal kali ini bisa saja masih
  // tidak eksak. rescheduleAll() menaikkannya ke eksak saat aplikasi dibuka
  // lagi setelah izin diberikan.
  Future<bool> _ensureExactPermission() async {
    final android = _android;
    if (android == null) return true;
    if (await canScheduleExact()) return true;
    await android.requestExactAlarmsPermission();
    return canScheduleExact();
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime whenUtc,
    required bool exact,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // Waktu dalam UTC, jadi tidak perlu mendeteksi zona perangkat.
      scheduledDate: tz.TZDateTime.from(whenUtc, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // --- Notifikasi uji (demo) --------------------------------------------

  Future<void> showTestNow() async {
    await _requireNotificationPermission();
    await _plugin.show(
      id: _testNowId,
      title: 'Notifikasi uji Numisma',
      body: 'Notifikasi berfungsi.',
      notificationDetails: _details,
    );
  }

  // Memakai jalur penjadwalan yang sama dengan pengingat acara, jadi bisa
  // dipakai membuktikan "tetap muncul walau aplikasi ditutup". Mengembalikan
  // true bila dijadwalkan eksak.
  Future<bool> showTestIn(Duration d) async {
    await _requireNotificationPermission();
    final exact = await _ensureExactPermission();
    await _schedule(
      id: _testLaterId,
      title: 'Notifikasi uji Numisma',
      body: 'Notifikasi terjadwal muncul walau aplikasi ditutup.',
      whenUtc: DateTime.now().toUtc().add(d),
      exact: exact,
    );
    return exact;
  }

  // --- Pengingat acara --------------------------------------------------

  // Menjadwalkan pengingat `before` sebelum acara dimulai, dan menyimpannya
  // di `reminders` (mengganti pengingat lama acara ini bila ada).
  // Mengembalikan true bila dijadwalkan eksak.
  Future<bool> scheduleEventReminder(Event event, Duration before) async {
    final remindAt = event.startUtc.subtract(before);
    if (!remindAt.isAfter(DateTime.now().toUtc())) {
      throw const NotifException(
        'Waktu pengingat sudah lewat. Pilih selisih yang lebih kecil.',
      );
    }
    await _requireNotificationPermission();
    final exact = await _ensureExactPermission();

    await _schedule(
      id: event.id,
      title: event.title,
      body: 'Dimulai ${formatZone(event.startUtc, zoneWib)}',
      whenUtc: remindAt,
      exact: exact,
    );

    final db = await DbHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'reminders',
        where: 'event_id = ?',
        whereArgs: [event.id],
      );
      await txn.insert('reminders', {
        'event_id': event.id,
        'remind_at': remindAt.toIso8601String(),
      });
    });
    return exact;
  }

  // Membatalkan alarm dan menghapus baris pengingat acara ini.
  Future<void> cancelEventReminder(int eventId) async {
    await _plugin.cancel(id: eventId);
    final db = await DbHelper.instance.database;
    await db.delete('reminders', where: 'event_id = ?', whereArgs: [eventId]);
  }

  // Peta id acara -> waktu pengingat (UTC), untuk menampilkan info pengingat
  // di kartu dan layar detail.
  Future<Map<int, DateTime>> reminderMap() async {
    final db = await DbHelper.instance.database;
    final rows = await db.query('reminders');
    return {
      for (final r in rows)
        r['event_id'] as int: DateTime.parse(r['remind_at'] as String).toUtc(),
    };
  }

  // Alarm Android bersifat per PERANGKAT, sedangkan acara per AKUN. Saat
  // akun keluar, alarm miliknya dibatalkan supaya tidak berbunyi (dan
  // membocorkan nama acara) di layar akun lain. Baris `reminders` sengaja
  // dibiarkan, jadi pengingatnya dipulihkan oleh rescheduleAll() ketika
  // akun itu login lagi.
  Future<void> cancelAllForUser(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT r.event_id AS event_id
      FROM reminders r JOIN events e ON e.id = r.event_id
      WHERE e.user_id = ?
      ''',
      [userId],
    );
    for (final r in rows) {
      await _plugin.cancel(id: r['event_id'] as int);
    }
  }

  // Dipanggil setelah akun diketahui (HomeShell dibuka, baik setelah login
  // maupun session lama). Force-stop membatalkan semua alarm sistem, tetapi
  // tabel `reminders` tetap ada, jadi pengingat AKUN INI yang masih di masa
  // depan dijadwalkan ulang (id sama, tidak ganda). Yang sudah lewat
  // dibiarkan: tampil sebagai "Pengingat sudah lewat".
  //
  // Pengingat milik akun LAIN dibatalkan alarmnya di sini (barisnya tetap
  // ada). Ini menutup kasus session akun lain habis tanpa logout, atau
  // alarm yang dipulihkan sistem setelah HP restart.
  Future<void> rescheduleAll(int userId) async {
    try {
      final db = await DbHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT r.event_id AS event_id, r.remind_at AS remind_at,
               e.title AS title, e.start_utc AS start_utc,
               e.user_id AS user_id
        FROM reminders r JOIN events e ON e.id = r.event_id
      ''');
      final now = DateTime.now().toUtc();
      final exact = await canScheduleExact();
      for (final r in rows) {
        if (r['user_id'] != userId) {
          await _plugin.cancel(id: r['event_id'] as int);
          continue;
        }
        final remindAt = DateTime.parse(r['remind_at'] as String).toUtc();
        if (!remindAt.isAfter(now)) continue;
        final start = DateTime.parse(r['start_utc'] as String).toUtc();
        await _schedule(
          id: r['event_id'] as int,
          title: r['title'] as String,
          body: 'Dimulai ${formatZone(start, zoneWib)}',
          whenUtc: remindAt,
          exact: exact,
        );
      }
    } catch (e) {
      // Gagal menjadwalkan ulang tidak boleh menghentikan aplikasi.
      debugPrint('rescheduleAll gagal: $e');
    }
  }
}
