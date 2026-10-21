// widgets/coin_face.dart
// Gambar koin/uang kertas generik untuk mini game (NUMISMA_GUIDE 7.8, 7.10).
// Sengaja digambar dari bentuk dan teks saja, TANPA gambar koin asli, supaya
// tidak ada masalah lisensi gambar dan tidak terikat ke koin koleksi
// pengguna tertentu. Dipakai di Tebak Asal Koin (nominal + kode mata uang)
// dan Coin Flip (teks Head/Tail).

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
    return Container(
      width: banknote ? size * 1.5 : size,
      height: banknote ? size * 0.8 : size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: banknote ? BorderRadius.circular(12) : null,
        // Gradasi emas ke perunggu memberi kesan logam tanpa gambar.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6C98C), AppColors.gold, AppColors.bronze],
        ),
        border: Border.all(color: AppColors.bronze, width: size * 0.04),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: size * 0.13,
                    color: AppColors.textDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
