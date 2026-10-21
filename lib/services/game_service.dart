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

// Satu soal: koin yang ditampilkan, empat pilihan negara, dan jawabannya.
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
  static const optionCount = 4;

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

  // 10 soal acak tanpa koin ganda. Tiga pilihan salah diambil dari negara
  // lain di seed dan dijamin berbeda dari jawaban maupun satu sama lain.
  // Seed hanya memuat mata uang yang dipakai satu negara, jadi jawabannya
  // selalu tunggal (tidak ada soal "EUR" yang dipakai banyak negara).
  Future<List<QuizQuestion>> buildQuiz({Random? random}) async {
    final rnd = random ?? Random();
    final seed = await _loadSeed();
    final countries = seed.map((c) => c.country).toSet().toList();

    final picked = [...seed]..shuffle(rnd);
    return picked.take(questionCount).map((coin) {
      final wrong = countries.where((c) => c != coin.country).toList()
        ..shuffle(rnd);
      final options = [coin.country, ...wrong.take(optionCount - 1)]
        ..shuffle(rnd);
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
