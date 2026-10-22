// screens/home/home_shell.dart
// Kerangka utama setelah login (NUMISMA_GUIDE Bagian 4.3): bottom nav
// 5 ikon + isi tab. Ikon Scan di tengah dibuat menonjol, jadi kita
// TIDAK memakai BottomNavigationBar bawaan Flutter (bentuknya datar
// dan tidak bisa menonjolkan satu ikon). Gantinya: Stack berisi bar
// biasa + satu tombol bulat yang "naik" dari garis bar.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../services/notif_service.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../chain/chain_screen.dart';
import '../chat/chat_screen.dart';
import '../collection/collection_screen.dart';
import '../convert/convert_screen.dart';
import '../feedback/feedback_screen.dart';
import '../game/game_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';

class HomeShell extends StatefulWidget {
  final String username;
  const HomeShell({super.key, required this.username});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _authService = AuthService();

  // Hanya 3 ikon yang punya halaman (Beranda, Profil, Saran). Scan dan
  // Keluar adalah aksi, jadi tidak mengubah indeks tab yang aktif.
  static const _tabBeranda = 0;
  static const _tabProfil = 1;
  static const _tabSaran = 2;
  int _tab = _tabBeranda;

  static const _titles = ['Numisma', 'Profil', 'Saran & Kesan'];

  // Path foto profil, dipegang di sini (bukan di ProfileScreen) karena
  // ikon Profil di bottom nav juga menampilkannya. ProfileScreen
  // memberi tahu lewat callback saat foto diganti.
  String? _photoPath;

