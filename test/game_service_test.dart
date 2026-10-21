// test/game_service_test.dart
// Menguji pembuatan soal Tebak Asal Koin: jumlah soal, pilihan unik, dan
// jawaban benar selalu ada di antara pilihan.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/services/game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildQuiz membuat 10 soal dengan 4 pilihan unik berisi jawaban',
    () async {
      final quiz = await GameService().buildQuiz(random: Random(1));

      expect(quiz.length, GameService.questionCount);
      for (final q in quiz) {
        expect(q.options.length, GameService.optionCount);
        expect(q.options.toSet().length, GameService.optionCount);
        expect(q.options, contains(q.answer));
      }
      // Tidak ada koin yang sama muncul dua kali dalam satu permainan.
      expect(quiz.map((q) => q.answer).toSet().length, quiz.length);
    },
  );
}
