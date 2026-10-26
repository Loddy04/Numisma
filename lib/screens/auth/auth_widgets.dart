// screens/auth/auth_widgets.dart
// Potongan tampilan yang dipakai bersama layar Login dan Daftar: kepala
// halaman bergradasi (logo, nama, tagline), label kecil di atas kolom isian,
// dan dekorasi kolom isian bersudut sangat bulat. Hanya tampilan; semua warna
// diambil dari theme.dart.

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_logo.dart';

// Kepala halaman Login: gradasi cokelat dengan lingkaran tipis bergaya koin
// di pojok kanan atas, logo, nama, dan tagline.
class AuthHero extends StatelessWidget {
  final double height;
  const AuthHero({super.key, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroDark, AppColors.heroLight],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -70,
            child: SizedBox(
              width: 300,
              height: 300,
              child: CustomPaint(painter: _RingsPainter()),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 72),
                    const SizedBox(height: 14),
                    Text(
                      'Numisma',
                      style: AppText.serif(
                        size: 38,
                        weight: FontWeight.w700,
                        color: AppColors.creamTop,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buku koleksi koin dan uang kertas',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.creamTop.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Label kecil huruf kapital di atas kolom isian ("EMAIL", "PASSWORD").
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.fieldLabel,
        ),
      ),
    );
  }
}

// Dekorasi kolom isian Login dan Daftar: label sudah ada di atas, jadi di
// dalam kolom hanya petunjuk isi (hint) dan ikon. Sudut dibuat sangat bulat
// (pil) sesuai desain; warna isi dan garis mengikuti tema.
InputDecoration authInput({
  required String hint,
  required IconData icon,
  Widget? suffix,
  String? counterText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    counterText: counterText,
    border: border(AppColors.cardBorder),
    enabledBorder: border(AppColors.cardBorder),
    focusedBorder: border(AppColors.bronze, 1.5),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.5),
  );
}

// Lingkaran-lingkaran tipis sepusat, hiasan bergaya koin.
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