  // Ringkasan koleksi untuk kartu di Beranda.
  int _coinCount = 0;
  int _banknoteCount = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      final user = await _authService.currentUser();
      if (!mounted) return;
      setState(() => _photoPath = user?.photoPath);
      // Ditunggu supaya indikator tarik-untuk-menyegarkan baru hilang setelah
      // jadwal pengingat selesai dimuat ulang.
      if (user != null) await _syncReminders(user.id!);
      await _loadStats();
    } catch (_) {
      // Gagal memuat foto tidak fatal: ikon orang bawaan tetap tampil.
    }
  }

  // Jumlah koin dan uang kertas milik akun ini. Gagal tidak fatal: kartu
  // tetap tampil tanpa angka.
  Future<void> _loadStats() async {
    try {
      final user = await _authService.currentUser();
      if (user == null) return;
      final coins = await CoinRepo().list(user.id!);
      if (!mounted) return;
      setState(() {
        _coinCount = coins.where((c) => c.type == 'coin').length;
        _banknoteCount = coins.length - _coinCount;
        _statsLoaded = true;
      });
    } catch (_) {}
  }

  // Akun yang login sudah diketahui di sini: jadwalkan ulang pengingat AKUN
  // INI (force-stop membatalkan alarm sistem) dan batalkan alarm milik akun
  // lain. Alarm Android per perangkat, sedangkan acara per akun.
  Future<void> _syncReminders(int userId) async {
    try {
      await NotifService().rescheduleAll(userId);
    } catch (_) {
      // Gagal menjadwalkan ulang tidak boleh mengganggu layar utama.
    }
  }

  // Item grid Beranda. Sinkron sementara tetap di sini (masih placeholder);
  // rencananya dipindah ke layar Koleksi saat dibuat di Hari 5 (Guide 7.4),
  // lalu grid kembali enam item (3x2).
  static const _features = <_Feature>[
    _Feature('Koleksi', Icons.collections_bookmark_outlined),
    _Feature('Konversi', Icons.currency_exchange),
    _Feature('Jelajah', Icons.map_outlined),
    _Feature('Jejak Catatan', Icons.link),
    _Feature('Tanya Numisma', Icons.chat_bubble_outline),
    _Feature('Game', Icons.sports_esports_outlined),
    _Feature('Sinkron', Icons.cloud_sync_outlined),
  ];

  // Ikon Koleksi sudah punya halaman asli; sisanya masih placeholder
  // sampai fiturnya dibuat di hari-hari berikutnya.
  void _openFeature(String label) {
    if (label == 'Koleksi') {
      // Jumlah koleksi di kartu Beranda dimuat ulang setelah kembali.
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CollectionScreen()))
          .then((_) => _loadStats());
    } else if (label == 'Konversi') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ConvertScreen()));
    } else if (label == 'Jejak Catatan') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChainScreen()));
    } else if (label == 'Tanya Numisma') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } else if (label == 'Game') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
    } else {
      _openPlaceholder(label);
    }
  }

  void _openPlaceholder(String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _PlaceholderPage(title: title)));
  }

  // Scan = aksi cepat, bukan tab: langsung membuka scan_screen.dart. Hasilnya
  // true bila koin tersimpan, supaya pengguna diberi kabar di Beranda.
  Future<void> _onScan() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (saved == true && mounted) {
      _loadStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koin disimpan ke Koleksi.')),
      );
    }
  }

  // Keluar tidak punya halaman: tampilkan dialog, dan indeks tab aktif
  // tidak diubah supaya kalau dibatalkan pengguna tetap di tab semula.
  Future<void> _onLogout() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _tabProfil:
        return ProfileScreen(
          onPhotoChanged: (path) => setState(() => _photoPath = path),
        );
      case _tabSaran:
        return const FeedbackScreen();
      default:
        return _buildGrid();
    }
  }

  // Beranda: header (sapaan di kiri, merek di kanan), kartu ringkasan
  // koleksi, lalu enam fitur. Tarik ke bawah untuk menyegarkan (foto profil,
  // pengingat, dan jumlah koleksi dimuat ulang). ListView memakai
  // AlwaysScrollableScrollPhysics supaya tarikan terdeteksi walau isinya
  // muat dalam satu layar.
  Widget _buildGrid() {
    return Column(
      children: [
        // Sapaan menyambung dari AppBar: satu bidang perunggu dengan sudut
        // bawah membulat, jadi bagian atas layar tetap berwarna.
        _greeting(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPhoto,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                _collectionCard(),
                const SizedBox(height: 28),
                Text(
                  'MENU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: AppColors.textDark.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 12),
                _featureGrid(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Garis tipis perunggu: pembatas kartu tanpa bayangan tebal.
  ShapeBorder _cardShape(double radius) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.25)),
  );

  // Sapaan di bawah AppBar. Username dari Splash (data akun yang login),
  // tanpa baca database. Username panjang boleh turun ke baris kedua.
  Widget _greeting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.bronze,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Halo,',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          Text(
            widget.username,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Kartu ringkasan: hanya data nyata (jumlah koin dan uang kertas), diketuk
  // untuk membuka Koleksi. Nilai uang sengaja tidak ditampilkan di sini karena
  // butuh kurs dari internet dan memperlambat Beranda.
  Widget _collectionCard() {
    final total = _coinCount + _banknoteCount;
    final detail = !_statsLoaded
        ? ' '
        : (total == 0
              ? 'Belum ada koin. Ketuk untuk menambah.'
              : '$_coinCount koin · $_banknoteCount uang kertas');
    return Material(
      color: AppColors.latte,
      shape: _cardShape(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFeature('Koleksi'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koleksimu',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statsLoaded ? '$total item' : '...',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.bronze),
            ],
          ),
        ),
      ),
    );
  }

  // Ubin fitur: ikon besar di tengah dengan label di bawahnya, di atas warna
  // cokelat susu lembut. Tanpa bayangan dan tanpa efek kaca; pembatasnya
  // garis tipis perunggu.
  Widget _featureGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: [
        for (final f in _features)
          Material(
            color: AppColors.latte,
            shape: _cardShape(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openFeature(f.label),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(f.icon, size: 40, color: AppColors.bronze),
                    const SizedBox(height: 10),
                    Text(
                      f.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Satu ikon bar. Yang aktif diwarnai perunggu, sisanya abu-abu.
  // `customIcon` menggantikan ikon bawaan (dipakai Profil untuk foto).
  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Widget? customIcon,
  }) {
    final color = active ? AppColors.bronze : Colors.grey;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon ?? Icon(icon, color: color),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  // Foto profil kecil berbentuk lingkaran sebagai ikon tab Profil.
  // Null = belum ada foto, pakai ikon orang bawaan (customIcon null).
  // Cincin perunggu menandai tab Profil sedang aktif.
  Widget? _profileNavIcon() {
    final path = _photoPath;
    if (path == null) return null;
    final active = _tab == _tabProfil;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.bronze : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 11,
        backgroundImage: FileImage(File(path)),
        // File hilang tidak boleh membuat nav crash.
        onBackgroundImageError: (_, _) {},
      ),
    );
  }

  Widget _buildBottomNav() {
    const barHeight = 64.0;
    const scanSize = 64.0;
    // Tinggi total = bar + bagian tombol Scan yang menonjol di atasnya.
    // Tombol sengaja tetap DI DALAM area widget supaya bisa ditekan
    // (area di luar batas induk tidak menerima sentuhan).
    const totalHeight = barHeight + scanSize / 2;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: barHeight,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  _navItem(
                    icon: Icons.home,
                    label: 'Beranda',
                    active: _tab == _tabBeranda,
                    onTap: () => setState(() => _tab = _tabBeranda),
                  ),
                  _navItem(
                    icon: Icons.person,
                    customIcon: _profileNavIcon(),
                    label: 'Profil',
                    active: _tab == _tabProfil,
                    onTap: () => setState(() => _tab = _tabProfil),
                  ),
                  // Ruang kosong di tengah untuk tombol Scan.
                  const Expanded(child: SizedBox()),
                  _navItem(
                    icon: Icons.rate_review,
                    label: 'Saran',
                    active: _tab == _tabSaran,
                    onTap: () => setState(() => _tab = _tabSaran),
                  ),
                  _navItem(
                    icon: Icons.logout,
                    label: 'Keluar',
                    onTap: _onLogout,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Material(
                color: AppColors.bronze,
                shape: const CircleBorder(),
                elevation: 6,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _onScan,
                  child: const SizedBox(
                    width: scanSize,
                    height: scanSize,
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar perunggu tetap ada di semua tab. Di Beranda judulnya disertai
      // logo; tab lain teks saja.
      appBar: AppBar(
        title: _tab == _tabBeranda
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 28),
                  const SizedBox(width: 8),
                  Text(_titles[_tab]),
                ],
              )
            : Text(_titles[_tab]),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class _Feature {
  final String label;
  final IconData icon;
  const _Feature(this.label, this.icon);
}

// Halaman sementara untuk fitur yang belum dibuat.
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — segera hadir')),
    );
  }
}
