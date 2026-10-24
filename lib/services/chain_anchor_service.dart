// services/chain_anchor_service.dart
// Penjangkaran Jejak Catatan ke blockchain sungguhan (K13, NUMISMA_GUIDE 7.13,
// dokumen progres-hari-5 bagian 9.4): setelah sinkron, nomor dan hash BLOK
// TERAKHIR dicatat di jaringan uji Ethereum Sepolia lewat satu transaksi biasa
// (tanpa smart contract). Data koin, foto, dan email tidak pernah dikirim:
// hanya teks pendek "numisma:v1:<idx>:<hash blok>".
//
// Kenapa cukup blok terakhir: hash tiap blok dihitung dari isi blok dan hash
// blok sebelumnya, jadi mengunci blok terakhir sekaligus mengunci seluruh
// riwayat di belakangnya. Catatan lama di jaringan tidak pernah dihapus:
// tiap penjangkaran menambah satu transaksi baru.
//
// Transaksi dikirim ke ALAMAT DOMPET SENDIRI (nilai 0) dengan kolom `data`
// berisi teks di atas; Etherscan menampilkannya sebagai "Input Data".
// Dompet adalah dompet testnet khusus proyek (kunci di .env, tanpa nilai uang).
//
// Semua kegagalan jaringan menjadi AnchorException berpesan ramah; di jalur
// otomatis (anchorQuietly) semuanya ditelan dan dicoba lagi nanti.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:web3dart/json_rpc.dart' show RPCError;
import 'package:web3dart/web3dart.dart';

import '../core/config.dart';
import '../core/db_helper.dart';
import '../models/block.dart';
import '../models/user.dart';

class AnchorException implements Exception {
  final String message;
  const AnchorException(this.message);

  @override
  String toString() => message;
}

// Hasil pemeriksaan blok terjangkar terakhir terhadap jaringan.
enum AnchorState {
  disabled, // kunci/RPC belum diisi di .env
  none, // belum ada blok yang dijangkarkan
  pending, // transaksi belum terkonfirmasi
  matched, // cocok dengan catatan di jaringan
  mismatch, // BERBEDA dari catatan di jaringan
  failed, // transaksi di jaringan gagal
  unreachable, // jaringan tidak terjangkau saat ini
}

class AnchorCheck {
  final AnchorState state;
  final int? idx;
  final String? txHash;
  final String message;

  const AnchorCheck(this.state, this.message, {this.idx, this.txHash});
}

class ChainAnchorService {
  static const explorerTxBase = 'https://sepolia.etherscan.io/tx/';
  static const _timeout = Duration(seconds: 30);

  static const errOffline =
      'Tidak bisa terhubung ke jaringan. Periksa internet lalu coba lagi.';
  static const errTimeout = 'Jaringan terlalu lama menjawab. Coba lagi nanti.';
  static const errNoFunds =
      'Saldo ETH testnet di dompet aplikasi habis. Isi ulang lewat faucet.';
  static const errRate =
      'Penyedia jaringan membatasi permintaan. Coba lagi sebentar lagi.';
  static const errGeneric = 'Gagal berhubungan dengan jaringan. Coba lagi.';

  // Setelah gagal, penjangkaran otomatis menunggu sebentar supaya tidak
  // mengetuk jaringan tiap menit (mis. saat saldo habis atau offline).
  static const _cooldown = Duration(minutes: 5);
  static DateTime? _cooldownUntil;
  static bool _running = false;

  static String explorerUrl(String txHash) => '$explorerTxBase$txHash';

  // ---------------------------------------------------------------
  // Bagian murni (tanpa jaringan), mudah diuji
  // ---------------------------------------------------------------

  // Teks yang ditulis ke jaringan. Tanpa email dan tanpa data koin.
  static String payloadOf(int idx, String hash) => 'numisma:v1:$idx:$hash';

