// test/crypto_util_test.dart
// Menguji emailHash: kunci pencarian akun dan kunci sinkron, jadi harus
// stabil (email yang sama selalu menghasilkan hash yang sama) dan
// dinormalkan.

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/core/crypto_util.dart';

void main() {
  group('CryptoUtil.emailHash', () {
    test('berupa 64 karakter heksadesimal huruf kecil', () {
      final h = CryptoUtil.emailHash('budi@mail.com');
      expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('email yang sama selalu menghasilkan hash yang sama', () {
      expect(
        CryptoUtil.emailHash('budi@mail.com'),
        CryptoUtil.emailHash('budi@mail.com'),
      );
    });

    test('huruf besar dan spasi di ujung diabaikan', () {
      expect(
        CryptoUtil.emailHash('  Budi@Mail.COM '),
        CryptoUtil.emailHash('budi@mail.com'),
      );
    });

    test('email berbeda menghasilkan hash berbeda', () {
      expect(
        CryptoUtil.emailHash('budi@mail.com'),
        isNot(CryptoUtil.emailHash('budi2@mail.com')),
      );
    });

    test('memakai awalan "numisma:" (bukan SHA-256 email polos)', () {
      expect(
        CryptoUtil.emailHash('budi@mail.com'),
        CryptoUtil.sha256OfString('numisma:budi@mail.com'),
      );
      expect(
        CryptoUtil.emailHash('budi@mail.com'),
        isNot(CryptoUtil.sha256OfString('budi@mail.com')),
      );
    });
  });
}
