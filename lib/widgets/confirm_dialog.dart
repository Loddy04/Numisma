// widgets/confirm_dialog.dart
// Dialog konfirmasi ya/batal yang dipakai sebelum tindakan yang tidak bisa
// dibatalkan (mis. menghapus acara, keluar akun). Mengembalikan true hanya
// bila pengguna menekan tombol konfirmasi; menutup dialog atau menekan Batal
// = false. Gaya: kartu krem bersudut sangat bulat di atas latar gelap
// cokelat, tombol Batal bergaris dan tombol konfirmasi bergradasi.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'gradient_button.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.dialogBarrier,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        decoration: BoxDecoration(
          gradient: AppGradients.page,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.serif(size: 26, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
