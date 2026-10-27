// widgets/hero_card.dart
// Kartu "hero": gradasi cokelat bersudut bulat dengan bayangan pekat dan
// lingkaran tipis bergaya koin di pojok kanan atas. Dipakai untuk hasil
// penting (jam, total nilai, kepala detail acara, hasil kuis). Warna dan
// bayangan dari theme.dart.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'coin_rings.dart';

class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 28,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppShadows.strong,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.brown),
          child: Stack(
            children: [
              const Positioned(top: -90, right: -70, child: CoinRings()),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(padding: padding, child: child),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
