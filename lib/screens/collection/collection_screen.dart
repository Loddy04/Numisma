// screens/collection/collection_screen.dart
// Daftar koleksi milik pengguna yang sedang login. Data dimuat ulang
// dari CoinRepo setiap layar dibuka dan setiap kali kembali dari
// form/detail (NUMISMA_GUIDE Bagian 4.4: setState + muat ulang).
//
// Cari, filter, urut, dan multi-pilih ditambahkan di langkah berikutnya
// (K11); struktur ini sengaja dibuat supaya fitur itu tinggal menambah
// parameter pada _load().

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/coin.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import 'coin_detail_screen.dart';
import 'coin_form_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _authService = AuthService();
  final _repo = CoinRepo();

  int? _userId;
  List<Coin> _coins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Layar tidak menerima userId lewat konstruktor; ia bertanya ke
      // AuthService siapa yang sedang login (sumber kebenarannya session).
      final user = await _authService.currentUser();
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final coins = await _repo.list(user.id!);
      if (!mounted) return;
      setState(() {
        _userId = user.id;
        _coins = coins;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat koleksi, coba lagi.')),
      );
    }
  }

  Future<void> _openForm() async {
    if (_userId == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CoinFormScreen(userId: _userId!)),
    );
    _load();
  }

  Future<void> _openDetail(Coin coin) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CoinDetailScreen(coinId: coin.id)),
    );
    _load();
  }

  Widget _thumbnail(Coin coin) {
    const size = 56.0;
    final path = coin.photoPath;
    // Foto bisa tidak ada (koin tanpa foto, atau hasil Pulihkan nanti);
    // errorBuilder menjaga tampilan tetap rapi, bukan crash.
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(
        coin.type == 'banknote' ? Icons.payments : Icons.monetization_on,
        color: AppColors.bronze,
      ),
    );
    if (path == null) return fallback;
    return ClipOval(
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_coins.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Koleksi masih kosong.\nTekan tombol Tambah untuk mencatat koin pertamamu.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: _coins.length,
      itemBuilder: (context, i) {
        final coin = _coins[i];
        final jenis = coin.type == 'banknote' ? 'Uang kertas' : 'Koin';
        final detail = [
          jenis,
          if (coin.year != null) '${coin.year}',
          if (coin.condition != null) coin.condition!,
        ].join(' • ');
        return Card(
          child: ListTile(
            leading: _thumbnail(coin),
            title: Text(
              '${coin.denominationLabel} ${coin.currencyCode} — ${coin.country}',
            ),
            subtitle: Text(detail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetail(coin),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koleksi')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}
