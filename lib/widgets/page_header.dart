// widgets/page_header.dart
// Kepala halaman untuk layar yang tidak memakai AppBar: tombol kembali bulat,
// judul serif besar, dan aksi teks opsional di kanan (mis. "Ubah"). Dipakai
// Permainan, Jelajah, Konversi, dan layar lain bergaya baru. Warna dari
// theme.dart.

import 'package:flutter/material.dart';

import '../theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing; // aksi di kanan (opsional)
  final VoidCallback? onBack; // null = kembali ke layar sebelumnya

  const PageHeader({super.key, required this.title, this.trailing, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: AppColors.card,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.cardBorder),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.chevron_left, color: AppColors.bronze),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(size: 32, weight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
