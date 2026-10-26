// screens/home/home_shell.dart
// Kerangka utama setelah login (NUMISMA_GUIDE Bagian 4.3): bottom nav
// 5 ikon + isi tab. Ikon Scan di tengah dibuat menonjol, jadi kita
// TIDAK memakai BottomNavigationBar bawaan Flutter (bentuknya datar
// dan tidak bisa menonjolkan satu ikon). Gantinya: Stack berisi bar
// biasa + satu tombol bulat yang "naik" dari garis bar.

import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/coin.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../services/event_repo.dart';
import '../../services/rates_service.dart';
import '../../services/notif_service.dart';
import '../../services/sync_service.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../auth/login_screen.dart';
import '../chain/chain_screen.dart';
import '../chat/chat_screen.dart';
import '../collection/collection_screen.dart';
import '../convert/convert_screen.dart';
import '../explore/event_detail_screen.dart';
import '../explore/explore_screen.dart';
import '../feedback/feedback_screen.dart';
import '../game/game_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';
import 'beranda_view.dart';

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

  // Nama tampilan untuk sapaan. Awalnya dari login, diperbarui bila pengguna
  // menggantinya di Profil.
  late String _username = widget.username;

  // Ringkasan koleksi untuk kartu di Beranda.
  int _coinCount = 0;
  int _banknoteCount = 0;
  bool _statsLoaded = false;

  // Nilai nominal setara seluruh koleksi dalam rupiah (null = belum ada atau
  // kurs tidak tersedia). Dihitung di latar belakang dari cache kurs, tidak
  // menahan layar.
  CollectionValue? _value;

  // Ringkasan acara untuk Daftar Acara di Beranda: jumlah yang akan datang
  // dan yang paling dekat waktunya (null bila tidak ada).
  int _upcomingCount = 0;
  Event? _nextEvent;
  bool _eventsLoaded = false;

  // Mencoba mengunggah perubahan yang tertunda tiap menit. Tanpa paket
  // pemantau koneksi: bila tadi offline, perubahan terkirim paling lambat
  // semenit setelah internet kembali. Bila tidak ada yang tertunda, tidak
  // ada permintaan jaringan sama sekali.
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final user = await _authService.currentUser();
      if (user != null) unawaited(SyncService.syncQuietly(user.id!));
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    try {
      final user = await _authService.currentUser();
      if (!mounted) return;
      setState(() => _photoPath = user?.photoPath);
      // Sinkron otomatis saat Beranda dibuka dan saat ditarik untuk
      // menyegarkan; tanpa await supaya tidak menahan layar.
      if (user != null) unawaited(SyncService.syncQuietly(user.id!));
      // Ditunggu supaya indikator tarik-untuk-menyegarkan baru hilang setelah
      // jadwal pengingat selesai dimuat ulang.
      if (user != null) await _syncReminders(user.id!);
      await _loadStats();
      await _loadEvents();
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
      unawaited(_loadValue(coins));
    } catch (_) {}
  }

  // Nilai nominal setara dalam IDR. Gagal (offline tanpa cache) tidak fatal:
  // kartu menampilkan tanda "–".
  Future<void> _loadValue(List<Coin> coins) async {
    try {
      final value = await RatesService().valueOfCoins(coins, 'IDR');
      if (!mounted) return;
      setState(() => _value = value);
    } catch (_) {}
  }

  // Acara yang belum mulai milik akun ini, diurut dari yang paling awal.
  // Gagal tidak fatal: bagian acara tampil seperti belum ada acara.
  Future<void> _loadEvents() async {
    try {
      final user = await _authService.currentUser();
      if (user == null) return;
      final all = await EventRepo().list(user.id!);
      final now = DateTime.now().toUtc();
      final upcoming = all.where((e) => e.startUtc.isAfter(now)).toList()
        ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
      if (!mounted) return;
      setState(() {
        _upcomingCount = upcoming.length;
        _nextEvent = upcoming.isEmpty ? null : upcoming.first;
        _eventsLoaded = true;
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

  // Daftar Acara di Beranda: acara terdekat membuka detailnya, bila kosong
  // membuka tab Acara di Jelajah. Daftar dimuat ulang setelah kembali.
  void _openEvents() {
    final next = _nextEvent;
    final page = next == null
        ? const ExploreScreen(initialTab: 1)
        : EventDetailScreen(eventId: next.id);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => page)).then((_) => _loadEvents());
  }

  // "+N lainnya": daftar semua acara (tab Acara di Jelajah).
  void _openEventList() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const ExploreScreen(initialTab: 1)),
        )
        .then((_) => _loadEvents());
  }

  // Membuka halaman fitur dari menu Jelajahi di Beranda.
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
    } else if (label == 'Permainan') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
    } else if (label == 'Jelajah') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ExploreScreen())).then(
        (_) => _loadEvents(),
      );
    }
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
    final yakin = await confirmDialog(
      context,
      title: 'Keluar dari Numisma?',
      message:
          'Sesi akan dihapus dan pengingat akunmu dibatalkan. Koleksimu tetap '
          'tersimpan dan muncul lagi saat kamu masuk.',
      confirmLabel: 'Keluar',
    );
    if (!yakin) return;

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
          onNameChanged: (name) => setState(() => _username = name),
        );
      case _tabSaran:
        return const FeedbackScreen();
      default:
        return _buildGrid();
    }
  }

  // Beranda bergaya buku koleksi; tampilannya ada di BerandaView. Tarik ke
  // bawah untuk menyegarkan (foto profil, pengingat, jumlah koleksi).
  Widget _buildGrid() {
    return BerandaView(
      username: _username,
      photoPath: _photoPath,
      coinCount: _coinCount,
      banknoteCount: _banknoteCount,
      statsLoaded: _statsLoaded,
      upcomingCount: _upcomingCount,
      nextEvent: _nextEvent,
      eventsLoaded: _eventsLoaded,
      value: _value,
      onOpenEvents: _openEvents,
      onOpenEventList: _openEventList,
      onRefresh: _loadPhoto,
      onOpen: _openFeature,
    );
  }

  // Satu ikon bar. Yang aktif diberi latar krem lembut dengan ikon dan label
  // cokelat tua logo, sisanya tinta pudar.
  Widget _navItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final color = active
        ? AppColors.bronze
        : AppColors.ink.withValues(alpha: 0.6);
    return Expanded(
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.tileActive : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bottom nav kapsul melayang: bar putih bersudut bulat dengan bayangan lembut
  // dan tombol Scan bulat bergradasi cokelat di tengah, sedikit terangkat
  // dengan cincin krem. Tombol tetap DI DALAM area widget supaya bisa ditekan
  // (area di luar batas induk tidak menerima sentuhan).
  Widget _buildBottomNav() {
    const barHeight = 64.0;
    const scanSize = 60.0;
    const lift = 14.0; // seberapa tinggi Scan naik dari tepi atas bar
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      // Wilayah di sekitar kapsul memakai warna dasar gradasi Beranda.
      color: _tab == _tabBeranda ? AppColors.creamBottom : AppColors.paper,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottomInset),
      child: SizedBox(
        height: barHeight + lift,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.heroDark.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _navItem(
                    icon: Icons.home_outlined,
                    label: 'Beranda',
                    active: _tab == _tabBeranda,
                    onTap: () => setState(() => _tab = _tabBeranda),
                  ),
                  _navItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    active: _tab == _tabProfil,
                    onTap: () => setState(() => _tab = _tabProfil),
                  ),
                  // Ruang kosong di tengah untuk tombol Scan.
                  const Expanded(child: SizedBox()),
                  _navItem(
                    icon: Icons.rate_review_outlined,
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
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.creamTop,
                ),
                child: Material(
                  shape: const CircleBorder(),
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.heroLight, AppColors.heroDark],
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _onScan,
                      child: const SizedBox(
                        width: scanSize - 8,
                        height: scanSize - 8,
                        child: Icon(
                          Icons.center_focus_strong_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
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
    final beranda = _tab == _tabBeranda;
    return Scaffold(
      // Beranda memakai latar krem bergradasi dan header sendiri (BerandaView),
      // jadi tanpa AppBar. Tab lain memakai AppBar tema global.
      backgroundColor: beranda ? AppColors.creamBottom : null,
      appBar: beranda ? null : AppBar(title: Text(_titles[_tab])),
      body: beranda
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.creamTop, AppColors.creamBottom],
                ),
              ),
              child: _buildBody(),
            )
          : _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
