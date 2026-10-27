// test/number_input_test.dart
// Menguji aturan nominal uang: batas 15 angka, titik ribuan otomatis,
// penolakan teks berpangkat, dan pemformatan tanpa notasi eksponen.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/core/format_util.dart';
import 'package:numisma/core/number_input.dart';

// Mensimulasikan satu ketikan: dari isian lama menjadi teks baru.
String typed(String oldText, String newText) {
  final result = NominalInputFormatter().formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    ),
  );
  return result.text;
}

void main() {
  group('parseNominal', () {
    test('angka biasa, titik ribuan, dan koma desimal terbaca', () {
      expect(parseNominal('100').value, 100);
      expect(parseNominal('1.000.000').value, 1000000);
      expect(parseNominal('0,5').value, 0.5);
      expect(parseNominal('1.250,75').value, 1250.75);
    });

    test('15 angka diterima, 16 angka ditolak', () {
      expect(parseNominal('999.999.999.999.999').value, 999999999999999);
      expect(parseNominal('1.000.000.000.000.000').error, contains('terlalu'));
    });

    test('bagian bulat dan desimal dihitung bersama dalam batas 15 angka', () {
      expect(parseNominal('999.999.999.999,999').value, isNotNull); // 12 + 3
      expect(parseNominal('1.000.000.000.000,123').error, isNotNull); // 13 + 3
    });

    test('lebih dari 4 angka desimal ditolak', () {
      expect(parseNominal('1,2345').value, 1.2345);
      expect(parseNominal('1,23456').error, contains('di belakang koma'));
    });

    test('kosong, nol, huruf, dan teks berpangkat ditolak', () {
      expect(parseNominal('').error, isNotNull);
      expect(parseNominal('0').error, contains('lebih dari 0'));
      expect(parseNominal('0,0000').error, contains('lebih dari 0'));
      expect(parseNominal('abc').error, contains('angka'));
      expect(parseNominal('1e5').error, contains('angka'));
      expect(parseNominal('1e30').error, contains('angka'));
    });
  });

  group('NominalInputFormatter', () {
    test('titik ribuan disisipkan otomatis', () {
      expect(typed('', '1'), '1');
      expect(typed('100', '1000'), '1.000');
      expect(typed('1.000.00', '1.000.000'), '1.000.000');
    });

    test('koma desimal diterima sekali saja', () {
      expect(typed('1.000', '1.000,'), '1.000,');
      expect(typed('1.000,5', '1.000,5,'), '1.000,5');
    });

    test('titik di ujung ketikan dibaca sebagai koma desimal', () {
      expect(typed('1.000', '1.000.'), '1.000,');
    });

    test('huruf dan tanda lain ditolak', () {
      expect(typed('100', '100e'), '100');
      expect(typed('100', '100-'), '100');
    });

    test('nol di depan dibuang', () {
      expect(typed('', '0005'), '5');
      expect(typed('', ','), '0,');
    });

    test('melewati batas panjang ditolak, isian tetap', () {
      expect(typed('999.999.999.999.999', '9999999999999999'), '999.999.999.999.999');
      expect(typed('1,2345', '1,23456'), '1,2345');
    });
  });

  group('formatNumber', () {
    test('tanpa notasi eksponen, pemisah ribuan Indonesia', () {
      expect(formatNumber(20000), '20.000');
      expect(formatNumber(0.5), '0,5');
      expect(formatNumber(999999999999999), '999.999.999.999.999');
    });

    test('nilai di luar batas tampil sebagai teks aman', () {
      expect(formatNumber(1e30), 'sangat besar');
      expect(formatNumber(double.infinity), 'sangat besar');
      expect(formatNumber(double.nan), 'sangat besar');
    });
  });
}
