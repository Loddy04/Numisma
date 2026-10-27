// screens/profile/profile_screen.dart
// Isi tab Profil (K6, NUMISMA_GUIDE Bagian 7.6): foto pengguna dari
// kamera atau galeri, nama tampilan (bisa diganti), dan email. Layar ini hanya isi tab,
// tanpa Scaffold sendiri, karena AppBar dan bottom nav milik HomeShell.
//
// Email tersimpan terenkripsi di database; di sini didekripsi hanya
// untuk ditampilkan dan tidak pernah ditulis balik sebagai teks biasa.
// Switch "Masuk dengan sidik jari" (K3) ada di bagian bawah.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/sync_service.dart';
import '../../theme.dart';
import '../../widgets/coin_rings.dart';
import '../../widgets/soft_card.dart';
import '../crop/crop_screen.dart';

class ProfileScreen extends StatefulWidget {
  // Dipanggil setelah foto berhasil diganti, supaya HomeShell bisa
  // memperbarui ikon Profil di bottom nav.
  final ValueChanged<String?>? onPhotoChanged;
  // Dipanggil setelah nama tampilan diganti, supaya sapaan di Beranda ikut.
  final ValueChanged<String>? onNameChanged;
  const ProfileScreen({super.key, this.onPhotoChanged, this.onNameChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _biometricService = BiometricService();
  final _picker = ImagePicker();

  User? _user;
  String _email = '';
  bool _loading = true;
  bool _savingPhoto = false;
  bool _biometricAvailable = false; // HP punya sensor + sidik jari terdaftar
  bool _biometricBusy = false; // sedang memindai/menyimpan pengaturan
  int _pending = 0; // koin dan blok yang belum diunggah (kartu Sinkronisasi)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _authService.currentUser();
      final email =
          user == null ? '' : await _authService.decryptedEmail(user);
      final bioAvailable = await _biometricService.isAvailable();
      final pending = user == null ? 0 : await SyncService().pendingCount(user);
      if (!mounted) return;
      setState(() {
        _user = user;
        _email = email;
        _pending = pending;
        _biometricAvailable = bioAvailable;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Gagal memuat profil, coba lagi.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Menyalakan harus lolos pemindaian sidik jari dulu (di dalam
  // BiometricService.enable); mematikan langsung. Switch baru berubah
  // setelah hasilnya pasti, supaya tampilannya tidak menipu.
  Future<void> _toggleBiometric(bool value) async {
    final user = _user;
    if (user == null) return;

    setState(() => _biometricBusy = true);
    try {
      var ok = true;
      if (value) {
        ok = await _biometricService.enable(user);
      } else {
        await _biometricService.disable(user);
      }
      if (!mounted) return;
      setState(() {
        if (ok) _user = user.copyWith(biometricEnabled: value);
        _biometricBusy = false;
      });
      if (!ok) {
        _showMessage('Pemindaian gagal. Login sidik jari tidak diaktifkan.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricBusy = false);
      _showMessage('Gagal mengubah pengaturan, coba lagi.');
    }
  }

  Future<void> _changePhoto() async {
    final user = _user;
    if (user == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      // Diperkecil di sumbernya, sama seperti foto koin: foto asli HP
      // berukuran beberapa MB, padahal avatar tidak butuh sebesar itu.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final original = await picked.readAsBytes();
      if (!mounted) return;

      // Pengguna mengatur area foto dulu (kotak 1:1 karena avatar bulat);
      // batal = foto profil tidak berubah.
      final bytes = await CropScreen.open(
        context,
        original,
        aspectRatio: 1.0,
        circleUi: true,
      );
      if (bytes == null || !mounted) return;

      setState(() => _savingPhoto = true);
      final updated = await _authService.updateProfilePhoto(user, bytes);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _savingPhoto = false;
      });
      widget.onPhotoChanged?.call(updated.photoPath);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingPhoto = false);
      _showMessage('Foto tidak bisa disimpan, coba lagi.');
    }
  }

  // Dialog ganti nama tampilan (1-30 karakter, bebas). Disimpan di HP dan
  // di Supabase; tanpa internet ditolak dengan pesan ramah.
  Future<void> _editName() async {
    final user = _user;
    if (user == null) return;

    // Isi dialog adalah widget sendiri yang memegang controller-nya: controller
    // baru dibuang setelah dialog benar-benar hilang dari layar. Sebelumnya
    // controller dibuang tepat setelah dialog ditutup, saat animasi keluar
    // masih berjalan, sehingga layar menjadi merah.
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: user.username),
    );
    if (newName == null || newName.trim() == user.username) return;

    try {
      final updated = await _authService.updateDisplayName(user, newName);
      if (!mounted) return;
      setState(() => _user = updated);
      widget.onNameChanged?.call(updated.username);
    } catch (e) {
      if (!mounted) return;
      // Pesan dari AuthService/AccountRemote sudah ramah.
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Foto bulat dengan cincin emas di atas kepala bergradasi. Tombol kamera
  // emas di pojok menandakan foto bisa diganti.
  Widget _buildAvatar(User user) {
    const radius = 58.0;
    final path = user.photoPath;

    // onBackgroundImageError (di bawah) menelan error bila file foto
    // hilang, jadi layar tidak crash; avatar tampil sebagai lingkaran polos.
    final ImageProvider? image = path == null ? null : FileImage(File(path));
    final avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.creamBottom,
        backgroundImage: image,
        onBackgroundImageError: image == null ? null : (_, _) {},
        child: image == null
            ? const Icon(Icons.person, size: 72, color: AppColors.heroLight)
            : null,
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(onTap: _changePhoto, child: avatar),
        if (_savingPhoto)
          const SizedBox(
            width: radius * 2 + 6,
            height: radius * 2 + 6,
            child: CircularProgressIndicator(color: Colors.white),
          ),
        Positioned(
          right: 2,
          bottom: 4,
          child: Material(
            color: AppColors.gold,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.creamTop, width: 2),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _changePhoto,
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 20,
                  color: AppColors.heroDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Kepala Profil: gradasi cokelat selebar layar sampai ke tepi atas (di bawah
  // bilah status), berisi label PROFIL, foto, nama, dan email. Kartu pertama
  // sedikit menimpa tepi bawahnya (lihat build).
  Widget _buildHeader(User user) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(gradient: AppGradients.brown),
      child: Stack(
        children: [
          const Positioned(top: -90, right: -70, child: CoinRings()),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 18, 20, 64),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Text(
                    'PROFIL',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      color: AppColors.creamTop.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildAvatar(user),
                  const SizedBox(height: 16),
                  Text(
                    user.username,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(
                      size: 36,
                      weight: FontWeight.w700,
                      color: AppColors.creamTop,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Label kecil huruf kapital dan nilainya, dipakai kartu Nama dan Email.
  Widget _labelValue(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppColors.fieldLabel,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }

  // Judul dan keterangan dengan ikon di kiri, untuk kartu sidik jari dan
  // Sinkronisasi.
  Widget _iconTitle(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: AppColors.bronze, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final user = _user;
    if (user == null) {
      return const Center(child: Text('Profil tidak ditemukan.'));
    }

    final bioSubtitle = !_biometricAvailable
        ? 'Tidak tersedia: HP belum punya sidik jari terdaftar.'
        : (user.biometricEnabled ? 'Aktif' : 'Nonaktif');

    const cardPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

    // Kepala bergradasi ada di luar daftar kartu; daftar kartu digeser ke atas
    // sebesar tinggi tambahan di dasar kepala (64 - 36) supaya kartu pertama
    // menimpa tepi bawah kepala.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(user),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SoftCard(
                    radius: 28,
                    padding: cardPadding,
                    onTap: _editName,
                    child: Row(
                      children: [
                        _labelValue('Nama tampilan', user.username),
                        const Text(
                          'Ubah',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.bronze,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    radius: 28,
                    padding: cardPadding,
                    child: Row(
                      children: [
                        _labelValue('Email', _email),
                        Text(
                          'tidak bisa diubah',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.ink.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    radius: 28,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _iconTitle(
                          Icons.fingerprint,
                          'Masuk dengan sidik jari',
                          bioSubtitle,
                        ),
                        Switch(
                          value: user.biometricEnabled,
                          // null = switch nonaktif saat tidak tersedia/sibuk.
                          onChanged: (_biometricAvailable && !_biometricBusy)
                              ? _toggleBiometric
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    radius: 28,
                    padding: cardPadding,
                    child: Row(
                      children: [
                        _iconTitle(
                          Icons.sync,
                          'Sinkronisasi',
                          _pending == 0
                              ? 'Semua sudah tersinkron'
                              : '$_pending belum diunggah',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Dialog ganti nama tampilan. Menjadi StatefulWidget supaya
// TextEditingController dibuat dan dibuang bersama dialognya.
class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti nama tampilan'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: AuthService.maxNameLength,
        decoration: const InputDecoration(labelText: 'Nama tampilan'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
