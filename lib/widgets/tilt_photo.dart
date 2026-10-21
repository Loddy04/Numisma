// widgets/tilt_photo.dart
// Efek "tilt" untuk foto koin (K8, NUMISMA_GUIDE 7.8) memakai GYROSCOPE.
// Foto bergeser dan kartunya miring tipis mengikuti gerak HP, lalu perlahan
// kembali ke tengah saat HP diam. Ini bukan membuka sisi lain koin: yang
// dilihat tetap satu foto yang sama dari "sudut" berbeda, jadi aman walau
// tiap koin hanya punya satu foto.
//
// Gyroscope melaporkan KECEPATAN putar (rad/detik), bukan sudut. Karena
// itu kecepatan dijumlahkan dari waktu ke waktu (integrasi) menjadi sudut
// miring, lalu sudutnya "bocor" kembali ke nol supaya tidak melayang.
//
// Satu widget, dua gaya (diatur lewat parameter):
// - Di detail koin: halus, foto dipotong bingkai dan diperbesar sedikit
//   supaya tepinya tidak kosong saat bergeser.
// - Di layar penuh (coin_photo_viewer.dart): lebih dinamis, foto utuh tanpa
//   dipotong, geser dan miringnya lebih besar.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TiltPhoto extends StatefulWidget {
  final Widget child;
  // null = mengisi seluruh ruang yang tersedia (layar penuh).
  final double? height;
  final BorderRadius borderRadius;
  // Geser maksimum foto (piksel) di batas kemiringan.
  final double maxShift;
  // Pengali kemiringan kartu 3D terhadap sudut (0.3 = tipis, 0.55 = jelas).
  final double cardTilt;
  // Perbesaran foto. 1.0 = tidak diperbesar.
  final double scale;
  // true = foto dipotong mengikuti sudut bingkai (detail koin).
  final bool clip;

  const TiltPhoto({
    super.key,
    required this.child,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.maxShift = 14,
    this.cardTilt = 0.3,
    this.scale = 1.12,
    this.clip = true,
  });

  @override
  State<TiltPhoto> createState() => _TiltPhotoState();
}

class _TiltPhotoState extends State<TiltPhoto> {
  // Batas sudut (radian, sekitar 20 derajat).
  static const _maxAngle = 0.35;
  // Seberapa cepat sudut kembali ke tengah (per detik). Makin besar makin cepat.
  static const _returnRate = 1.5;
  // Kalau arah gesernya terasa terbalik di HP, ubah ini menjadi -1.
  static const _direction = 1.0;

  StreamSubscription<GyroscopeEvent>? _sub;
  double _angleX = 0; // miring kiri-kanan (putaran sumbu y)
  double _angleY = 0; // miring depan-belakang (putaran sumbu x)
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    try {
      _sub = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen(
            _onEvent,
            // HP tanpa gyroscope (atau emulator): foto diam, tidak crash.
            onError: (_) {},
            cancelOnError: true,
          );
    } catch (_) {
      // Sama: tanpa sensor, efeknya saja yang tidak ada.
    }
  }

  @override
  void dispose() {
    // Wajib dibatalkan, kalau tidak sensor terus membaca setelah layar ditutup.
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(GyroscopeEvent e) {
    final last = _last;
    _last = e.timestamp;
    if (last == null) return;
    // Selang waktu antar-pembacaan, dibatasi supaya lonjakan (mis. setelah
    // aplikasi dijeda) tidak membuat foto melompat.
    final dt = (e.timestamp.difference(last).inMicroseconds / 1e6).clamp(
      0.0,
      0.1,
    );
    if (dt == 0) return;

    final leak = math.exp(-_returnRate * dt);
    final x = ((_angleX + e.y * dt) * leak).clamp(-_maxAngle, _maxAngle);
    final y = ((_angleY + e.x * dt) * leak).clamp(-_maxAngle, _maxAngle);
    if (!mounted) return;
    setState(() {
      _angleX = x;
      _angleY = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dx = _direction * (_angleX / _maxAngle) * widget.maxShift;
    final dy = _direction * (_angleY / _maxAngle) * widget.maxShift;

    final cardTilt = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // sedikit perspektif
      ..rotateY(_direction * _angleX * widget.cardTilt)
      ..rotateX(-_direction * _angleY * widget.cardTilt);

    // Foto digeser, lalu (bila perlu) diperbesar supaya tepinya tidak
    // memperlihatkan area kosong saat bergeser.
    Widget photo = Transform.translate(
      offset: Offset(dx, dy),
      child: widget.scale == 1.0
          ? widget.child
          : Transform.scale(scale: widget.scale, child: widget.child),
    );
    if (widget.clip) {
      photo = ClipRRect(borderRadius: widget.borderRadius, child: photo);
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Transform(
        transform: cardTilt,
        alignment: Alignment.center,
        child: widget.clip ? SizedBox.expand(child: photo) : photo,
      ),
    );
  }
}
