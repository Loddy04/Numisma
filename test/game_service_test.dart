// test/game_service_test.dart
// Menguji pembuatan soal Tebak Asal Koin: jumlah soal, dua pilihan unik,
// jawaban benar selalu ada di antara pilihan, dan pengecoh dari wilayah yang
// sama bila tersedia.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/services/game_service.dart';

SeedCoin coin(String country, String code) => SeedCoin(
  type: 'coin',
  country: country,
  currencyCode: code,
  denomination: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildQuiz membuat 10 soal dengan 2 pilihan unik berisi jawaban', () async {
    final quiz = await GameService().buildQuiz(random: Random(1));

    expect(quiz.length, GameService.questionCount);
    for (final q in quiz) {
      expect(q.options.length, GameService.optionCount);
      expect(q.options.toSet().length, GameService.optionCount);
      expect(q.options, contains(q.answer));
    }
    // Tidak ada koin yang sama muncul dua kali dalam satu permainan.
    expect(quiz.map((q) => q.answer).toSet().length, quiz.length);
  });

  test('regionOf mengelompokkan negara tetangga dan melewatkan yang lain', () {
    expect(GameService.regionOf('JPY'), GameService.regionOf('KRW'));
    expect(GameService.regionOf('JPY'), isNot(GameService.regionOf('BRL')));
    expect(GameService.regionOf('ZAR'), isNull);
  });

  test('pickDistractor memilih dari wilayah yang sama bila ada', () {
    final seed = [
      coin('Jepang', 'JPY'),
      coin('Korea Selatan', 'KRW'),
      coin('Brasil', 'BRL'),
      coin('Mesir', 'EGP'),
    ];
    for (var i = 0; i < 20; i++) {
      final d = GameService.pickDistractor(seed[0], seed, Random(i));
      expect(d.country, 'Korea Selatan');
    }
  });

  test('pickDistractor tanpa wilayah memilih negara lain, bukan jawabannya', () {
    final seed = [coin('Afrika Selatan', 'ZAR'), coin('Brasil', 'BRL')];
    final d = GameService.pickDistractor(seed[0], seed, Random(3));
    expect(d.country, 'Brasil');
  });
}
