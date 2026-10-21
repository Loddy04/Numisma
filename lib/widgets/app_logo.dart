// widgets/app_logo.dart
// Logo Numisma (koin emas dengan huruf N perunggu) dari aset gambar, supaya
// semua layar memakai logo yang sama dan penggantiannya cukup di satu
// tempat. File: assets/logo/logo_numisma_1024.png.

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo_numisma_1024.png',
      width: size,
      height: size,
      // Gambar besar ditampilkan kecil: filter berkualitas tinggi supaya
      // tepinya halus.
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Logo Numisma',
    );
  }
}
