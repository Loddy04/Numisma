// screens/collection/coin_detail_screen.dart
// Detail satu koin. Layar menerima `coinId` (bukan objek Coin) dan
// memuat ulang lewat getById(), karena hanya getById yang mendekripsi
// catatan. Dengan begitu data selalu segar setelah diubah di form.
//
// Efek sensor (goyang = flip, tilt) ditambahkan di Hari 3 (K8); layar
// ini sengaja masih sederhana. Pop dengan nilai true bila koin dihapus.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/coin.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import 'coin_form_screen.dart';

class CoinDetailScreen extends StatefulWidget {
  final String coinId;
  const CoinDetailScreen({super.key, required this.coinId});

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  final _repo = CoinRepo();

  Coin? _coin;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final coin = await _repo.getById(widget.coinId);
      if (!mounted) return;
      setState(() {
        _coin = coin;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat detail koin.')),
      );
    }
  }

  Future<void> _edit() async {
    final coin = _coin;
    if (coin == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CoinFormScreen(userId: coin.userId, coin: coin),
      ),
    );
    _load();
  }

  Future<void> _delete() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus koin'),
        content: const Text('Koin ini akan dihapus dari koleksi. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    try {
      await _repo.delete(widget.coinId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus, coba lagi.')),
      );
    }
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPhoto(Coin coin) {
    final path = coin.photoPath;
    final placeholder = Container(
      height: 220,
      color: AppColors.gold.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Icon(
        coin.type == 'banknote' ? Icons.payments : Icons.monetization_on,
        size: 72,
        color: AppColors.bronze,
      ),
    );
    if (path == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(path),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final coin = _coin;
    if (coin == null) {
      return const Center(child: Text('Koin tidak ditemukan.'));
    }
    final jenis = coin.type == 'banknote' ? 'Uang kertas' : 'Koin';
    final harga = coin.buyPrice == null
        ? null
        : '${coin.buyPrice} ${coin.buyCurrency ?? ''}'.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPhoto(coin),
        const SizedBox(height: 16),
        Text(
          '${coin.denominationLabel} ${coin.currencyCode}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _row('Jenis', jenis),
        _row('Negara', coin.country),
        _row('Tahun', coin.year?.toString()),
        _row('Kondisi', coin.condition),
        _row('Harga beli', harga),
        _row('Catatan', coin.notes),
        _row('Ringkasan AI', coin.aiSummary),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.edit),
          label: const Text('Ubah'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.delete),
          label: const Text('Hapus'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Koin')),
      body: _buildBody(),
    );
  }
}
