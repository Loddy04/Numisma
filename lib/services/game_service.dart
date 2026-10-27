// services/game_service.dart
// Logika mini game (NUMISMA_GUIDE 7.10): soal Tebak Asal Koin dari
// assets/seed/coins_seed.json, skor di tabel game_scores, dan lempar koin.
// Layar (game_screen.dart dan tab-tabnya) tidak membaca asset atau database
// langsung, semuanya lewat service ini (aturan Bagian 4.1).

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../core/db_helper.dart';

// Satu koin contoh dari coins_seed.json (data contoh, bukan katalog).
class SeedCoin {
  final String type; // 'coin' atau 'banknote'
  final String country;
  final String currencyCode;
  final num denomination;
  final int? year;

  const SeedCoin({
    required this.type,
    required this.country,
    required this.currencyCode,
    required this.denomination,
    this.year,
  });

  factory SeedCoin.fromJson(Map<String, dynamic> json) => SeedCoin(
    type: json['type'] as String,
    country: json['country'] as String,
    currencyCode: json['currency_code'] as String,
    denomination: json['denomination'] as num,
    year: json['year'] as int?,
  );
}

// Satu soal: koin yang ditampilkan, dua pilihan negara, dan jawabannya.
class QuizQuestion {
  final SeedCoin coin;
  final List<String> options;
  const QuizQuestion(this.coin, this.options);

  String get answer => coin.country;
}

class BestScore {
  final int score;
  final int total;
  const BestScore(this.score, this.total);
}

class GameService {
  static const questionCount = 10;
  // Dua pilihan, supaya bisa dijawab dengan memiringkan HP ke kiri atau kanan.
  static const optionCount = 2;

  // Wilayah per kode mata uang. Dipakai memilih pengecoh yang masuk akal
  // (Jepang vs Korea Selatan, bukan Jepang vs Brasil). Kode yang tidak ada di
  // sini (mis. ZAR) jatuh ke pilihan acak.
  static const _regions = <String, String>{
    // Asia Tenggara
    'IDR': 'sea', 'MYR': 'sea', 'SGD': 'sea', 'THB': 'sea', 'VND': 'sea',
    'PHP': 'sea', 'BND': 'sea', 'KHR': 'sea', 'LAK': 'sea', 'MMK': 'sea',
    // Asia Timur
    'JPY': 'ea', 'KRW': 'ea', 'CNY': 'ea', 'HKD': 'ea', 'TWD': 'ea',
    // Asia Selatan
    'INR': 'sa', 'PKR': 'sa', 'LKR': 'sa', 'BDT': 'sa',
    // Timur Tengah
    'SAR': 'me', 'QAR': 'me', 'AED': 'me', 'KWD': 'me', 'ILS': 'me',
    'TRY': 'me', 'EGP': 'me',
    // Eropa
    'GBP': 'eu', 'CHF': 'eu', 'SEK': 'eu', 'NOK': 'eu', 'DKK': 'eu',
    'PLN': 'eu', 'CZK': 'eu', 'HUF': 'eu', 'RUB': 'eu',
    // Amerika
    'USD': 'am', 'CAD': 'am', 'BRL': 'am', 'MXN': 'am', 'ARS': 'am',
    // Oseania
    'AUD': 'oc', 'NZD': 'oc',
  };

  // Wilayah suatu mata uang, null bila tidak dikelompokkan.
  static String? regionOf(String currencyCode) => _regions[currencyCode];

  // Memilih satu koin pengecoh untuk [answer]: dari wilayah yang sama bila
  // ada negara lain di sana, jika tidak dari negara mana pun yang berbeda.
  static SeedCoin pickDistractor(
    SeedCoin answer,
    List<SeedCoin> seed,
    Random rnd,
  ) {
    final others = seed.where((c) => c.country != answer.country).toList();
    final region = regionOf(answer.currencyCode);
    final near = region == null
        ? <SeedCoin>[]
        : others.where((c) => regionOf(c.currencyCode) == region).toList();
    final pool = near.isNotEmpty ? near : others;
    return pool[rnd.nextInt(pool.length)];
  }

  static Future<List<SeedCoin>>? _seed;

  // Dibaca sekali dari asset (offline), lalu dipakai ulang.
  Future<List<SeedCoin>> _loadSeed() {
    return _seed ??= () async {
      final text = await rootBundle.loadString('assets/seed/coins_seed.json');
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .map((e) => SeedCoin.fromJson(e as Map<String, dynamic>))
          .toList();
    }();
  }

  // 10 soal acak tanpa koin ganda. Satu pilihan salah (pengecoh) diambil dari
  // wilayah yang sama bila bisa (lihat pickDistractor), dan dijamin berbeda
  // dari jawaban. Seed hanya memuat mata uang yang dipakai satu negara, jadi
  // jawabannya selalu tunggal (tidak ada soal "EUR" yang dipakai banyak
  // negara). Urutan kedua pilihan diacak: yang kiri dan yang kanan.
  Future<List<QuizQuestion>> buildQuiz({Random? random}) async {
    final rnd = random ?? Random();
    final seed = await _loadSeed();

    final picked = [...seed]..shuffle(rnd);
    return picked.take(questionCount).map((coin) {
      final wrong = pickDistractor(coin, seed, rnd);
      final options = [coin.country, wrong.country]..shuffle(rnd);
      return QuizQuestion(coin, options);
    }).toList();
  }

  Future<void> saveScore({
    required int userId,
    required int score,
    required int total,
  }) async {
    final db = await DbHelper.instance.database;
    await db.insert('game_scores', {
      'user_id': userId,
      'score': score,
      'total': total,
      'played_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // Skor tertinggi satu akun, null bila belum pernah bermain.
  Future<BestScore?> bestScore(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'game_scores',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'score DESC, played_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BestScore(rows.first['score'] as int, rows.first['total'] as int);
  }

  // Lempar koin: true = Head, false = Tail, peluang 50/50.
  // Random.secure() supaya hasilnya tidak bisa ditebak dari pola sebelumnya.
  bool flipIsHead() => Random.secure().nextBool();
}
