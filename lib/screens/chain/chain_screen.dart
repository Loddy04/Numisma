// screens/chain/chain_screen.dart
// Jejak Catatan (K13, NUMISMA_GUIDE 7.13): daftar blok hash chain milik akun
// sebagai lini waktu, dan tombol Verifikasi. Layar tidak menghitung hash
// sendiri: semuanya lewat ChainService (aturan Bagian 4.1).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/format_util.dart';
import '../../core/time_util.dart';
import '../../models/block.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/chain_anchor_service.dart';
import '../../services/chain_service.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/soft_card.dart';

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

  // Verifikasi menyatukan dua pemeriksaan: (1) rantai di HP (hash tiap blok,
  // sambungan, proof-of-work, dan kecocokan dengan data koin), lalu (2) bila
  // blockchain dikonfigurasi, kecocokan blok terakhir yang dicatat dengan
  // transaksi di Sepolia. Langkah kedua yang tidak bisa dijalankan (belum ada
  // catatan, offline) hanya menampilkan pesannya dan tidak menggagalkan
  // verifikasi lokal.
  Future<void> _verify() async {
    final id = _userId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _anchorCheck = null;
    });
    try {
      final result = await _chain.verify(id);
      if (!mounted) return;
      setState(() => _result = result);
      final user = _user;
      if (Config.ethConfigured && user != null) {
        final check = await _anchor.checkOnChain(user);
        if (!mounted) return;
        setState(() => _anchorCheck = check);
      }
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

  // --- Tampilan ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(side: BorderSide(color: AppColors.cardBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.chevron_left, color: AppColors.bronze),
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Row(
      children: [
        _backButton(),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Jejak Catatan',
            style: AppText.serif(size: 32, weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(),
            Expanded(
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    final blocks = _blocks.reversed.toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _titleRow(),
          const SizedBox(height: 18),
          _statusCard(),
          const SizedBox(height: 12),
          Text(
            'Menjamin catatan tidak diubah diam-diam. Tidak membuktikan '
            'keaslian atau kepemilikan koin fisik.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.ink.withValues(alpha: 0.65),
            ),
          ),
          if (Config.ethConfigured) ...[
            const SizedBox(height: 16),
            _anchorCard(),
          ],
          const SizedBox(height: 18),
          for (var i = 0; i < blocks.length; i++)
            _timelineItem(blocks[i], last: i == blocks.length - 1),
        ],
      ),
    );
  }

  Color _anchorColor(AnchorState s) => switch (s) {
    AnchorState.matched => AppColors.success,
    AnchorState.mismatch || AnchorState.failed => AppColors.danger,
    _ => AppColors.ink.withValues(alpha: 0.6),
  };

  // Kartu status: sebelum verifikasi netral, "Catatan utuh" hijau lembut, atau
  // "Catatan telah diubah" merah lembut. Tombol Verifikasi ada di kanan.
  Widget _statusCard() {
    final r = _result;
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;
    if (r == null) {
      color = AppColors.bronze;
      icon = Icons.shield_outlined;
      title = 'Belum diverifikasi';
      subtitle = '${_blocks.length} blok';
    } else if (r.ok) {
      color = AppColors.success;
      icon = Icons.verified_user_outlined;
      title = 'Catatan utuh';
      subtitle = '${r.blockCount} blok terverifikasi';
    } else {
      color = AppColors.danger;
      icon = Icons.gpp_bad_outlined;
      title = 'Catatan telah diubah';
      subtitle = '${r.blockCount} blok diperiksa';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: r == null ? 0.06 : 0.16),
            color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 38, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.serif(
                        size: 22,
                        weight: FontWeight.w700,
                        color: r == null ? AppColors.ink : color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: (r == null ? AppColors.ink : color).withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 118,
                child: GradientButton(
                  label: 'Verifikasi',
                  height: 44,
                  loading: _busy,
                  onPressed: _busy ? null : _verify,
                ),
              ),
            ],
          ),
          // Hasil pemeriksaan di jaringan (bagian dari Verifikasi).
          if (_anchorCheck != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (_anchorCheck!.state) {
                      AnchorState.matched => Icons.check_circle_outline,
                      AnchorState.mismatch ||
                      AnchorState.failed => Icons.error_outline,
                      _ => Icons.info_outline,
                    },
                    size: 18,
                    color: _anchorColor(_anchorCheck!.state),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _anchorCheck!.message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: _anchorColor(_anchorCheck!.state),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (r != null)
            for (final p in r.coinProblems)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '✘ $p',
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ),
        ],
      ),
    );
  }

  // Info singkat blockchain: blok terakhir yang sudah dicatat di Sepolia dan
  // tautan ke Etherscan. Pencatatan berjalan otomatis setelah sinkron, dan
  // pemeriksaannya ikut tombol Verifikasi.
  Widget _anchorCard() {
    final last = _lastAnchored;
    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          const Icon(Icons.link, color: AppColors.bronze),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blockchain Sepolia', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  last == null
                      ? 'Belum ada blok yang dicatat di jaringan. Pencatatan '
                            'berjalan otomatis setelah sinkron.'
                      : 'Terakhir dicatat: blok #${last.idx}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.ink.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          if (last != null)
            TextButton(
              onPressed: () => _openExplorer(last.txHash!),
              child: const Text('Etherscan'),
            ),
        ],
      ),
    );
  }

  // --- Lini waktu blok -----------------------------------------------

  String _actionLabel(String action) => switch (action) {
    'GENESIS' => 'GENESIS',
    _ => action,
  };

  // Warna chip aksi: ADD hijau, UPDATE krem, DELETE merah, GENESIS abu.
  (Color, Color) _chipColors(String action) => switch (action) {
    'ADD' => (AppColors.chipOk, AppColors.chipOkText),
    'UPDATE' => (AppColors.tileActive, AppColors.bronze),
    'DELETE' => (AppColors.danger.withValues(alpha: 0.12), AppColors.danger),
    _ => (AppColors.chipOff, AppColors.chipOffText),
  };

  // "26 Okt 14:02" dalam WIB.
  String _timeOf(String ts) {
    final t = toZone(DateTime.parse(ts).toUtc(), zoneWib);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.day} ${monthNamesId[t.month - 1]} ${two(t.hour)}:${two(t.minute)}';
  }

  String _short(String hash) =>
      '${hash.substring(0, 8)}…${hash.substring(hash.length - 4)}';

  Widget _timelineItem(ChainBlock b, {required bool last}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.brown,
                  ),
                  child: Text(
                    '${b.idx}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _blockCard(b),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockCard(ChainBlock b) {
    final result = _result;
    final problem = result?.blockProblems[b.idx];
    final verified = result != null;
    final ok = verified && problem == null;

    final title = b.action == 'GENESIS'
        ? 'Blok awal'
        : (b.coinId == null
              ? _actionLabel(b.action)
              : (_coinLabels[b.coinId] ?? '(koin sudah dihapus)'));
    final (chipBg, chipFg) = _chipColors(b.action);

    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
                if (verified)
                  Icon(
                    ok ? Icons.check : Icons.close,
                    size: 22,
                    color: ok ? AppColors.success : AppColors.danger,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _actionLabel(b.action),
                    style: TextStyle(
                      fontSize: 12,
                      color: chipFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _timeOf(b.ts),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.ink.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _short(b.hash),
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppColors.ink.withValues(alpha: 0.55),
              ),
            ),
            if (b.txHash != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: AppColors.bronze),
                    const SizedBox(width: 4),
                    Text(
                      'Tercatat di jaringan Sepolia',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.bronze.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
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
