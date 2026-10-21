// test/ai_service_test.dart
// Menguji parser tebakan AI (CoinGuess.fromJson): AI kadang mengirim angka
// sebagai teks, kode mata uang berhuruf kecil, atau nilai tak masuk akal.
// Yang tidak valid harus jadi null supaya form tidak terisi sampah.

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/services/ai_service.dart';

void main() {
  test('jawaban lengkap terbaca benar', () {
    final g = CoinGuess.fromJson({
      'type': 'coin',
      'country': 'Japan',
      'currency_code': 'JPY',
      'denomination': 100,
      'year': 1990,
      'features': 'Koin 100 yen.',
      'confidence': 'high',
    });
    expect(g.type, 'coin');
    expect(g.country, 'Japan');
    expect(g.currencyCode, 'JPY');
    expect(g.denomination, 100.0);
    expect(g.year, 1990);
    expect(g.confidence, 'high');
    expect(g.summary, contains('kepercayaan AI: high'));
  });

  test('angka berupa teks dan kode huruf kecil dinormalkan', () {
    final g = CoinGuess.fromJson({
      'type': 'banknote',
      'country': 'Indonesia',
      'currency_code': 'idr',
      'denomination': '5.000',
      'year': '1999',
      'features': 'x',
      'confidence': 'medium',
    });
    expect(g.type, 'banknote');
    expect(g.currencyCode, 'IDR');
    expect(g.year, 1999);
  });

  test('null dan nilai tak masuk akal menjadi null', () {
    final g = CoinGuess.fromJson({
      'type': 'aneh',
      'country': 'null',
      'currency_code': 'RUPIAH',
      'denomination': -5,
      'year': 99999,
      'features': null,
      'confidence': 'sangat yakin',
    });
    expect(g.type, 'coin'); // selain "banknote" dianggap koin
    expect(g.country, isNull);
    expect(g.currencyCode, isNull);
    expect(g.denomination, isNull);
    expect(g.year, isNull);
    expect(g.confidence, 'low');
    // ai_summary tidak boleh kosong: ia menandai "sudah dianalisis AI".
    expect(g.summary, isNotEmpty);
  });

  test('hasil contoh ditandai sebagai contoh', () {
    final g = CoinGuess.sample();
    expect(g.isSample, isTrue);
    expect(g.summary, contains('contoh'));
  });

  test('year_estimated hanya berlaku bila tahunnya ada', () {
    final dengan = CoinGuess.fromJson({
      'year': 1985,
      'year_estimated': true,
      'features': 'x',
    });
    expect(dengan.year, 1985);
    expect(dengan.yearEstimated, isTrue);
    expect(dengan.summary, contains('perkiraan AI'));

    final tanpa = CoinGuess.fromJson({
      'year': null,
      'year_estimated': true,
      'features': 'x',
    });
    expect(tanpa.year, isNull);
    expect(tanpa.yearEstimated, isFalse);

    final terbaca = CoinGuess.fromJson({
      'year': 1990,
      'year_estimated': false,
      'features': 'x',
    });
    expect(terbaca.yearEstimated, isFalse);
    expect(terbaca.summary, isNot(contains('perkiraan AI')));
  });
}
