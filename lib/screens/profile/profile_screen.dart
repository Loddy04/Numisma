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

    final controller = TextEditingController(text: user.username);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti nama tampilan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: AuthService.maxNameLength,
          decoration: const InputDecoration(labelText: 'Nama tampilan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
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

  Widget _buildAvatar(User user) {
    const radius = 64.0;
    final path = user.photoPath;

    // onBackgroundImageError (di bawah) menelan error bila file foto
    // hilang, jadi layar tidak crash; avatar tampil sebagai lingkaran polos.
    final ImageProvider? image = path == null ? null : FileImage(File(path));
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold.withValues(alpha: 0.4),
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, _) {},
      child: image == null
          ? const Icon(Icons.person, size: 72, color: AppColors.bronze)
          : null,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(onTap: _changePhoto, child: avatar),
        if (_savingPhoto)
          const SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: CircularProgressIndicator(),
          ),
        // Ikon kamera kecil sebagai petunjuk bahwa foto bisa diganti.
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: AppColors.bronze,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _changePhoto,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.camera_alt, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.bronze),
        title: Text(label, style: const TextStyle(fontSize: 12)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16)),
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Center(child: _buildAvatar(user)),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Tekan foto untuk mengganti',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: AppColors.bronze),
            title: const Text('Nama tampilan', style: TextStyle(fontSize: 12)),
            subtitle: Text(
              user.username,
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: _editName,
          ),
        ),
        _infoTile(Icons.email, 'Email', _email),
        _infoTile(Icons.event, 'Bergabung', _formatDate(user.createdAt)),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.fingerprint, color: AppColors.bronze),
            title: const Text('Masuk dengan sidik jari'),
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
