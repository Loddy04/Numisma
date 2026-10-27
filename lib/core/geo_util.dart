// core/geo_util.dart
// Fungsi murni untuk LBS Jelajah (NUMISMA_GUIDE 7.5): jarak, format jarak,
// dan urutan terdekat. Tanpa database dan tanpa GPS, jadi mudah diuji.

import 'package:geolocator/geolocator.dart';

import '../models/event.dart';

// Jarak garis lurus dua titik dalam meter. Rumus Haversine milik geolocator
// (murni Dart), dipakai supaya tidak menulis ulang rumus yang sama.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}

// "850 m" di bawah 1 km (dibulatkan ke 10 m), "2,4 km" di atasnya (satu
// desimal, koma sebagai pemisah seperti di Indonesia), "120 km" bila sudah
// puluhan km (tanpa desimal).
String formatDistance(double meters) {
  if (meters < 10) return '< 10 m';
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  if (km >= 100) return '${km.round()} km';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

// Acara beserta jaraknya dari satu titik.
class EventDistance {
  final Event event;
  final double meters;
  const EventDistance(this.event, this.meters);
}

// Acara yang punya titik, diurutkan dari yang terdekat ke titik [lat], [lng].
// Acara tanpa titik tidak ikut (hanya tampil di tab Acara).
List<EventDistance> sortByDistance(
  List<Event> events,
  double lat,
  double lng,
) {
  final result = [
    for (final e in events)
      if (e.hasPoint)
        EventDistance(e, distanceMeters(lat, lng, e.lat!, e.lng!)),
  ];
  result.sort((a, b) => a.meters.compareTo(b.meters));
  return result;
}

// Alamat Google Maps (Maps URLs) untuk petunjuk arah ke titik acara. Bila
// posisi asal diketahui, ikut dikirim sebagai `origin` supaya rute dimulai
// dari posisi yang dipakai aplikasi (GPS atau lokasi manual), bukan dari
// posisi yang diperkirakan Google Maps sendiri. Tanpa asal, Google Maps yang
// menentukan titik awalnya.
Uri routeUri({
  required double destLat,
  required double destLng,
  double? originLat,
  double? originLng,
}) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (originLat != null && originLng != null) 'origin': '$originLat,$originLng',
    'destination': '$destLat,$destLng',
  });
}
