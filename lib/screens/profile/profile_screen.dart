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
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme.dart';
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
      if (!mounted) return;
      setState(() {
        _user = user;
        _email = email;
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

  // "2026-10-19T..." (UTC) -> "19/10/2026" dalam waktu lokal HP.
  String _formatDate(String iso) {
    final d = DateTime.parse(iso).toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  // Foto bulat dengan cincin emas di atas kepala bergradasi. Ikon kamera kecil
  // di pojok menandakan foto bisa diganti.
  Widget _buildAvatar(User user) {
    const radius = 52.0;
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
            ? const Icon(Icons.person, size: 64, color: AppColors.bronze)
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
          right: 0,
          bottom: 2,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _changePhoto,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: AppColors.bronze,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Kepala Profil: kartu bergradasi cokelat berisi foto, nama, dan email.
  Widget _buildHeader(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: AppGradients.brown,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.strong,
      ),
      child: Column(
        children: [
          _buildAvatar(user),
          const SizedBox(height: 14),
          Text(
            user.username,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(
              size: 28,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ketuk foto untuk mengganti',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // Satu baris info dalam kartu: ikon dalam lingkaran lembut, label kecil,
  // dan nilai. `onTap` dan `trailing` opsional (mis. ubah nama).
  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tileActive,
            ),
            child: Icon(icon, color: AppColors.bronze, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildHeader(user),
        const SizedBox(height: 20),
        _infoRow(
          Icons.person_outline,
          'Nama tampilan',
          user.username,
          onTap: _editName,
          trailing: const Icon(Icons.edit_outlined, size: 20),
        ),
        const SizedBox(height: 12),
        _infoRow(
          Icons.event_outlined,
          'Bergabung',
          _formatDate(user.createdAt),
        ),
        const SizedBox(height: 12),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tileActive,
              ),
              child: const Icon(Icons.fingerprint, color: AppColors.bronze),
            ),
            title: const Text(
              'Masuk dengan sidik jari',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _biometricAvailable
                  ? 'Login tanpa mengetik password.'
                  : 'Tidak tersedia: HP belum punya sidik jari terdaftar.',
            ),
            value: user.biometricEnabled,
            // null = switch nonaktif (abu-abu) saat tidak tersedia/sibuk.
            onChanged: (_biometricAvailable && !_biometricBusy)
                ? _toggleBiometric
                : null,
          ),
        ),
      ],
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
