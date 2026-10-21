// test/chain_service_test.dart
// Menguji bagian murni Jejak Catatan (rumus hash, proof-of-work, dan
// pemeriksaan struktur rantai) tanpa database: data_hash kanonik, nonce
// menghasilkan hash berawalan "00", dan perubahan sekecil apa pun pada blok
// atau sambungannya terdeteksi.

import 'package:flutter_test/flutter_test.dart';
import 'package:numisma/models/block.dart';
import 'package:numisma/services/chain_service.dart';

ChainBlock _block(int idx, String prev, String action, {String? coinId}) {
  const ts = '2026-10-22T03:00:00.000Z';
  final dataHash = ChainService.dataHashOf({'id': coinId ?? 'g', 'n': idx});
  final found = ChainService.mine(
    idx: idx,
    ts: ts,
    coinId: coinId,
    action: action,
    dataHash: dataHash,
    photoHash: null,
    photoSource: 'none',
    prevHash: prev,
  );
  return ChainBlock(
    userId: 1,
    idx: idx,
    ts: ts,
    coinId: coinId,
    action: action,
    dataHash: dataHash,
    photoSource: 'none',
    prevHash: prev,
    nonce: found.nonce,
    hash: found.hash,
  );
}

ChainBlock _copy(ChainBlock b, {String? dataHash, String? prevHash}) {
  return ChainBlock(
    userId: b.userId,
    idx: b.idx,
    ts: b.ts,
    coinId: b.coinId,
    action: b.action,
    dataHash: dataHash ?? b.dataHash,
    photoHash: b.photoHash,
    photoSource: b.photoSource,
    prevHash: prevHash ?? b.prevHash,
    nonce: b.nonce,
    hash: b.hash,
  );
}

List<ChainBlock> _validChain() {
  final g = _block(0, ChainService.zeroHash, 'GENESIS');
  final a = _block(1, g.hash, 'ADD', coinId: 'coin-1');
  final u = _block(2, a.hash, 'UPDATE', coinId: 'coin-1');
  return [g, a, u];
}

void main() {
  test('data_hash tidak bergantung urutan kunci (JSON kanonik)', () {
    final a = ChainService.dataHashOf({
      'id': 'x',
      'year': 1990,
      'type': 'coin',
    });
    final b = ChainService.dataHashOf({
      'type': 'coin',
      'id': 'x',
      'year': 1990,
    });
    expect(a, b);
  });

  test('tipe data ikut menentukan hash (100.0 beda dengan "100")', () {
    final asDouble = ChainService.dataHashOf({'denomination': 100.0});
    final asString = ChainService.dataHashOf({'denomination': '100'});
    expect(asDouble, isNot(asString));
  });

  test('null dihash sebagai string kosong, bukan "null"', () {
    String h(String? photoHash) => ChainService.computeHash(
      idx: 1,
      ts: 't',
      coinId: 'c',
      action: 'ADD',
      dataHash: 'd',
      photoHash: photoHash,
      photoSource: 'none',
      prevHash: 'p',
      nonce: 0,
    );
    expect(h(null), h(''));
    expect(h(null), isNot(h('null')));
  });

  test('proof-of-work: hash diawali "00", termasuk genesis', () {
    final chain = _validChain();
    for (final b in chain) {
      expect(b.hash.startsWith('00'), isTrue);
    }
    expect(chain.first.prevHash, '0' * 64);
  });

  test('rantai utuh lolos pemeriksaan', () {
    expect(ChainService.checkBlocks(_validChain()), isEmpty);
  });

  test('isi blok diubah -> blok itu ditandai', () {
    final chain = _validChain();
    chain[1] = _copy(chain[1], dataHash: 'diubah');
    final problems = ChainService.checkBlocks(chain);
    expect(problems.keys, contains(1));
  });

  test('sambungan prev_hash putus -> blok setelahnya ditandai', () {
    final chain = _validChain();
    chain[2] = _copy(chain[2], prevHash: 'x' * 64);
    final problems = ChainService.checkBlocks(chain);
    expect(problems.keys, contains(2));
  });

  test('blok dihapus dari tengah rantai terdeteksi', () {
    final chain = _validChain()..removeAt(1);
    expect(ChainService.checkBlocks(chain), isNotEmpty);
  });
}
