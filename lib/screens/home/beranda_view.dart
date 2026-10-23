// screens/home/beranda_view.dart
// Tampilan Beranda bergaya buku koleksi: header (foto profil, sapaan), kotak
// ringkasan bergaris ganda, lalu "Daftar Isi" berisi menu fitur dengan titik
// penuntun dan nomor halaman. Hanya tampilan: data dan aksi diberikan
// HomeShell lewat parameter, jadi file ini tidak memanggil service.
//
// Nomor di daftar isi hanya hiasan bertema buku (urutan 1, 2, 3, ...),
// bukan data. Tarik ke bawah untuk menyegarkan.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/double_rule.dart';

class BerandaView extends StatelessWidget {
  final String username;
  final String? photoPath; // foto profil; null = ikon orang
  final int coinCount;
  final int banknoteCount;
  final bool statsLoaded;
  final Future<void> Function() onRefresh;
  // Dipanggil dengan label menu yang diketuk.
  final ValueChanged<String> onOpen;

  const BerandaView({
    super.key,
    required this.username,
    required this.photoPath,
    required this.coinCount,
    required this.banknoteCount,
    required this.statsLoaded,
    required this.onRefresh,
    required this.onOpen,
  });

  static const _menu = <_MenuItem>[
    _MenuItem('Koleksi', Icons.collections_bookmark_outlined),
    _MenuItem('Konversi', Icons.swap_horiz),
    _MenuItem('Tanya Numisma', Icons.chat_bubble_outline),
    _MenuItem('Jelajah', Icons.location_on_outlined),
    _MenuItem('Permainan', Icons.casino_outlined),
    _MenuItem('Jejak Catatan', Icons.link),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _header(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: DoubleRule(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              // AlwaysScrollable supaya tarikan terdeteksi walau isinya muat
              // dalam satu layar.
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  _summaryBox(),
                  const SizedBox(height: 28),
                  _tocTitle(),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _menu.length; i++) _menuRow(i),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Foto profil di kiri (hanya tampilan, tidak bisa diketuk; Profil dibuka
  // lewat bottom nav), sapaan di kanan. Nama pengguna bisa sampai 30
  // karakter, jadi kolom kanan mengisi sisa ruang, rata kanan, dan boleh
  // turun baris.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Halo,', style: AppText.serif(size: 18, italic: true)),
                Text(
                  username,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppText.mono(size: 14, weight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Foto profil bulat dengan bingkai tipis. Belum ada foto = ikon orang.
  // File yang hilang tidak boleh merusak tampilan: errorBuilder menampilkan
  // ikon orang juga.
  Widget _avatar() {
    const size = 52.0;
    final person = Container(
      width: size,
      height: size,
      color: AppColors.gold.withValues(alpha: 0.4),
      child: const Icon(Icons.person, size: 32, color: AppColors.bronze),
    );
    final path = photoPath;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink),
      ),
      child: ClipOval(
        child: path == null
            ? person
            : Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => person,
              ),
      ),
    );
  }

  // Kotak bergaris ganda: dua bingkai 1 px dengan celah 3 px, berisi tiga
  // kolom. Hanya data nyata (jumlah koin dan uang kertas); nilai uang sengaja
  // tidak ditampilkan karena butuh kurs dari internet.
  Widget _summaryBox() {
    final frame = Border.all(color: AppColors.ink);
    final total = coinCount + banknoteCount;
    String n(int v) => statsLoaded ? '$v' : '–';
    return Container(
      decoration: BoxDecoration(border: frame),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(border: frame),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cell('KOIN', n(coinCount)),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.ink,
              ),
              _cell('UANG\nKERTAS', n(banknoteCount)),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.ink,
              ),
              _cell('JUMLAH', n(total)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tinggi dua baris tetap, supaya angka tiap kolom sejajar
            // walau hanya "UANG KERTAS" yang berbaris dua.
            SizedBox(
              height: 32,
              child: Text(
                label,
                style: AppText.mono(
                  size: 11,
                  spacing: 2,
                  color: AppColors.bronze,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppText.serif(size: 38, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tocTitle() {
    final line = Expanded(
      child: Container(
        height: 1,
        color: AppColors.ink.withValues(alpha: 0.7),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'DAFTAR ISI',
            style: AppText.serif(size: 22, spacing: 4, weight: FontWeight.w500),
          ),
        ),
        line,
      ],
    );
  }

  // Satu baris menu: ikon, nama, titik penuntun, nomor.
  Widget _menuRow(int index) {
    final item = _menu[index];
    return InkWell(
      onTap: () => onOpen(item.label),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(item.icon, size: 26, color: AppColors.bronze),
            const SizedBox(width: 14),
            Text(
              item.label,
              style: AppText.serif(size: 24, weight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  height: 2,
                  child: CustomPaint(painter: _DotsPainter()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('${index + 1}', style: AppText.mono(size: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  const _MenuItem(this.label, this.icon);
}

// Titik-titik penuntun antara nama menu dan nomor.
class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink.withValues(alpha: 0.5);
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x + 1, size.height / 2), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
