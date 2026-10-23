// widgets/double_rule.dart
// Garis ganda tipis ala buku lama: dua garis 1 px dengan celah 3 px. Dipakai
// di bawah header Beranda dan di tepi atas bottom nav.

import 'package:flutter/material.dart';

import '../theme.dart';

class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key});

  @override
  Widget build(BuildContext context) {
    const line = SizedBox(
      height: 1,
      child: ColoredBox(color: AppColors.ink),
    );
    // stretch: tanpa ini, Column memusatkan anak-anaknya dan ColoredBox kosong
    // mengecil ke lebar 0, sehingga garis tidak tampil sama sekali.
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [line, SizedBox(height: 3), line],
    );
  }
}
