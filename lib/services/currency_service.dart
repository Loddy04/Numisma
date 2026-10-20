// services/currency_service.dart
// Daftar mata uang untuk pemilih di form koin. Datanya ada di
// assets/seed/currencies_seed.json (data referensi tetap), bukan di
// SQLite dan bukan di kode: menambah mata uang cukup mengedit JSON.
// Dimuat dari asset, jadi tetap jalan offline.
//
// Yang disimpan ke database hanya `code` (3 huruf, ISO 4217); nama dan
// negara hanya bantuan tampilan dan pencarian.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class CurrencyOption {
  final String code;
  final String name;
  final String country;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.country,
  });

  factory CurrencyOption.fromJson(Map<String, dynamic> json) {
    return CurrencyOption(
      code: json['code'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
    );
  }

  // Teks yang dilihat pengguna, mis. "Rupiah (IDR)".
  String get label => '$name ($code)';
}

class CurrencyService {
  CurrencyService._();

  // Disimpan sebagai Future supaya file hanya dibaca sekali, walau
  // pemilih dibuka berkali-kali (atau dua pemilih memuat bersamaan).
  static Future<List<CurrencyOption>>? _cache;

  static Future<List<CurrencyOption>> load() {
    return _cache ??= _read();
  }

  static Future<List<CurrencyOption>> _read() async {
    final text = await rootBundle.loadString('assets/seed/currencies_seed.json');
    final list = jsonDecode(text) as List<dynamic>;
    return list
        .map((e) => CurrencyOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Mencari di kode, nama, DAN negara sekaligus (tanpa peduli huruf
  // besar/kecil). Query kosong mengembalikan seluruh daftar.
  static List<CurrencyOption> search(List<CurrencyOption> all, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.code.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q))
        .toList();
  }
}
