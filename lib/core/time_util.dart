// core/time_util.dart
// Konversi waktu antar zona (NUMISMA_GUIDE Bagian 7.7b). Semua waktu di
// aplikasi disimpan UTC; di sini UTC diubah ke zona yang diminta memakai
// paket `timezone`, yang membawa data DST sehingga London otomatis
// berpindah BST (UTC+1) <-> GMT (UTC+0), tidak dihitung manual.

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'format_util.dart';

// Empat zona yang diminta dosen.
const zoneWib = 'Asia/Jakarta';
const zoneWita = 'Asia/Makassar';
const zoneWit = 'Asia/Jayapura';
const zoneLondon = 'Europe/London';
// Tambahan untuk pemilih zona di Jam Dunia: waktu acuan tanpa DST.
// Namanya 'Etc/UTC': nama 'UTC' saja tidak ada di data paket timezone.
const zoneUtc = 'Etc/UTC';

// Dipanggil sekali di main() sebelum runApp. Sengaja TIDAK mengatur zona
// perangkat (setLocalLocation): kita hanya memakai zona bernama secara
// eksplisit, sehingga tidak perlu mendeteksi zona HP.
void initTimeZones() => tzdata.initializeTimeZones();

// Kontrak Bagian 8. Mengembalikan waktu yang sama di zona tujuan.
DateTime toZone(DateTime utc, String zoneName) {
  return tz.TZDateTime.from(utc, tz.getLocation(zoneName));
}

// Kebalikan toZone: jam dinding di zona tertentu (mis. 20:00 WIB) menjadi
// waktu UTC. Dipakai form acara, yang jam inputnya selalu dibaca WIB.
DateTime utcFromZone(
  String zoneName,
  int year,
  int month,
  int day,
  int hour,
  int minute,
) {
  return tz.TZDateTime(
    tz.getLocation(zoneName),
    year,
    month,
    day,
    hour,
    minute,
  ).toUtc();
}

// Singkatan zona saat itu: WIB, WITA, WIT, dan BST atau GMT untuk London.
String zoneAbbreviation(DateTime utc, String zoneName) {
  return (toZone(utc, zoneName) as tz.TZDateTime).timeZoneName;
}

String _two(int n) => n.toString().padLeft(2, '0');

// "25 Okt 2026 02:00 WIB" (kontrak Bagian 8).
String formatZone(DateTime utc, String zoneName) {
  final t = toZone(utc, zoneName);
  return '${t.day} ${monthNamesId[t.month - 1]} ${t.year} '
      '${_two(t.hour)}:${_two(t.minute)} ${zoneAbbreviation(utc, zoneName)}';
}

// "02:00", jam dan menit saja (kartu acara).
String formatZoneTime(DateTime utc, String zoneName) {
  final t = toZone(utc, zoneName);
  return '${_two(t.hour)}:${_two(t.minute)}';
}

// "14:05:09", untuk kartu jam yang berdetak tiap detik.
String formatClock(DateTime utc, String zoneName) {
  final t = toZone(utc, zoneName);
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

// "25 Okt 2026", tanggal di zona itu (bisa beda hari dengan zona lain).
String formatZoneDate(DateTime utc, String zoneName) {
  final t = toZone(utc, zoneName);
  return '${t.day} ${monthNamesId[t.month - 1]} ${t.year}';
}
