// widgets/confirm_dialog.dart
// Dialog konfirmasi ya/batal yang dipakai sebelum tindakan yang tidak bisa
// dibatalkan (mis. menghapus acara). Mengembalikan true hanya bila pengguna
// menekan tombol konfirmasi; menutup dialog atau menekan Batal = false.

import 'package:flutter/material.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
