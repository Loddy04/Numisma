// widgets/coin_rings.dart
// Lingkaran-lingkaran tipis sepusat bergaya koin, hiasan di pojok kepala
// bergradasi (Profil). Hanya gambar; warna garis putih transparan.

import 'package:flutter/material.dart';

class CoinRings extends StatelessWidget {
  final double size;
  const CoinRings({super.key, this.size = 300});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _RingsPainter()),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.14);
    final center = Offset(size.width / 2, size.height / 2);
    for (var r = 40.0; r < size.width / 2; r += 24) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
