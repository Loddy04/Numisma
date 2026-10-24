// screens/chain/chain_screen.dart
// Jejak Catatan (K13, NUMISMA_GUIDE 7.13): daftar blok hash chain milik akun,
// dan tombol Verifikasi. Layar tidak menghitung hash sendiri: semuanya lewat
// ChainService (aturan Bagian 4.1).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/time_util.dart';
import '../../models/block.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/chain_anchor_service.dart';
import '../../services/chain_service.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';

class ChainScreen extends StatefulWidget {
  const ChainScreen({super.key});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  final _chain = ChainService();
  final _coins = CoinRepo();
  final _auth = AuthService();
  final _anchor = ChainAnchorService();

  User? _user;
  AnchorCheck? _anchorCheck; // hasil "Periksa di jaringan" terakhir
  bool _anchorBusy = false;

  int? _userId;
  List<ChainBlock> _blocks = [];
  // coin_id -> "Jepang 100", untuk menampilkan nama koin di tiap blok.
  Map<String, String> _coinLabels = {};

  ChainVerifyResult? _result; // null = belum diverifikasi
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _auth.currentUser();
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Sesi tidak ditemukan. Masuk ulang.';
          _loading = false;
        });
        return;
      }
      _userId = user.id!;
      _user = user;
      // Akun lama (dibuat sebelum fitur ini) dibuatkan rantai pada pembukaan
      // pertama; akun yang sudah punya rantai tidak diubah.
      await _chain.ensureChain(_userId!);
      final blocks = await _chain.blocksOf(_userId!);
      final coins = await _coins.list(_userId!);
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _coinLabels = {
          for (final c in coins) c.id: '${c.country} ${c.denominationLabel}',
        };
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Jejak Catatan gagal dimuat. Coba lagi.';
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    final id = _userId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final result = await _chain.verify(id);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      _snack('Verifikasi gagal dijalankan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Blok terakhir yang sudah dijangkarkan ke jaringan (null = belum ada).
  ChainBlock? get _lastAnchored {
    for (final b in _blocks.reversed) {
      if (b.txHash != null) return b;
    }
    return null;
  }

  // Mengirim blok terakhir ke jaringan sekarang (selain pengiriman otomatis
  // setelah sinkron).
  Future<void> _anchorNow() async {
    final user = _user;
    if (user == null) return;
    setState(() => _anchorBusy = true);
    try {
      final tx = await _anchor.anchorHead(user);
      _snack(
        tx == null
            ? 'Blok terakhir sudah tercatat di jaringan.'
            : 'Terkirim ke jaringan. Konfirmasi butuh sekitar setengah menit.',
      );
      await _load();
    } on AnchorException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(ChainAnchorService.errGeneric);
    } finally {
      if (mounted) setState(() => _anchorBusy = false);
    }
  }

  Future<void> _checkAnchor() async {
    final user = _user;
    if (user == null) return;
    setState(() => _anchorBusy = true);
    final check = await _anchor.checkOnChain(user);
    if (!mounted) return;
    setState(() {
      _anchorCheck = check;
      _anchorBusy = false;
    });
  }

  Future<void> _openExplorer(String txHash) async {
    try {
      final ok = await launchUrl(
        Uri.parse(ChainAnchorService.explorerUrl(txHash)),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _snack('Tidak bisa membuka Etherscan.');
    } catch (_) {
      _snack('Tidak bisa membuka Etherscan.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jejak Catatan')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _helpCard(),
          if (Config.ethConfigured) ...[
            const SizedBox(height: 8),
            _anchorCard(),
          ],
          const SizedBox(height: 8),
          _actions(),
          if (_result != null) _summary(_result!),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Blok (${_blocks.length}), terbaru di atas',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final b in _blocks.reversed) _blockCard(b),
        ],
      ),
    );
  }

  Widget _helpCard() {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Setiap koin yang ditambah, diubah, atau dihapus dicatat sebagai blok '
          'yang saling terkait lewat hash. Menjamin catatan tidak diubah '
          'diam-diam. Tidak membuktikan keaslian atau kepemilikan koin fisik.',
          style: TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  // Kartu status blockchain: blok terakhir yang sudah dicatat di Sepolia,
  // tombol buka Etherscan, periksa kecocokan dengan jaringan, dan kirim
  // sekarang. Pengiriman otomatis terjadi setelah sinkron.
  Widget _anchorCard() {
    final last = _lastAnchored;
    final check = _anchorCheck;
    Color colorOf(AnchorState s) => switch (s) {
      AnchorState.matched => AppColors.success,
      AnchorState.mismatch || AnchorState.failed => AppColors.danger,
      _ => Colors.grey,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: AppColors.bronze),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Blockchain Sepolia',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_anchorBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              last == null
                  ? 'Belum ada blok yang dicatat di jaringan. Pencatatan '
                        'berjalan otomatis setelah sinkron.'
                  : 'Terakhir dicatat: blok #${last.idx} · tx '
                        '${last.txHash!.substring(0, 10)}…',
              style: const TextStyle(fontSize: 13),
            ),
            if (check != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  check.message,
                  style: TextStyle(
                    color: colorOf(check.state),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: _anchorBusy ? null : _anchorNow,
                  child: const Text('Catat sekarang'),
                ),
                if (last != null) ...[
                  OutlinedButton(
                    onPressed: _anchorBusy ? null : _checkAnchor,
                    child: const Text('Periksa di jaringan'),
                  ),
                  OutlinedButton(
                    onPressed: () => _openExplorer(last.txHash!),
                    child: const Text('Etherscan'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    return ElevatedButton.icon(
      onPressed: _busy ? null : _verify,
      icon: const Icon(Icons.verified_user),
      label: const Text('Verifikasi'),
    );
  }

  Widget _summary(ChainVerifyResult r) {
    final ok = r.ok;
    final color = ok ? AppColors.success : AppColors.danger;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
                const SizedBox(width: 8),
                Text(
                  ok ? 'Catatan utuh' : 'Catatan telah diubah',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${r.blockCount} blok diperiksa.'),
            for (final p in r.coinProblems)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('✘ $p', style: TextStyle(color: color)),
              ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(String action) => switch (action) {
    'GENESIS' => 'Genesis',
    'ADD' => 'Tambah koin',
    'UPDATE' => 'Ubah koin',
    'DELETE' => 'Hapus koin',
    _ => action,
  };

  String _short(String hash) => '${hash.substring(0, 12)}…';

  Widget _blockCard(ChainBlock b) {
    final result = _result;
    final problem = result?.blockProblems[b.idx];
    final verified = result != null;
    final ok = verified && problem == null;

    final coinName = b.coinId == null
        ? null
        : (_coinLabels[b.coinId] ?? '(koin sudah dihapus)');
    final time = formatZone(DateTime.parse(b.ts).toUtc(), zoneWib);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${b.idx} · ${_actionLabel(b.action)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (verified)
                  Text(
                    ok ? '✔ utuh' : '✘ berubah',
                    style: TextStyle(
                      color: ok ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (coinName != null) Text(coinName),
            Text(time, style: const TextStyle(color: Colors.grey)),
            if (b.txHash != null)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  '⛓ tercatat di jaringan Sepolia',
                  style: TextStyle(fontSize: 12, color: AppColors.bronze),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'hash ${_short(b.hash)} · sebelumnya ${_short(b.prevHash)} · nonce ${b.nonce}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  problem,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
