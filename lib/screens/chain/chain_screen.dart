// screens/chain/chain_screen.dart
// Jejak Catatan (K13, NUMISMA_GUIDE 7.13): daftar blok hash chain milik akun,
// tombol Verifikasi, dan tombol demo "Ubah data diam-diam". Layar tidak
// menghitung hash sendiri: semuanya lewat ChainService (aturan Bagian 4.1).

import 'package:flutter/material.dart';

import '../../core/time_util.dart';
import '../../models/block.dart';
import '../../services/auth_service.dart';
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

  int? _userId;
  List<ChainBlock> _blocks = [];
  // coin_id -> "Jepang 100", untuk menampilkan nama koin di tiap blok.
  Map<String, String> _coinLabels = {};
  int _coinCount = 0;

  ChainVerifyResult? _result; // null = belum diverifikasi
  TamperInfo? _tamper; // ada = data sedang diubah diam-diam oleh demo
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
      // Akun lama (dibuat sebelum fitur ini) dibuatkan rantai pada pembukaan
      // pertama; akun yang sudah punya rantai tidak diubah.
      await _chain.ensureChain(_userId!);
      final blocks = await _chain.blocksOf(_userId!);
      final coins = await _coins.list(_userId!);
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _coinCount = coins.length;
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

  // Demo: mengubah data koin langsung di tabel tanpa blok, lalu verifikasi
  // otomatis dijalankan supaya hasilnya langsung terlihat.
  Future<void> _tamperSilently() async {
    final id = _userId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final info = await _chain.tamperSilently(id);
      if (info == null) {
        _snack('Belum ada koin untuk diubah. Tambah koin dulu.');
        return;
      }
      setState(() => _tamper = info);
      await _verify();
      _snack('Nominal satu koin diubah tanpa catatan. Lihat hasil verifikasi.');
    } catch (_) {
      _snack('Gagal menjalankan demo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final info = _tamper;
    if (info == null) return;
    setState(() => _busy = true);
    try {
      await _chain.restoreTampered(info);
      setState(() {
        _tamper = null;
        _result = null;
      });
      await _verify();
      _snack('Data asli dikembalikan.');
    } catch (_) {
      _snack('Gagal mengembalikan data.');
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Widget _actions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _busy ? null : _verify,
          icon: const Icon(Icons.verified_user),
          label: const Text('Verifikasi'),
        ),
        const SizedBox(height: 8),
        if (_tamper == null)
          OutlinedButton.icon(
            onPressed: _busy || _coinCount == 0 ? null : _tamperSilently,
            icon: const Icon(Icons.warning_amber),
            label: const Text('Ubah data diam-diam (demo)'),
          )
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.undo),
            label: const Text('Kembalikan data asli'),
          ),
      ],
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
