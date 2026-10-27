// screens/scan/scan_screen.dart
// Scan koin dengan AI (K9a, NUMISMA_GUIDE 7.9a). Alur: pilih foto (kamera
// atau galeri) -> atur/potong -> kirim ke AI -> form koin terisi dari
// tebakan AI dan bisa diedit -> pengguna menyimpan. Layar ini tidak memanggil
// HTTP langsung, semuanya lewat AiService (aturan Bagian 4.1).
//
// Bila AI gagal (internet, kuota, jawaban tak terbaca) pengguna tidak
// buntu: bisa coba lagi, mengisi manual dengan foto yang sama, atau memakai
// hasil contoh. Pop dengan nilai true bila koin tersimpan.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/soft_card.dart';
import '../collection/coin_form_screen.dart';
import '../crop/crop_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ai = AiService();
  final _auth = AuthService();
  final _picker = ImagePicker();

  Uint8List? _photo; // foto yang sudah diatur, belum tentu berhasil dianalisis
  String _source = 'none'; // camera / gallery
  bool _busy = false; // AI sedang membaca
  String? _error; // pesan ramah bila AI gagal

  // --- Foto ----------------------------------------------------------

  Future<void> _pick(ImageSource source) async {
    try {
      // Diperkecil di sumbernya (Bagian 3), sama seperti form koin.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final original = await picked.readAsBytes();
      if (!mounted) return;

      final bytes = await CropScreen.open(
        context,
        original,
        allowRatioChoice: true,
      );
      if (bytes == null || !mounted) return;

      setState(() {
        _photo = bytes;
        _source = source == ImageSource.camera ? 'camera' : 'gallery';
        _error = null;
      });
      await _analyze();
    } catch (_) {
      _snack('Foto tidak bisa diambil, coba lagi.');
    }
  }

  // --- AI ------------------------------------------------------------

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final guess = await _ai.identifyCoin(photo);
      if (!mounted) return;
      setState(() => _busy = false);
      await _openForm(guess);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      // Mis. key AI belum diisi di .env: bukan kesalahan pengguna.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Fitur AI belum siap. Kamu tetap bisa mengisi manual.';
      });
    }
  }

  // Membuka form dengan foto ini. `guess` null = isi manual.
  Future<void> _openForm(CoinGuess? guess) async {
    final user = await _auth.currentUser();
    if (user == null || !mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CoinFormScreen(
          userId: user.id!,
          guess: guess,
          initialPhoto: _photo,
          initialPhotoSource: _source,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      Navigator.of(context).pop(true);
    } else {
      // Kembali dari form tanpa menyimpan: mulai dari awal.
      setState(() {
        _photo = null;
        _error = null;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Tampilan ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Koin')),
      body: _photo == null ? _buildPicker() : _buildProgress(),
    );
  }

  // Layar pilih foto: lingkaran bergradasi bergaya koin dengan ikon pemindai,
  // penjelasan singkat, dua tombol (kamera bergradasi, galeri bergaris), dan
  // catatan privasi.
  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.brown,
                boxShadow: AppShadows.strong,
              ),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.center_focus_strong_outlined,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Scan koin atau uang kertas',
            textAlign: TextAlign.center,
            style: AppText.serif(size: 26, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Foto koin atau uang kertasmu, lalu Numisma membaca ciri-cirinya. '
            'Hasilnya hanya perkiraan dan bisa kamu koreksi sebelum disimpan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.ink.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          GradientButton(
            label: 'Ambil dengan kamera',
            onPressed: () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pilih dari galeri'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 14,
                color: AppColors.ink.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Foto dikirim ke layanan AI (OpenAI) untuk dianalisis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Layar proses: foto dalam kartu, lalu keadaan memuat atau galat dengan
  // pilihan lanjutan.
  Widget _buildProgress() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        SoftCard(
          padding: const EdgeInsets.all(8),
          radius: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 260,
              child: Image.memory(_photo!, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_busy) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 14),
          Text(
            'Numisma sedang membaca fotomu…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink.withValues(alpha: 0.65)),
          ),
        ],
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 20,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(label: 'Coba lagi', onPressed: _analyze),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _openForm(null),
            child: const Text('Isi manual dengan foto ini'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              _photo = null;
              _error = null;
            }),
            child: const Text('Pilih foto lain'),
          ),
        ],
      ],
    );
  }
}
