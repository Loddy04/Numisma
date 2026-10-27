// screens/collection/coin_detail_screen.dart
// Detail satu koin. Layar menerima `coinId` (bukan objek Coin) dan
// memuat ulang lewat getById(), karena hanya getById yang mendekripsi
// catatan. Dengan begitu data selalu segar setelah diubah di form.
//
// Foto koin memakai efek tilt dari gyroscope (K8, widgets/tilt_photo.dart).
// Sensor accelerometer (goyang) ada di Coin Flip, bukan di layar ini.
// Tata letak: kepala bergradasi cokelat berisi foto besar, lalu kisi info,
// catatan, dan aksi. Pop dengan nilai true bila koin dihapus.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format_util.dart';
import '../../models/coin.dart';
import '../../services/coin_repo.dart';
import '../../services/currency_service.dart';
import '../../theme.dart';
import '../../widgets/coin_face.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/field_label.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/soft_card.dart';
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
    final yakin = await confirmDialog(
      context,
      title: 'Hapus koin?',
      message: 'Koin ini akan dihapus dari koleksi. Lanjutkan?',
    );
    if (!yakin) return;

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

  // "2026-10-21T..." (UTC) -> "21 Okt 2026" dalam waktu lokal HP.
  String _dateOf(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day} ${monthNamesId[d.month - 1]} ${d.year}';
  }

  // --- Tampilan ------------------------------------------------------

  // Foto asli bergerak halus mengikuti gyroscope (miringkan HP). Diketuk =
  // layar penuh dengan efek lebih dinamis. Tag Hero yang sama dipakai di layar
  // penuh supaya foto membesar dari posisinya. Koin berbentuk lingkaran, uang
  // kertas persegi panjang bersudut bulat. Tanpa foto: koin generik.
  Widget _buildPhoto(Coin coin) {
    final banknote = coin.type == 'banknote';
    final width = banknote ? 300.0 : 220.0;
    final height = banknote ? 170.0 : 220.0;
    final radius = BorderRadius.circular(banknote ? 20 : 110);
    final path = coin.photoPath;

    final placeholder = CoinFace(
      title: coin.denominationLabel,
      subtitle: coin.currencyCode,
      size: 180,
      banknote: banknote,
    );
    if (path == null) return Center(child: placeholder);

    final heroTag = 'coin-photo-${coin.id}';
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CoinPhotoViewer(photoPath: path, heroTag: heroTag),
            ),
          ),
          child: TiltPhoto(
            height: height,
            borderRadius: radius,
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
      ),
    );
  }

  // Kepala bergradasi: tombol kembali, tombol Ubah, foto besar, dan petunjuk.
  Widget _buildHeader(Coin coin) {
    Widget pill({required Widget child, VoidCallback? onTap}) => Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: child,
      ),
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.brown,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  pill(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.chevron_left, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPhoto(coin),
              const SizedBox(height: 14),
              Text(
                coin.photoPath == null
                    ? 'Foto belum tersedia di perangkat ini'
                    : 'Foto asli · miringkan HP untuk melihatnya dari sudut lain',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Satu sel info: label kecil huruf kapital dan nilainya.
  Widget _cell(String label, Widget value) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.fieldLabel,
              ),
            ),
            const SizedBox(height: 4),
            value,
          ],
        ),
      ),
    );
  }

  Widget _text(String? value) => Text(
    (value == null || value.isEmpty) ? '–' : value,
    style: const TextStyle(fontSize: 17),
  );

  // "Yen (JPY)" bila ada di daftar mata uang; selain itu kodenya saja.
  Widget _currencyValue(String code) {
    return FutureBuilder<List<CurrencyOption>>(
      future: CurrencyService.load(),
      builder: (context, snap) {
        final match = snap.data?.where((c) => c.code == code).firstOrNull;
        return _text(match?.label ?? code);
      },
    );
  }

  // Dua sel sebaris dengan tinggi sama. IntrinsicHeight wajib: baris dengan
  // CrossAxisAlignment.stretch di dalam ListView mendapat tinggi tak terbatas
  // dan membuat layar gagal tampil.
  Widget _row2(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, const SizedBox(width: 12), b],
      ),
    ),
  );

  // Kartu teks bebas (Catatan, Ringkasan AI).
  Widget _textCard(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label),
              Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),
            ],
          ),
        ),
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
    final subtitle = [
      coin.country,
      jenis,
      if (coin.year != null) '${coin.year}',
    ].join(' · ');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(coin),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${coin.denominationLabel} ${coin.currencyCode}',
                style: AppText.serif(size: 34, weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 18),
              _row2(
                _cell('Negara', _text(coin.country)),
                _cell('Mata uang', _currencyValue(coin.currencyCode)),
              ),
              _row2(
                _cell('Nominal', _text(coin.denominationLabel)),
                _cell('Tahun', _text(coin.year?.toString())),
              ),
              _row2(
                _cell('Kondisi', _text(coin.condition)),
                _cell('Dicatat', _text(_dateOf(coin.createdAt))),
              ),
              if (coin.notesUnreadable)
                _textCard(
                  'Catatan',
                  'Catatan tidak bisa dibuka di perangkat ini '
                      '(kunci enkripsi berbeda).',
                )
              else if ((coin.notes ?? '').isNotEmpty)
                _textCard('Catatan', coin.notes!),
              const SizedBox(height: 12),
              GradientButton(
                label: 'Tanya Numisma tentang koin ini',
                onPressed: () => _askAi(coin),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ubah'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus koin'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Kepala bergradasi menutupi bilah status, jadi ikon statusnya terang.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _buildBody(),
      ),
    );
  }
}
