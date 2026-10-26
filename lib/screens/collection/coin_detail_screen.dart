// screens/collection/coin_detail_screen.dart
// Detail satu koin. Layar menerima `coinId` (bukan objek Coin) dan
// memuat ulang lewat getById(), karena hanya getById yang mendekripsi
// catatan. Dengan begitu data selalu segar setelah diubah di form.
//
// Foto koin memakai efek tilt dari gyroscope (K8, widgets/tilt_photo.dart).
// Sensor accelerometer (goyang) ada di Coin Flip, bukan di layar ini.
// Pop dengan nilai true bila koin dihapus.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/coin.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
import '../../widgets/tilt_photo.dart';
import '../chat/chat_screen.dart';
import 'coin_form_screen.dart';
import 'coin_photo_viewer.dart';

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

  // Membuka chatbot dengan konteks koin ini (Guide 7.9b). Chat tidak mengubah
  // data; bila AI menyarankan koreksi, pengguna memakai tombol Ubah sendiri.
  void _askAi(Coin coin) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(contextCoin: coin)));
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
    // Foto asli bergerak halus mengikuti gyroscope (miringkan HP). Diketuk
    // = layar penuh dengan efek lebih dinamis. Tag Hero yang sama dipakai di
    // layar penuh supaya foto membesar dari posisinya.
    final heroTag = 'coin-photo-${coin.id}';
    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CoinPhotoViewer(photoPath: path, heroTag: heroTag),
            ),
          ),
          child: TiltPhoto(
            height: 220,
            child: Hero(
              tag: heroTag,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ketuk foto untuk layar penuh · miringkan HP untuk menggeser',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final coin = _coin;
    if (coin == null) {
      return const Center(child: Text('Koin tidak ditemukan.'));
    }
    final jenis = coin.type == 'banknote' ? 'Uang kertas' : 'Koin';

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
        _row(
          'Catatan',
          coin.notesUnreadable
              ? 'Catatan tidak bisa dibuka di perangkat ini '
                    '(kunci enkripsi berbeda).'
              : coin.notes,
        ),
        _row('Ringkasan AI', coin.aiSummary),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _askAi(coin),
          icon: const Icon(Icons.chat),
          label: const Text('Tanya Numisma tentang koin ini'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
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
