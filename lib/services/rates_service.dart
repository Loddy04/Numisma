// services/rates_service.dart
// Kurs mata uang dari Frankfurter v2 (NUMISMA_GUIDE Bagian 6.1), disimpan
// di tabel rates_cache supaya tetap ada saat internet bermasalah.
//
// Bentuk respons yang sudah dicek dengan curl (21 Okt 2026):
//   GET /v2/rate/JPY/IDR -> {"date":"2026-10-20","base":"JPY","quote":"IDR","rate":113.88}
//
// Strategi:
//   1. Cache segar (< 6 jam) dipakai langsung, tanpa jaringan.
//   2. Kalau tidak, panggil API lalu simpan ke cache.
//   3. Kalau API gagal, pakai cache lama (berapapun umurnya) dan tandai
//      `fromCache` supaya layar menampilkan tanggal kurs.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../core/db_helper.dart';

class RateInfo {
  final double rate;
  // Tanggal kurs dari API ("2026-10-20"), BUKAN waktu kita mengambilnya.
  final String? rateDate;
  // true = angka ini dari cache karena API tidak terjangkau.
  final bool fromCache;

  const RateInfo(this.rate, this.rateDate, {this.fromCache = false});
}

// Dilempar bila kurs tidak bisa didapat sama sekali (API gagal dan belum
// ada cache). Pesannya sudah ramah, langsung boleh ditampilkan.
class RateUnavailable implements Exception {
  final String message;
  const RateUnavailable(this.message);
  @override
  String toString() => message;
}

class RatesService {
  static const _baseUrl = 'https://api.frankfurter.dev/v2';
  static const _ttl = Duration(hours: 6);
  static const _timeout = Duration(seconds: 15);

  // Kurs satu pasangan beserta tanggalnya.
  Future<RateInfo> getRateInfo(String from, String to) async {
    if (from == to) return const RateInfo(1.0, null);

    final db = await DbHelper.instance.database;
    final cached = await _readCache(db, from, to);

    if (cached != null && cached.fresh) return cached.info;

    try {
      final info = await _fetchBest(from, to);
      await _writeCache(db, from, to, info);
      return info;
    } catch (_) {
      // Jaringan mati, timeout, atau API menolak: cache lama masih lebih
      // baik daripada tidak ada angka sama sekali.
      if (cached != null) {
        return RateInfo(cached.info.rate, cached.info.rateDate,
            fromCache: true);
      }
      throw const RateUnavailable(
        'Kurs belum bisa diambil. Periksa internet lalu coba lagi.',
      );
    }
  }

  // Sesuai kontrak Bagian 8.
  Future<double> getRate(String from, String to) async {
    return (await getRateInfo(from, to)).rate;
  }

  // null bila kurs tidak tersedia (tidak melempar, supaya pemanggil
  // cukup menampilkan "nilai tidak tersedia").
  Future<double?> convert(double amount, String from, String to) async {
    try {
      return amount * await getRate(from, to);
    } on RateUnavailable {
      return null;
    }
  }

  // Frankfurter membulatkan kurs ke beberapa angka penting saja, jadi
  // kurs kecil jadi kasar (IDR->JPY hanya 0.00878, sedangkan JPY->IDR
  // 113.88 jauh lebih teliti). Karena itu bila hasil langsung < 1, kita
  // minta arah sebaliknya lalu dibalik (1/kurs). Angka besar kehilangan
  // lebih sedikit ketelitian relatif.
  Future<RateInfo> _fetchBest(String from, String to) async {
    final direct = await _fetchPair(from, to);
    if (direct.rate >= 1) return direct;
    final reverse = await _fetchPair(to, from);
    return RateInfo(1 / reverse.rate, reverse.rateDate);
  }

  Future<RateInfo> _fetchPair(String from, String to) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/rate/$from/$to'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Frankfurter ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // `rate` bisa tampil sebagai int (mis. 18025), jadi lewat num.
    final rate = (json['rate'] as num).toDouble();
    if (rate <= 0) throw Exception('Kurs tidak valid');
    return RateInfo(rate, json['date'] as String?);
  }

  Future<_Cached?> _readCache(Database db, String from, String to) async {
    final rows = await db.query(
      'rates_cache',
      where: 'base = ? AND target = ?',
      whereArgs: [from, to],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final fetchedAt = DateTime.tryParse(row['fetched_at'] as String);
    final fresh = fetchedAt != null &&
        DateTime.now().toUtc().difference(fetchedAt) < _ttl;
    return _Cached(
      RateInfo((row['rate'] as num).toDouble(), row['rate_date'] as String?),
      fresh,
    );
  }

  Future<void> _writeCache(
      Database db, String from, String to, RateInfo info) async {
    await db.insert(
      'rates_cache',
      {
        'base': from,
        'target': to,
        'rate': info.rate,
        'rate_date': info.rateDate,
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class _Cached {
  final RateInfo info;
  final bool fresh;
  const _Cached(this.info, this.fresh);
}
