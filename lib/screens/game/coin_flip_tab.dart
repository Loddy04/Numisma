// screens/game/coin_flip_tab.dart
// Coin Flip (NUMISMA_GUIDE 7.8 dan 7.10b): goyang HP untuk melempar koin.
// Inilah pembawa sensor KEDUA (ACCELEROMETER) untuk syarat K8; sensor
// pertama (gyroscope) ada di tilt_photo.dart. Koinnya widget generik
// (coin_face.dart), bukan foto koleksi asli, jadi tidak perlu "sisi lain".
//
// Accelerometer melaporkan percepatan termasuk gravitasi (sekitar 9,8 m/s²
// saat HP diam). Goyangan dideteksi dari BESAR percepatan (akar x²+y²+z²)
// yang melewati ambang, dengan jeda supaya satu goyangan tidak memicu
// banyak lemparan. Tombol disediakan sebagai cadangan (HP tanpa sensor,
// atau saat demo di ruangan ramai).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../services/game_service.dart';
import '../../widgets/coin_face.dart';

class CoinFlipTab extends StatefulWidget {
  const CoinFlipTab({super.key});

  @override
  State<CoinFlipTab> createState() => _CoinFlipTabState();
}

class _CoinFlipTabState extends State<CoinFlipTab>
    with SingleTickerProviderStateMixin {
  // Ambang goyang (m/s²). Hasil coba awal; sesuaikan lewat uji di HP.
  static const _shakeThreshold = 15.0;
  // Jeda minimum antar lemparan.
  static const _cooldown = Duration(seconds: 1);

  final _game = GameService();
  late final AnimationController _controller;
  StreamSubscription<AccelerometerEvent>? _sub;

  bool _isHead = true; // sisi yang sedang menghadap atas
  double _startAngle = 0;
  double _endAngle = 0;
  int _heads = 0;
  int _tails = 0;
  bool _sensorOk = true;
  DateTime _lastFlip = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener(_onAnimationStatus);

    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen(
            _onAccel,
            // HP tanpa accelerometer (atau emulator): tombol tetap bisa dipakai.
            onError: (_) {
              if (mounted) setState(() => _sensorOk = false);
            },
            cancelOnError: true,
          );
    } catch (_) {
      _sensorOk = false;
    }
  }

  @override
  void dispose() {
    // Wajib dibatalkan, kalau tidak sensor terus membaca setelah layar ditutup.
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onAccel(AccelerometerEvent e) {
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude < _shakeThreshold) return;
    _flip();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Hasil dihitung setelah koin berhenti, bukan saat dilempar.
    setState(() {
      if (_isHead) {
        _heads++;
      } else {
        _tails++;
      }
    });
  }

  void _flip() {
    final now = DateTime.now();
    // Abaikan goyangan saat koin masih berputar atau masih dalam jeda.
    if (_controller.isAnimating || now.difference(_lastFlip) < _cooldown) {
      return;
    }
    _lastFlip = now;

    final newHead = _game.flipIsHead();
    // Sudut 0 = Head menghadap atas, pi = Tail. Selalu putar beberapa kali
    // penuh (5 putaran) lalu berhenti di sisi hasil lemparan.
    _startAngle = _isHead ? 0 : math.pi;
    final sideChange = newHead == _isHead ? 0 : math.pi;
    _endAngle = _startAngle + 5 * 2 * math.pi + sideChange;
    _isHead = newHead;
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Center(child: _buildCoin()),
        const SizedBox(height: 24),
        Text(
          _controller.isAnimating
              ? 'Berputar...'
              : (_heads + _tails == 0
                    ? 'Belum dilempar'
                    : (_isHead ? 'Head!' : 'Tail!')),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          _sensorOk
              ? 'Goyang HP untuk melempar koin, atau tekan tombol.'
              : 'Sensor tidak tersedia di perangkat ini. Pakai tombol.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: _flip,
            icon: const Icon(Icons.casino),
            label: const Text('Lempar koin'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Head: $_heads   ·   Tail: $_tails',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Koin diputar pada sumbu horizontal seperti koin yang dilempar. Saat
  // sudut melewati 90 derajat, sisi yang terlihat berganti; sisi belakang
  // diputar setengah putaran lagi supaya tulisannya tidak terbalik.
  Widget _buildCoin() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final angle = _controller.isAnimating || _controller.value > 0
            ? _startAngle + (_endAngle - _startAngle) * t
            : (_isHead ? 0.0 : math.pi);
        final a = angle % (2 * math.pi);
        final showHead = a < math.pi / 2 || a > 3 * math.pi / 2;
        // Koin "terangkat" di tengah lemparan (membesar lalu mengecil).
        final lift = 1 + 0.35 * math.sin(math.pi * _controller.value);

        final face = showHead
            ? const CoinFace(title: 'Head', subtitle: 'Numisma', size: 180)
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationX(math.pi),
                child: const CoinFace(
                  title: 'Tail',
                  subtitle: 'Numisma',
                  size: 180,
                ),
              );

        return Transform.scale(
          scale: lift,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(angle),
            child: face,
          ),
        );
      },
    );
  }
}
