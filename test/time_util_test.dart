// Uji konversi zona waktu (T11, NUMISMA_GUIDE Bagian 7.7b): DST London
// berakhir Minggu 25 Okt 2026, jadi selisih ke WIB berubah dari 6 jam
// (BST) menjadi 7 jam (GMT).

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/core/time_util.dart';

void main() {
  setUpAll(initTimeZones);

  test('20:00 London 24 Okt 2026 (BST) = 02:00 WIB 25 Okt 2026', () {
    final utc = DateTime.utc(2026, 10, 24, 19);
    expect(formatZone(utc, zoneLondon), '24 Okt 2026 20:00 BST');
    expect(formatZone(utc, zoneWib), '25 Okt 2026 02:00 WIB');
  });

  test('20:00 London 26 Okt 2026 (GMT) = 03:00 WIB 27 Okt 2026', () {
    final utc = DateTime.utc(2026, 10, 26, 20);
    expect(formatZone(utc, zoneLondon), '26 Okt 2026 20:00 GMT');
    expect(formatZone(utc, zoneWib), '27 Okt 2026 03:00 WIB');
  });

  test('UTC tampil sebagai UTC tanpa selisih', () {
    final utc = DateTime.utc(2026, 10, 24, 19);
    expect(formatZone(utc, zoneUtc), '24 Okt 2026 19:00 UTC');
    expect(formatZoneTime(utc, zoneWib), '02:00');
  });

  test('WITA dan WIT selisih 1 dan 2 jam dari WIB', () {
    final utc = DateTime.utc(2026, 10, 24, 19);
    expect(formatZone(utc, zoneWita), '25 Okt 2026 03:00 WITA');
    expect(formatZone(utc, zoneWit), '25 Okt 2026 04:00 WIT');
  });
}
