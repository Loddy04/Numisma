// widgets/gradient_button.dart
// Tombol utama bergradasi cokelat dengan bayangan lembut (Login, Daftar,
// Saran, dialog konfirmasi). ElevatedButton bawaan tidak bisa bergradasi, jadi
// dibuat dari Container + InkWell. Gradasi dan bayangan diambil dari
// theme.dart supaya perubahannya cukup di satu tempat.

import 'package:flutter/material.dart';

import '../theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // null = nonaktif (mis. saat memuat)
  final bool loading; // true = tampilkan lingkaran putar, bukan teks
  final IconData? icon; // ikon kecil di kiri teks (opsional)
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(18);
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: AppGradients.brown,
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: Colors.white),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
