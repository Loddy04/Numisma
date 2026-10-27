// screens/home/beranda_view.dart
// Beranda bergaya "elegan modern": logo dan foto profil di atas, kartu hero
// bergradasi cokelat berisi jumlah koleksi dan nilai nominal setara, satu
// kartu "Acara terdekat", lalu grid "Menu" berisi menu fitur. Latar
// krem bergradasi dipasang HomeShell.
// Hanya tampilan: data dan aksi diberikan HomeShell lewat parameter, jadi file
// ini tidak memanggil service. Tarik ke bawah untuk menyegarkan.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';

class BerandaView extends StatelessWidget {
  final String username;
  final String? photoPath; // foto profil; null = ikon orang
  final int coinCount;
  final int banknoteCount;
  final bool statsLoaded;
  // Acara terdekat: jumlah acara yang belum mulai dan yang paling dekat
  // waktunya (null = tidak ada).
  final int upcomingCount;
  final Event? nextEvent;
  final bool eventsLoaded;
  final VoidCallback onOpenEvents; // ketuk kartu acara terdekat
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

  // Bayangan lembut kartu putih: cokelat susu, blur lebar, spread negatif
  // supaya bayangan tidak melebar di sisi kartu dan mengikuti sudut bulat.
  static final _softShadow = [
    BoxShadow(
      color: AppColors.bronze.withValues(alpha: 0.20),
      blurRadius: 22,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  // Bayangan kartu hero: lebih pekat dan lebih lebar.
  static final _heroShadow = [
    BoxShadow(
      color: AppColors.heroDark.withValues(alpha: 0.38),
      blurRadius: 28,
      spreadRadius: -6,
      offset: const Offset(0, 14),
    ),
  ];

  // Bayangan dipasang pada pembungkus terpisah (bukan pada Ink): bayangan
  // yang digambar Ink ikut terpotong dan tampak kotak, sedangkan pembungkus
  // ini mengikuti sudut bulat kartu.
  Widget _shadowed(double radius, List<BoxShadow> shadow, Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: child,
    );
  }

  // Garis tepi krem tua yang sangat tipis, supaya kartu putih terpisah halus
  // dari latar krem.
  static final _cardBorder = Border.all(color: const Color(0xFFEADBC4));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        // AlwaysScrollable supaya tarikan terdeteksi walau isinya muat dalam
        // satu layar.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [
            _topBar(),
            const SizedBox(height: 16),
            _heroCard(),
            const SizedBox(height: 18),
            _sectionTitle('Acara terdekat'),
            const SizedBox(height: 10),
            _eventCard(),
            const SizedBox(height: 18),
            _sectionTitle('Menu'),
            const SizedBox(height: 10),
            _menuGrid(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: AppText.serif(size: 20, weight: FontWeight.w700));

  // Logo dan nama aplikasi di kiri, foto profil di kanan. Foto hanya tampilan
  // (Profil dibuka lewat bottom nav).
  Widget _topBar() {
    return Row(
      children: [
        const AppLogo(size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Numisma',
            style: AppText.serif(size: 24, weight: FontWeight.w700),
          ),
        ),
        _avatar(),
      ],
    );
  }

  // Foto profil bulat dengan bingkai krem. Belum ada foto = ikon orang. File
  // yang hilang tidak boleh merusak tampilan: errorBuilder menampilkan ikon
  // orang juga.
  Widget _avatar() {
    const size = 56.0;
    final person = Container(
      width: size,
      height: size,
      color: AppColors.gold.withValues(alpha: 0.5),
      child: const Icon(Icons.person, size: 36, color: AppColors.bronze),
    );
    final path = photoPath;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: _softShadow,
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

  // Kartu hero: sapaan dan nama besar, jumlah item, chip koin dan uang kertas,
  // lalu nilai nominal setara. Nilai uang butuh kurs; tanpa kurs tampil "–".
  Widget _heroCard() => _shadowed(24, _heroShadow, _heroInk());

  Widget _heroInk() {
    final total = coinCount + banknoteCount;
    String n(int v) => statsLoaded ? '$v' : '–';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onOpen('Koleksi'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroDark, AppColors.heroLight],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Lingkaran-lingkaran tipis di pojok kanan atas, hiasan
                // bergaya koin.
                const Positioned(
                  top: -50,
                  right: -50,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(painter: _RingsPainter()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.serif(
                          size: 28,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'KOLEKSIMU',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE6CFA3),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            n(total),
                            style: AppText.serif(
                              size: 48,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'item',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _chip('${n(coinCount)} koin'),
                          const SizedBox(width: 8),
                          _chip('${n(banknoteCount)} uang kertas'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  // Satu kartu putih: kotak tanggal emas, judul, jam dan tempat, dan chip
  // hitung mundur. Kosong = ajakan menambah acara.
  Widget _eventCard() => _shadowed(20, _softShadow, _eventInk());

  Widget _eventInk() {
    final next = nextEvent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenEvents,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: _cardBorder,
          ),
          child: next == null ? _emptyEvent() : _eventRow(next),
        ),
      ),
    );
  }

  Widget _emptyEvent() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.tileActive,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_outlined, color: AppColors.bronze),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            eventsLoaded
                ? 'Belum ada acara. Ketuk untuk menambah.'
                : 'Memuat acara…',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.ink.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.ink),
      ],
    );
  }

  Widget _eventRow(Event next) {
    final local = toZone(next.startUtc, zoneWib);
    final until = next.startUtc.difference(DateTime.now().toUtc());
    final place = (next.location ?? '').trim();
    final when =
        '${formatZoneTime(next.startUtc, zoneWib)} '
        '${zoneAbbreviation(next.startUtc, zoneWib)}'
        '${place.isEmpty ? '' : ' · $place'}';
    return Row(
      children: [
        Container(
          width: 54,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEBD8AE), AppColors.gold],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${local.day}',
                style: AppText.serif(
                  size: 24,
                  weight: FontWeight.w700,
                  color: AppColors.heroDark,
                ),
              ),
              Text(
                monthNamesId[local.month - 1].toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heroDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tileActive,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatCountdown(until),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bronze,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.ink),
      ],
    );
  }

  // Grid 3 kolom × 2 baris. Tiap kartu: ikon cokelat besar di tengah dengan
  // nama fitur di bawahnya.
  Widget _menuGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Tanpa pemotongan: bayangan kartu keluar dari batas grid.
      clipBehavior: Clip.none,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [for (final item in _menu) _menuTile(item)],
    );
  }

  Widget _menuTile(_MenuItem item) =>
      _shadowed(18, _softShadow, _menuInk(item));

  Widget _menuInk(_MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onOpen(item.label),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFFAF1E2)],
            ),
            border: _cardBorder,
          ),
          // Ikon besar di tengah kartu, nama di bawahnya.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 38, color: AppColors.bronze),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
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

// Lingkaran-lingkaran tipis sepusat, hiasan di kartu hero.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);
    final center = Offset(size.width / 2, size.height / 2);
    for (var r = 30.0; r < size.width / 2; r += 20) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
