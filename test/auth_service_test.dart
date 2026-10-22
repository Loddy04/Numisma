// test/auth_service_test.dart
// Menguji aturan statis di AuthService (password kuat, nama tampilan, email).
// Bagian yang butuh database dan internet (register, login) diuji di HP.

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/services/auth_service.dart';

void main() {
  group('passwordProblem', () {
    test('password kuat lolos', () {
      expect(AuthService.passwordProblem('Abcdef1!'), isNull);
    });

    test('kurang dari 8 atau lebih dari 64 karakter ditolak', () {
      expect(AuthService.passwordProblem('Ab1!xyz'), AuthService.errPasswordLength);
      expect(
        AuthService.passwordProblem('Aa1!${'x' * 61}'),
        AuthService.errPasswordLength,
      );
      expect(AuthService.passwordProblem('Aa1!${'x' * 60}'), isNull); // 64
    });

    test('pesan menyebut syarat yang belum terpenuhi', () {
      expect(AuthService.passwordProblem('abcdefg1!'), contains('huruf besar'));
      expect(AuthService.passwordProblem('ABCDEFG1!'), contains('huruf kecil'));
      expect(AuthService.passwordProblem('Abcdefgh!'), contains('angka'));
      expect(AuthService.passwordProblem('Abcdefg12'), contains('simbol'));
    });

    test('spasi tidak dihitung sebagai simbol', () {
      expect(AuthService.passwordProblem('Abcdef 12'), contains('simbol'));
    });
  });

  group('displayNameProblem', () {
    test('1-30 karakter bebas, termasuk spasi dan simbol', () {
      expect(AuthService.displayNameProblem('Budi Santoso #1'), isNull);
      expect(AuthService.displayNameProblem('a'), isNull);
      expect(AuthService.displayNameProblem('x' * 30), isNull);
    });

    test('kosong atau lebih dari 30 ditolak', () {
      expect(AuthService.displayNameProblem(''), AuthService.errNameInvalid);
      expect(AuthService.displayNameProblem('   '), AuthService.errNameInvalid);
      expect(
        AuthService.displayNameProblem('x' * 31),
        AuthService.errNameInvalid,
      );
    });
  });

  group('email', () {
    test('format valid dan tidak valid', () {
      expect(AuthService.isValidEmail('budi@mail.com'), isTrue);
      expect(AuthService.isValidEmail('  Budi@Mail.COM '), isTrue);
      expect(AuthService.isValidEmail('budi@mail'), isFalse);
      expect(AuthService.isValidEmail('budi mail@x.com'), isFalse);
    });

    test('normalisasi: huruf kecil dan tanpa spasi di ujung', () {
      expect(AuthService.normalizeEmail('  Budi@Mail.COM '), 'budi@mail.com');
    });
  });
}
