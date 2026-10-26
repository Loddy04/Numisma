// widgets/gradient_button.dart
// Tombol utama bergradasi cokelat dengan bayangan lembut (Login, Daftar,
// dialog konfirmasi). ElevatedButton bawaan tidak bisa bergradasi, jadi
// dibuat dari Container + InkWell. Gradasi dan bayangan diambil dari
// theme.dart supaya perubahannya cukup di satu tempat.

import 'package:flutter/material.dart';

import '../theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // null = nonaktif (mis. saat memuat)
  final bool loading; // true = tampilkan lingkaran putar, bukan teks

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(18);
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Container(
        height: 52,
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
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
