// test/geo_util_test.dart
// Menguji bagian murni LBS: jarak, format jarak, dan urutan terdekat.
// GPS dan peta diuji di HP (T19).

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/core/geo_util.dart';
import 'package:numisma/models/event.dart';

Event _event(int id, {double? lat, double? lng}) => Event(
  id: id,
  userId: 1,
  title: 'Acara $id',
  startUtc: DateTime.utc(2026, 10, 25, 3),
  lat: lat,
  lng: lng,
);

void main() {
  // Titik acuan: Tugu Yogyakarta.
  const tuguLat = -7.7829;
  const tuguLng = 110.3671;

  group('distanceMeters', () {
    test('titik yang sama berjarak 0', () {
      expect(distanceMeters(tuguLat, tuguLng, tuguLat, tuguLng), 0);
    });

    test('Tugu ke Alun-Alun Kidul sekitar 3,3 km (toleransi lebar)', () {
      final d = distanceMeters(tuguLat, tuguLng, -7.8127, 110.3642);
      expect(d, inInclusiveRange(3000, 3600));
    });

    test('simetris', () {
      final a = distanceMeters(tuguLat, tuguLng, -7.8, 110.4);
      final b = distanceMeters(-7.8, 110.4, tuguLat, tuguLng);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('formatDistance', () {
    test('di bawah 10 m', () => expect(formatDistance(4), '< 10 m'));
    test('meter dibulatkan ke 10', () {
      expect(formatDistance(847), '850 m');
      expect(formatDistance(10), '10 m');
    });
    test('kilometer satu desimal dengan koma', () {
      expect(formatDistance(1000), '1,0 km');
      expect(formatDistance(2449), '2,4 km');
    });
    test('puluhan km tanpa desimal', () {
      expect(formatDistance(120400), '120 km');
    });
  });

  group('sortByDistance', () {
    test('terdekat di atas, acara tanpa titik tidak ikut', () {
      final events = [
        _event(1, lat: -7.9, lng: 110.4), // jauh
        _event(2), // tanpa titik
        _event(3, lat: -7.783, lng: 110.368), // dekat
        _event(4, lat: -7.8, lng: 110.37), // sedang
      ];
      final sorted = sortByDistance(events, tuguLat, tuguLng);
      expect(sorted.map((e) => e.event.id), [3, 4, 1]);
      expect(sorted.first.meters, lessThan(sorted.last.meters));
    });

    test('daftar kosong tetap kosong', () {
      expect(sortByDistance([], tuguLat, tuguLng), isEmpty);
    });
  });
}