  static final _payloadPattern = RegExp(r'^numisma:v1:(\d+):([0-9a-f]{64})$');

  // null bila teksnya bukan catatan Numisma yang sah.
  static ({int idx, String hash})? parsePayload(String text) {
    final m = _payloadPattern.firstMatch(text.trim());
    if (m == null) return null;
    return (idx: int.parse(m.group(1)!), hash: m.group(2)!);
  }

  // true bila catatan di jaringan sama dengan blok di HP (nomor dan hash).
  static bool payloadMatches(String payload, ChainBlock local) {
    final p = parsePayload(payload);
    return p != null && p.idx == local.idx && p.hash == local.hash;
  }

  // ---------------------------------------------------------------
  // Pintu otomatis
  // ---------------------------------------------------------------

  // Dipanggil setelah sinkron berhasil. Menelan semua kegagalan.
  static Future<void> anchorQuietly(User user) async {
    if (!Config.ethConfigured || _running) return;
    final until = _cooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    _running = true;
    try {
      await ChainAnchorService().anchorHead(user);
      _cooldownUntil = null;
    } catch (_) {
      _cooldownUntil = DateTime.now().add(_cooldown);
    } finally {
      _running = false;
    }
  }

  // ---------------------------------------------------------------
  // Mengirim
  // ---------------------------------------------------------------

  // Menjangkarkan blok terakhir bila belum. Mengembalikan nomor transaksi,
  // atau null bila tidak ada yang perlu dikirim (belum dikonfigurasi, belum
  // punya blok, atau blok terakhir sudah dijangkarkan).
  Future<String?> anchorHead(User user) async {
    if (!Config.ethConfigured) return null;
    final db = await DbHelper.instance.database;

    final headRows = await db.query(
      'chain_blocks',
      where: 'user_id = ?',
      whereArgs: [user.id],
      orderBy: 'idx DESC',
      limit: 1,
    );
    if (headRows.isEmpty) return null;
    final head = ChainBlock.fromMap(headRows.first);

    final anchoredRows = await db.query(
      'chain_blocks',
      columns: ['idx'],
      where: 'user_id = ? AND tx_hash IS NOT NULL',
      whereArgs: [user.id],
      orderBy: 'idx DESC',
      limit: 1,
    );
    final lastAnchored = anchoredRows.isEmpty
        ? null
        : anchoredRows.first['idx'] as int;
    if (lastAnchored != null && head.idx <= lastAnchored) return null;

    final data = Uint8List.fromList(
      utf8.encode(payloadOf(head.idx, head.hash)),
    );

    final txHash = await _withClient((client, key) async {
      // Harga gas dinaikkan 25% dari harga node supaya transaksi tidak
      // tertahan bila harga bergerak. Gas yang tidak terpakai dikembalikan.
      final gas = await client.getGasPrice();
      final price = EtherAmount.inWei(
        gas.getInWei * BigInt.from(125) ~/ BigInt.from(100),
      );
      return client.sendTransaction(
        key,
        Transaction(
          to: key.address, // ke dompet sendiri; yang dicatat adalah isinya
          value: EtherAmount.zero(),
          data: data,
          maxGas: 40000,
          gasPrice: price,
        ),
        chainId: Config.ethChainId,
      );
    });

    await db.update(
      'chain_blocks',
      {'tx_hash': txHash},
      where: 'user_id = ? AND idx = ?',
      whereArgs: [user.id, head.idx],
    );
    // Salinan nomor transaksi ke Supabase (opsional): supaya setelah aplikasi
    // dipasang ulang dan data dipulihkan, blok ini tidak dijangkarkan dua
    // kali. Gagal (mis. kolom tx_hash belum ditambahkan) tidak apa-apa.
    unawaited(_pushTxHash(user.emailHash, head.idx, txHash));
    return txHash;
  }

