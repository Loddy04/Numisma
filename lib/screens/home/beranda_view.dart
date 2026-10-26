// screens/home/beranda_view.dart
// Tampilan Beranda bergaya buku koleksi: header (foto profil, nama),
// "Daftar Koleksi" (jumlah koin dan uang kertas), "Daftar Acara" (jumlah dan
// acara terdekat), lalu "Daftar Isi" berisi menu fitur dengan titik penuntun
// dan nomor halaman. Kotak ringkasan dibuat ringkas: satu garis tipis, isi
// transparan.
// Hanya tampilan: data dan aksi diberikan HomeShell lewat parameter, jadi file
// ini tidak memanggil service.
//
// Nomor di daftar isi hanya hiasan bertema buku (urutan 1, 2, 3, ...),
// bukan data. Tarik ke bawah untuk menyegarkan.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../theme.dart';
import '../../widgets/double_rule.dart';

class BerandaView extends StatelessWidget {
  final String username;
  final String? photoPath; // foto profil; null = ikon orang
  final int coinCount;
  final int banknoteCount;
  final bool statsLoaded;
  // Daftar Acara: jumlah acara yang belum mulai dan yang paling dekat
  // waktunya (null = tidak ada).
  final int upcomingCount;
  final Event? nextEvent;
  final bool eventsLoaded;
  final VoidCallback onOpenEvents;
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
    required this.upcomingCount,
    required this.nextEvent,
    required this.eventsLoaded,
    required this.onOpenEvents,
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
    return Column(
      children: [
        // Header satu warna dengan latar kertas, dipisah dari isi oleh garis
        // ganda yang sama dengan tepi atas bottom nav.
        SafeArea(bottom: false, child: _header()),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              children: [
                _sectionTitle('KOLEKSI ANDA'),
                const SizedBox(height: 10),
                _collectionCard(),
                const SizedBox(height: 18),
                _sectionTitle('ACARA ANDA'),
                const SizedBox(height: 10),
                _eventCard(),
                const SizedBox(height: 18),
                _sectionTitle('DAFTAR ISI'),
                const SizedBox(height: 4),
                for (var i = 0; i < _menu.length; i++) _menuRow(i),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Foto profil di kiri (hanya tampilan, tidak bisa diketuk; Profil dibuka
  // lewat bottom nav), sapaan di kanan. Nama pengguna bisa sampai 30
  // karakter, jadi kolom kanan mengisi sisa ruang, rata kanan, dan boleh
  // turun baris.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Halo,',
                  style: AppText.serif(size: 18, italic: true),
                ),
                Text(
                  username,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppText.serif(
                    size: 28,
                    weight: FontWeight.bold,
                  ),
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

  // Kerangka kotak: isi transparan (warna kertas Beranda), satu garis tipis,
  // dan sudut lancip (tanpa lengkung). Mengetuk kotak memanggil [onTap].
  Widget _card({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      // Transparan: isi kotak memakai warna latar kertas Beranda.
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.ink.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 44,
    margin: const EdgeInsets.symmetric(vertical: 8),
    color: AppColors.ink.withValues(alpha: 0.15),
  );

  // Daftar Koleksi: tiga angka sebaris. Hanya data nyata; nilai uang sengaja
  // tidak ditampilkan karena butuh kurs dari internet.
  Widget _collectionCard() {
    final total = coinCount + banknoteCount;
    String n(int v) => statsLoaded ? '$v' : '–';
    return _card(
      onTap: () => onOpen('Koleksi'),
      child: Row(
        children: [
          Expanded(child: _stat('KOIN', n(coinCount))),
          _divider(),
          Expanded(child: _stat('UANG KERTAS', n(banknoteCount))),
          _divider(),
          Expanded(child: _stat('JUMLAH', n(total))),
        ],
      ),
    );
  }

  // Satu angka (cokelat tua logo, seperti ikon Daftar Isi) dengan label
  // hitam di bawahnya.
  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppText.serif(
              size: 26,
              weight: FontWeight.w700,
              color: AppColors.bronze,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: AppText.mono(size: 10, spacing: 1),
          ),
        ],
      ),
    );
  }

  // Daftar Acara: kiri jumlah acara yang akan datang, kanan acara terdekat
  // (waktu WIB, hitung mundur, tempat) atau ajakan menambah bila kosong.
  Widget _eventCard() {
    return _card(
      onTap: onOpenEvents,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: _stat('AKAN DATANG', eventsLoaded ? '$upcomingCount' : '–'),
          ),
          _divider(),
          Expanded(child: _nextEventInfo(nextEvent)),
        ],
      ),
    );
  }

  Widget _nextEventInfo(Event? next) {
    if (next == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            eventsLoaded ? 'Belum ada acara. Ketuk untuk menambah.' : 'Memuat…',
            style: AppText.serif(size: 14, italic: true),
          ),
        ),
      );
    }
    final until = next.startUtc.difference(DateTime.now().toUtc());
    final place = (next.location ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            next.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            formatZone(next.startUtc, zoneWib),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(size: 11),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                // Huruf yang sama dengan nama tempat (serif miring), hanya
                // warnanya cokelat tua dan tebal.
                TextSpan(
                  text: formatCountdown(until),
                  style: AppText.serif(
                    size: 13,
                    italic: true,
                    weight: FontWeight.w700,
                    color: AppColors.bronze,
                  ),
                ),
                if (place.isNotEmpty)
                  TextSpan(
                    text: '  ·  $place',
                    style: AppText.serif(size: 13, italic: true),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Judul bagian: garis, teks kapital berjarak lebar, garis.
  Widget _sectionTitle(String title) {
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
            title,
            style: AppText.serif(size: 18, spacing: 4, weight: FontWeight.w500),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
