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

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.document_scanner, size: 72, color: AppColors.bronze),
          const SizedBox(height: 16),
          const Text(
            'Foto koin atau uang kertas, lalu AI membaca ciri-cirinya. '
            'Hasilnya hanya estimasi dan bisa kamu koreksi sebelum disimpan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _pick(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Ambil dengan kamera'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Pilih dari galeri'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Foto dikirim ke layanan AI (OpenAI) untuk dianalisis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            child: Image.memory(_photo!, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 20),
        if (_busy) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          const Text('AI sedang membaca foto...', textAlign: TextAlign.center),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _analyze, child: const Text('Coba lagi')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _openForm(null),
            child: const Text('Isi manual dengan foto ini'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _openForm(CoinGuess.sample()),
            child: const Text('Gunakan hasil contoh'),
          ),
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
