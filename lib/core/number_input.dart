// core/number_input.dart
// Penanganan isian nominal uang: aturan batas, pembacaan teks menjadi angka,
// dan pemformat yang bekerja saat pengguna mengetik. Dipisah dari layar supaya
// mudah diuji (test/number_input_test.dart) dan dipakai ulang.
//
// Aturan: nominal paling banyak 15 angka (gabungan bagian bulat dan desimal),
// dengan paling banyak 4 angka di belakang koma. 15 angka dipilih karena
// double hanya menyimpan sekitar 15 angka dengan tepat, dan cukup untuk uang
// kolektor yang sangat besar (mis. lembaran triliunan Zimbabwe). Format
// Indonesia: titik = pemisah ribuan, koma = desimal. Pengguna cukup mengetik
// angka dan koma; titik ribuan disisipkan otomatis.

import 'package:flutter/services.dart';

const maxNominalDigits = 15;
const maxNominalDecimals = 4;

// Hasil membaca teks nominal: salah satu dari [value] atau [error] terisi.
class NominalResult {
  final double? value;
  final String? error;
  const NominalResult.ok(double this.value) : error = null;
  const NominalResult.fail(String this.error) : value = null;
}

// Membaca teks isian ("1.250,5") menjadi angka, atau pesan galat ramah.
// Semua titik dianggap pemisah ribuan dan koma sebagai desimal. Teks
// berpangkat seperti "1e5" ditolak.
NominalResult parseNominal(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const NominalResult.fail('Nominal wajib diisi.');

  final cleaned = text.replaceAll('.', '').replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) {
    return const NominalResult.fail('Nominal harus berupa angka.');
  }
  final parts = cleaned.split('.');
  final intPart = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final decPart = parts.length > 1 ? parts[1] : '';

  if (decPart.length > maxNominalDecimals) {
    return const NominalResult.fail(
      'Maksimal $maxNominalDecimals angka di belakang koma.',
    );
  }
  if (intPart.length + decPart.length > maxNominalDigits) {
    return const NominalResult.fail(
      'Nominal terlalu besar (maksimal $maxNominalDigits angka).',
    );
  }
  final value = double.parse(cleaned);
  if (value <= 0) {
    return const NominalResult.fail('Nominal harus lebih dari 0.');
  }
  return NominalResult.ok(value);
}

// Memformat isian nominal saat diketik: hanya angka dan satu koma, titik
// ribuan disisipkan otomatis, dan batas panjang dijaga (melewati batas =
// ketikan ditolak). Titik yang diketik di akhir dibaca sebagai koma desimal,
// karena titik ribuan dibuat oleh pemformat ini sendiri.
class NominalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    final cursor = newValue.selection.isValid
        ? newValue.selection.baseOffset.clamp(0, raw.length)
        : raw.length;

    // Menyaring karakter sambil menghitung berapa karakter bersih yang ada
    // sebelum kursor.
    final clean = StringBuffer();
    var hasComma = false;
    var cleanBeforeCursor = 0;
    for (var i = 0; i < raw.length; i++) {
      if (i == cursor) cleanBeforeCursor = clean.length;
      final ch = raw[i];
      if (RegExp(r'[0-9]').hasMatch(ch)) {
        clean.write(ch);
      } else if (ch == ',' && !hasComma) {
        hasComma = true;
        clean.write(',');
      } else if (ch == '.' && i == raw.length - 1 && !hasComma) {
        // Titik di ujung ketikan = pengguna memulai desimal.
        hasComma = true;
        clean.write(',');
      }
    }
    if (cursor >= raw.length) cleanBeforeCursor = clean.length;
    if (clean.isEmpty) return oldValue; // hanya karakter yang tidak boleh

    final cleaned = clean.toString();
    final commaAt = cleaned.indexOf(',');
    var intDigits = commaAt < 0 ? cleaned : cleaned.substring(0, commaAt);
    final decDigits = commaAt < 0 ? '' : cleaned.substring(commaAt + 1);

    // Buang nol di depan ("007" -> "7"; "," -> "0,").
    final before = intDigits.length;
    intDigits = intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intDigits.isEmpty && commaAt >= 0) intDigits = '0';
    cleanBeforeCursor = (cleanBeforeCursor - (before - intDigits.length))
        .clamp(0, cleaned.length);

    // Melewati batas: ketikan ditolak, isian tetap seperti semula.
    if (decDigits.length > maxNominalDecimals ||
        intDigits.length + decDigits.length > maxNominalDigits) {
      return oldValue;
    }

    // Titik ribuan setiap tiga angka dari kanan.
    final grouped = StringBuffer();
    for (var i = 0; i < intDigits.length; i++) {
      if (i > 0 && (intDigits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(intDigits[i]);
    }
    final formatted = hasComma ? '$grouped,$decDigits' : grouped.toString();

    // Kursor dipindah ke posisi yang sama menurut jumlah angka/koma
    // sebelumnya, supaya mengetik di tengah tidak melompat ke ujung.
    var seen = 0;
    var offset = formatted.length;
    if (cleanBeforeCursor < cleaned.length) {
      offset = 0;
      for (var i = 0; i < formatted.length && seen < cleanBeforeCursor; i++) {
        offset = i + 1;
        if (formatted[i] != '.') seen++;
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
