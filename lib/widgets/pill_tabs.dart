// widgets/pill_tabs.dart
// Tab berbentuk kapsul: wadah krem dengan pilihan terpilih bergradasi
// cokelat. Menggantikan TabBar bawaan di Permainan, Jelajah, dan Konversi.
// Terhubung ke TabController, jadi TabBarView di bawahnya ikut berganti.

import 'package:flutter/material.dart';

import '../theme.dart';

class PillTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const PillTabs({super.key, required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE6D8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      // Dibangun ulang saat tab berganti, termasuk saat digeser.
      child: AnimatedBuilder(
        animation: controller.animation!,
        builder: (context, _) {
          final selected = controller.animation!.value.round();
          return Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.animateTo(i),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: i == selected ? AppGradients.brown : null,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 15,
                          color: i == selected
                              ? Colors.white
                              : AppColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