  Future<void> _pushTxHash(String key, int idx, String txHash) async {
    try {
      await Supabase.instance.client
          .from('chain_blocks')
          .update({'tx_hash': txHash})
          .eq('id', '$key:$idx');
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // Memeriksa
  // ---------------------------------------------------------------

  // Membaca transaksi blok terjangkar TERAKHIR dari jaringan dan
  // membandingkannya dengan blok di HP. Tidak melempar: semua hasil, termasuk
  // kegagalan jaringan, dikembalikan sebagai AnchorCheck.
  Future<AnchorCheck> checkOnChain(User user) async {
    if (!Config.ethConfigured) {
      return const AnchorCheck(
        AnchorState.disabled,
        'Blockchain belum dikonfigurasi di aplikasi ini.',
      );
    }
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'chain_blocks',
      where: 'user_id = ? AND tx_hash IS NOT NULL',
      whereArgs: [user.id],
      orderBy: 'idx DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return const AnchorCheck(
        AnchorState.none,
        'Belum ada blok yang dicatat di jaringan.',
      );
    }
    final block = ChainBlock.fromMap(rows.first);
    final tx = block.txHash!;

    try {
      return await _withClient((client, key) async {
        final info = await client.getTransactionByHash(tx);
        if (info == null || info.blockNumber.isPending) {
          return AnchorCheck(
            AnchorState.pending,
            'Menunggu konfirmasi jaringan untuk blok #${block.idx}.',
            idx: block.idx,
            txHash: tx,
          );
        }
        final receipt = await client.getTransactionReceipt(tx);
        if (receipt?.status == false) {
          return AnchorCheck(
            AnchorState.failed,
            'Transaksi untuk blok #${block.idx} gagal di jaringan.',
            idx: block.idx,
            txHash: tx,
          );
        }
        // Transaksi harus dikirim dari dompet aplikasi ini, bukan dari pihak
        // lain yang kebetulan memuat teks yang sama.
        final sentByUs =
            info.from.hex.toLowerCase() == key.address.hex.toLowerCase();
        final text = utf8.decode(info.input, allowMalformed: true);
        if (sentByUs && payloadMatches(text, block)) {
          return AnchorCheck(
            AnchorState.matched,
            'Cocok dengan catatan di jaringan (blok #${block.idx}).',
            idx: block.idx,
            txHash: tx,
          );
        }
        return AnchorCheck(
          AnchorState.mismatch,
          'Blok #${block.idx} di HP BERBEDA dari yang tercatat di jaringan.',
          idx: block.idx,
          txHash: tx,
        );
      });
    } on AnchorException catch (e) {
      return AnchorCheck(
        AnchorState.unreachable,
        e.message,
        idx: block.idx,
        txHash: tx,
      );
    }
  }

  // ---------------------------------------------------------------
  // Klien jaringan
  // ---------------------------------------------------------------

  // Membuka klien, menjalankan [body] dengan batas waktu, menerjemahkan
  // kegagalannya, lalu selalu menutup klien.
  Future<T> _withClient<T>(
    Future<T> Function(Web3Client client, EthPrivateKey key) body,
  ) async {
    final httpClient = http.Client();
    final client = Web3Client(Config.ethRpcUrl, httpClient);
    try {
      final key = EthPrivateKey.fromHex(Config.ethPrivateKey);
      return await body(client, key).timeout(_timeout);
    } on AnchorException {
      rethrow;
    } on TimeoutException {
      throw const AnchorException(errTimeout);
    } on SocketException {
      throw const AnchorException(errOffline);
    } on http.ClientException {
      throw const AnchorException(errOffline);
    } on RPCError catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('insufficient funds')) {
        throw const AnchorException(errNoFunds);
      }
      if (m.contains('rate') || m.contains('limit') || m.contains('429')) {
        throw const AnchorException(errRate);
      }
      throw const AnchorException(errGeneric);
    } catch (_) {
      throw const AnchorException(errGeneric);
    } finally {
      await client.dispose();
      httpClient.close();
    }
  }
}
