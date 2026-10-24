// test/chain_anchor_test.dart
// Menguji bagian murni penjangkaran: teks yang ditulis ke jaringan dan
// pencocokannya dengan blok di HP. Pengiriman transaksi sungguhan diuji di HP.

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/models/block.dart';
import 'package:numisma/services/chain_anchor_service.dart';

final _hash = 'ab' * 32; // 64 karakter heksadesimal

ChainBlock _block(int idx, String hash) => ChainBlock(
  userId: 1,
  idx: idx,
  ts: '2026-10-25T03:00:00.000Z',
  action: 'ADD',
  dataHash: 'd' * 64,
  prevHash: '0' * 64,
  nonce: 1,
  hash: hash,
);

void main() {
  group('payload', () {
    test('format teks yang ditulis ke jaringan', () {
      expect(ChainAnchorService.payloadOf(5, _hash), 'numisma:v1:5:$_hash');
    });

    test('dibaca kembali menjadi nomor dan hash yang sama', () {
      final p = ChainAnchorService.parsePayload(
        ChainAnchorService.payloadOf(12, _hash),
      );
      expect(p, isNotNull);
      expect(p!.idx, 12);
      expect(p.hash, _hash);
    });

    test('teks yang bukan catatan Numisma ditolak', () {
      expect(ChainAnchorService.parsePayload('halo dunia'), isNull);
      expect(ChainAnchorService.parsePayload('numisma:v1:5:abc'), isNull);
      expect(ChainAnchorService.parsePayload('numisma:v2:5:$_hash'), isNull);
      expect(ChainAnchorService.parsePayload('numisma:v1:x:$_hash'), isNull);
      // hash huruf besar bukan format kita (hash kita selalu huruf kecil)
      expect(
        ChainAnchorService.parsePayload('numisma:v1:5:${_hash.toUpperCase()}'),
        isNull,
      );
    });

    test('spasi di ujung diabaikan', () {
      expect(
        ChainAnchorService.parsePayload(' numisma:v1:5:$_hash \n'),
        isNotNull,
      );
    });
  });

  group('payloadMatches', () {
    test('cocok bila nomor dan hash sama', () {
      final payload = ChainAnchorService.payloadOf(5, _hash);
      expect(
        ChainAnchorService.payloadMatches(payload, _block(5, _hash)),
        true,
      );
    });

    test('hash berbeda = tidak cocok (bukti perubahan)', () {
      final payload = ChainAnchorService.payloadOf(5, _hash);
      expect(
        ChainAnchorService.payloadMatches(payload, _block(5, 'cd' * 32)),
        false,
      );
    });

    test('nomor blok berbeda = tidak cocok', () {
      final payload = ChainAnchorService.payloadOf(5, _hash);
      expect(
        ChainAnchorService.payloadMatches(payload, _block(6, _hash)),
        false,
      );
    });

    test('teks sembarang = tidak cocok', () {
      expect(
        ChainAnchorService.payloadMatches('apa saja', _block(5, _hash)),
        false,
      );
    });
  });

  test('tautan Etherscan memakai jaringan Sepolia', () {
    expect(
      ChainAnchorService.explorerUrl('0xabc'),
      'https://sepolia.etherscan.io/tx/0xabc',
    );
  });
}
