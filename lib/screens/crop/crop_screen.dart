// screens/crop/crop_screen.dart
// Layar atur/potong foto yang dipakai bersama oleh form koin dan Profil.
// Pengguna menggeser dan men-zoom gambar serta menarik sudut kotak untuk
// menentukan area yang dipakai, SEBELUM foto disimpan -- bukan langsung
// ditempel lalu disesuaikan otomatis oleh sistem.
//
// Memakai paket crop_your_image: layar potongnya digambar di dalam
// aplikasi Flutter sendiri (bukan membuka aktivitas Android terpisah),
// jadi tidak menambah risiko aplikasi dimatikan sistem saat berpindah
// layar seperti pada kamera/galeri.
//
// Hasilnya (Uint8List) dikembalikan lewat Navigator.pop; null berarti
// pengguna membatalkan, dan pemanggil tidak boleh memakai foto itu.

import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double? aspectRatio; // rasio awal; null = bebas
  final bool circleUi; // true = kotak potong 1:1 berpenampilan bulat
  final bool allowRatioChoice; // true = tampilkan pilihan rasio

  const CropScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
    this.circleUi = false,
    this.allowRatioChoice = false,
  });

  // Cara memakai dari layar lain: await CropScreen.open(...), lalu
  // periksa hasilnya null atau tidak.
  static Future<Uint8List?> open(
    BuildContext context,
    Uint8List imageBytes, {
    double? aspectRatio,
    bool circleUi = false,
    bool allowRatioChoice = false,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => CropScreen(
          imageBytes: imageBytes,
          aspectRatio: aspectRatio,
          circleUi: circleUi,
          allowRatioChoice: allowRatioChoice,
        ),
      ),
    );
  }

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  // Pilihan rasio untuk foto koin. Uang kertas berbentuk persegi
  // panjang, jadi "Bebas" dijadikan pilihan pertama.
  static const _ratios = <(String, double?)>[
    ('Bebas', null),
    ('1:1', 1.0),
    ('4:3', 4 / 3),
    ('3:4', 3 / 4),
  ];

  final _controller = CropController();
  late double? _ratio = widget.aspectRatio;
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto gagal dipotong, coba lagi.')),
        );
    }
  }

  void _done() {
    setState(() => _cropping = true);
    // crop() hanya memulai proses; hasilnya datang lewat onCropped.
    _controller.crop();
  }

  void _selectRatio(double? ratio) {
    setState(() => _ratio = ratio);
    _controller.aspectRatio = ratio;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Atur Foto'),
        actions: [
          TextButton(
            onPressed: _cropping ? null : _done,
            child: const Text(
              'Selesai',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              onCropped: _onCropped,
              aspectRatio: widget.aspectRatio,
              withCircleUi: widget.circleUi,
              // interactive: gambar bisa digeser dan di-zoom, sementara
              // sudut kotak tetap bisa ditarik untuk mengubah ukuran.
              interactive: true,
              baseColor: Colors.black,
              maskColor: Colors.black54,
              progressIndicator: const CircularProgressIndicator(),
            ),
          ),
          Container(
            color: AppColors.surface,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.allowRatioChoice) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (label, ratio) in _ratios)
                          ChoiceChip(
                            label: Text(label),
                            selected: _ratio == ratio,
                            onSelected: (_) => _selectRatio(ratio),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    'Cubit untuk zoom, geser gambar untuk memindahkan, '
                    'tarik sudut untuk mengubah area.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
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
