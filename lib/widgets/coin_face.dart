// widgets/coin_face.dart
// Gambar koin/uang kertas generik untuk mini game (NUMISMA_GUIDE 7.8, 7.10).
// Sengaja digambar dari bentuk dan teks saja, TANPA gambar koin asli, supaya
// tidak ada masalah lisensi gambar dan tidak terikat ke koin koleksi
// pengguna tertentu. Dipakai di Tebak Asal Koin (nominal + kode mata uang)
// dan Coin Flip (teks Head/Tail). Tampilan: bola emas bergradasi radial,
// cincin dalam, dan tulisan serif tebal sedikit miring.

import 'package:flutter/material.dart';

import '../theme.dart';

class CoinFace extends StatelessWidget {
  // Teks besar di tengah, mis. "100" atau "Head".
  final String title;
  // Teks kecil di bawahnya, mis. "JPY" atau "1990". Boleh kosong.
  final String? subtitle;
  final double size;
  // true = bentuk persegi panjang (uang kertas), false = lingkaran (koin).
  final bool banknote;

  const CoinFace({
    super.key,
    required this.title,
    this.subtitle,
    this.size = 160,
    this.banknote = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = banknote ? BoxShape.rectangle : BoxShape.circle;
    final radius = banknote ? BorderRadius.circular(size * 0.1) : null;
    final width = banknote ? size * 1.5 : size;
    final height = banknote ? size * 0.8 : size;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        // Gradasi radial dari krem emas ke perunggu memberi kesan logam.
        gradient: const RadialGradient(
          center: Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [Color(0xFFEBD8AE), AppColors.gold, Color(0xFF9A6B3A)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroDark.withValues(alpha: 0.3),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      alignment: Alignment.center,
      // Cincin dalam.
      child: Container(
        margin: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: banknote ? BorderRadius.circular(size * 0.06) : null,
          border: Border.all(
            color: AppColors.heroLight.withValues(alpha: 0.85),
            width: size * 0.02,
          ),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Transform.rotate(
              angle: -0.12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppText.serif(
                      size: size * 0.26,
                      weight: FontWeight.w900,
                      color: AppColors.heroDark,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: AppText.serif(
                        size: size * 0.11,
                        color: AppColors.heroDark.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
