// services/location_service.dart
// Posisi GPS pengguna untuk LBS Jelajah (NUMISMA_GUIDE 7.5): memeriksa layanan
// lokasi dan izin, lalu mengambil posisi. Semua kegagalan menjadi
// LocationException berpesan ramah (langsung ditampilkan UI), dan layar tetap
// bisa dipakai dengan lokasi manual (tekan lama pada peta).
//
// GPS di dalam ruangan bisa sangat lambat atau tidak ada, jadi pengambilan
// posisi punya batas waktu, lalu mencoba posisi terakhir yang diketahui HP.

import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

// Titik sederhana (lintang, bujur) agar layar tidak perlu mengimpor
// geolocator hanya untuk membawa posisi.
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

class LocationService {
  static const errServiceOff =
      'Layanan lokasi (GPS) di HP mati. Nyalakan dulu, atau tekan lama pada '
      'peta untuk menentukan lokasi manual.';
  static const errDenied =
      'Izin lokasi ditolak. Izinkan agar jarak ke acara bisa dihitung, atau '
      'tekan lama pada peta untuk menentukan lokasi manual.';
  static const errDeniedForever =
      'Izin lokasi diblokir. Aktifkan lewat Pengaturan aplikasi, atau tekan '
      'lama pada peta untuk menentukan lokasi manual.';
  static const errNoFix =
      'Posisi belum ditemukan (GPS lemah di dalam ruangan?). Coba lagi di '
      'tempat terbuka, atau tekan lama pada peta untuk lokasi manual.';

  static const _timeout = Duration(seconds: 10);

  // Izin diminta di sini, saat Jelajah dibuka, bukan saat aplikasi mulai.
  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(errServiceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(errDeniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationException(errDenied);
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );
      return GeoPoint(p.latitude, p.longitude);
    } on TimeoutException {
      return _lastKnownOrFail();
    } catch (_) {
      return _lastKnownOrFail();
    }
  }

  // Cadangan: posisi terakhir yang disimpan HP (bisa agak lama, tetapi lebih
  // baik daripada tidak ada).
  Future<GeoPoint> _lastKnownOrFail() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint(last.latitude, last.longitude);
    } catch (_) {}
    throw const LocationException(errNoFix);
  }

  // Dipanggil dari tombol "Buka pengaturan" bila izin diblokir.
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
