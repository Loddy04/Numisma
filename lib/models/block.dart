// models/block.dart
// Model data untuk tabel `chain_blocks` (NUMISMA_GUIDE 5.1 dan 7.13): satu
// blok Jejak Catatan. Hanya bentuk data; rumus hash dan proof-of-work ada di
// chain_service.dart.

class ChainBlock {
  final int? id; // null sebelum disimpan
  final int userId;
  final int idx; // 0 = genesis
  final String ts; // ISO-8601 UTC
  final String? coinId; // null pada genesis
  final String action; // GENESIS / ADD / UPDATE / DELETE
  final String dataHash;
  final String? photoHash;
  final String? photoSource; // camera / gallery / none
  final String prevHash;
  final int nonce;
  final String hash;
  final bool isSynced;
  // Nomor transaksi di jaringan Sepolia bila blok ini sudah dijangkarkan
  // (null = belum). TIDAK ikut dalam rumus hash blok, jadi mengisinya tidak
  // mengubah hash maupun hasil verifikasi.
  final String? txHash;

  const ChainBlock({
    this.id,
    required this.userId,
    required this.idx,
    required this.ts,
    this.coinId,
    required this.action,
    required this.dataHash,
    this.photoHash,
    this.photoSource,
    required this.prevHash,
    required this.nonce,
    required this.hash,
    this.isSynced = false,
    this.txHash,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'idx': idx,
    'ts': ts,
    'coin_id': coinId,
    'action': action,
    'data_hash': dataHash,
    'photo_hash': photoHash,
    'photo_source': photoSource,
    'prev_hash': prevHash,
    'nonce': nonce,
    'hash': hash,
    'is_synced': isSynced ? 1 : 0,
    'tx_hash': txHash,
  };

  factory ChainBlock.fromMap(Map<String, dynamic> map) => ChainBlock(
    id: map['id'] as int?,
    userId: map['user_id'] as int,
    idx: map['idx'] as int,
    ts: map['ts'] as String,
    coinId: map['coin_id'] as String?,
    action: map['action'] as String,
    dataHash: map['data_hash'] as String,
    photoHash: map['photo_hash'] as String?,
    photoSource: map['photo_source'] as String?,
    prevHash: map['prev_hash'] as String,
    nonce: map['nonce'] as int,
    hash: map['hash'] as String,
    isSynced: (map['is_synced'] as int) == 1,
    txHash: map['tx_hash'] as String?,
  );
}
