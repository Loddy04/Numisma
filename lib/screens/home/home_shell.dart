// screens/home/home_shell.dart
// Kerangka utama setelah login (NUMISMA_GUIDE Bagian 4.3): bottom nav
// 5 ikon + isi tab. Ikon Scan di tengah dibuat menonjol, jadi kita
// TIDAK memakai BottomNavigationBar bawaan Flutter (bentuknya datar
// dan tidak bisa menonjolkan satu ikon). Gantinya: Stack berisi bar
// biasa + satu tombol bulat yang "naik" dari garis bar.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/notif_service.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../collection/collection_screen.dart';
import '../convert/convert_screen.dart';
import '../feedback/feedback_screen.dart';
import '../profile/profile_screen.dart';

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
      if (user != null) _syncReminders(user.id!);
    } catch (_) {
      // Gagal memuat foto tidak fatal: ikon orang bawaan tetap tampil.
    }
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

  // Item grid Beranda. Halaman aslinya dibuat di hari-hari berikutnya,
  // untuk sekarang tiap item membuka halaman placeholder.
  static const _features = <_Feature>[
    _Feature('Koleksi', Icons.collections_bookmark),
    _Feature('Konversi', Icons.currency_exchange),
    _Feature('Jelajah', Icons.map),
    _Feature('Jejak Catatan', Icons.link),
    _Feature('Tanya Numisma', Icons.chat),
    _Feature('Game', Icons.sports_esports),
    _Feature('Sinkron', Icons.cloud_sync),
  ];

  // Ikon Koleksi sudah punya halaman asli; sisanya masih placeholder
  // sampai fiturnya dibuat di hari-hari berikutnya.
  void _openFeature(String label) {
    if (label == 'Koleksi') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CollectionScreen()));
    } else if (label == 'Konversi') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ConvertScreen()));
    } else {
      _openPlaceholder(label);
    }
  }

  void _openPlaceholder(String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _PlaceholderPage(title: title)));
  }

  // Scan = aksi cepat, bukan tab. Nanti diganti membuka scan_screen.dart
  // (Hari 4); sekarang placeholder.
  void _onScan() => _openPlaceholder('Scan');

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

  Widget _buildGrid() {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        for (final f in _features)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openFeature(f.label),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(f.icon, size: 36, color: AppColors.bronze),
                  const SizedBox(height: 8),
                  Text(
                    f.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
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
      // Di Beranda, judul AppBar disertai logo; tab lain tetap teks saja.
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
