// widgets/soft_card.dart
// Kartu putih bersudut bulat dengan garis krem tipis dan bayangan lembut,
// dipakai di Profil, Saran, Scan, dan form. Bayangan dipasang pada
// Container pembungkus (bukan pada Ink) supaya mengikuti sudut bulat dan
// tidak terpotong. Warna, bayangan, dan garis diambil dari theme.dart.

import 'package:flutter/material.dart';

import '../theme.dart';

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? color; // null = putih (AppColors.card)
  final VoidCallback? onTap; // null = kartu tidak bisa diketuk

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
