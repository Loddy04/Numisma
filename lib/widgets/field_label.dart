// widgets/field_label.dart
// Label kecil huruf kapital di atas kolom isian ("EMAIL", "NEGARA") dan
// dekorasi kolom isian umum yang dipasangkan dengannya. Dipakai di Login,
// Daftar, Saran, dan form koin supaya semua formulir terlihat sama. Warna
// diambil dari theme.dart.

import 'package:flutter/material.dart';

import '../theme.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  // null = warna label tema (AppColors.fieldLabel).
  final Color? color;
  const FieldLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.fieldLabel,
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
  // Opsional: menimpa warna tema (dipakai layar Saran lewat warna_widget.dart).
  Color? fillColor,
  Color? borderColor,
  Color? focusColor,
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
    fillColor: fillColor,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    border: border(borderColor ?? AppColors.cardBorder),
    enabledBorder: border(borderColor ?? AppColors.cardBorder),
    focusedBorder: border(focusColor ?? AppColors.bronze, 1.5),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.5),
  );
}
