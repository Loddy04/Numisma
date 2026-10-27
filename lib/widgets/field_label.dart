// widgets/field_label.dart
// Label kecil huruf kapital di atas kolom isian ("EMAIL", "NEGARA") dan
// dekorasi kolom isian umum yang dipasangkan dengannya. Dipakai di Login,
// Daftar, Saran, dan form koin supaya semua formulir terlihat sama. Warna
// diambil dari theme.dart.

import 'package:flutter/material.dart';

import '../theme.dart';

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

// Dekorasi kolom isian: label sudah ada di atas (FieldLabel), jadi di dalam
// kolom hanya petunjuk isi dan ikon. Warna isi dan garis mengikuti tema;
// hanya sudutnya diatur lewat [radius] (30 = pil untuk satu baris, 20 untuk
// kolom bertingkat seperti Catatan).
InputDecoration appInput({
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? helper,
  String? counterText,
  double radius = 20,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    counterText: counterText,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    border: border(AppColors.cardBorder),
    enabledBorder: border(AppColors.cardBorder),
    focusedBorder: border(AppColors.bronze, 1.5),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.5),
  );
}
