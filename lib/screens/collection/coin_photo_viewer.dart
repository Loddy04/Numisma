// screens/collection/coin_photo_viewer.dart
// Foto koin layar penuh, seperti membuka foto profil di WhatsApp (K8,
// NUMISMA_GUIDE 7.8). Foto tampil utuh di atas latar cokelat tua dengan
// efek tilt gyroscope yang lebih dinamis daripada di detail, karena ruangnya
// longgar (tidak dipotong bingkai). Tanpa zoom cubit: zoom dengan jari akan
// bertabrakan dengan gerakan tilt.
//
// Keluar: ketuk di mana saja, tombol tutup, atau tombol Kembali.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/tilt_photo.dart';

class CoinPhotoViewer extends StatelessWidget {
  final String photoPath;
  // Tag Hero yang sama dengan foto di detail, supaya foto "membesar" dari
  // posisinya semula saat dibuka.
  final String heroTag;

  const CoinPhotoViewer({
    super.key,
    required this.photoPath,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textDark, // cokelat tua tema
      body: Stack(
        children: [
          // Ketuk di mana saja untuk menutup.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox.expand(
                  child: TiltPhoto(
                    // Lebih dinamis daripada di detail: foto utuh, tidak
                    // dipotong dan tidak diperbesar, geser dan miring lebih besar.
                    clip: false,
                    scale: 1.0,
                    maxShift: 32,
                    cardTilt: 0.55,
                    child: Hero(
                      tag: heroTag,
                      child: Image.file(
                        File(photoPath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Miringkan HP · ketuk untuk menutup',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
