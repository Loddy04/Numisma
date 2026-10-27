// screens/explore/reminder_picker.dart
// Pemilih "berapa lama sebelum acara" untuk pengingat (NUMISMA_GUIDE 0.5,
// Bagian 7.12). Pengguna memilih SELISIH, bukan jam alarm: jam pengingat
// dihitung otomatis sebagai waktu_mulai - selisih. Pilihan cepat tersedia,
// dan "Atur sendiri" untuk angka + satuan (menit, jam, hari).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format_util.dart';
import '../../theme.dart';
import '../../widgets/soft_card.dart';

const _presets = [
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(days: 1),
];

// null = pengguna menutup tanpa memilih.
Future<Duration?> pickReminderOffset(BuildContext context) {
  return showModalBottomSheet<Duration>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingatkan berapa lama sebelum acara?',
              style: AppText.serif(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            for (final p in _presets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  onTap: () => Navigator.of(ctx).pop(p),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: AppColors.bronze,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${formatDuration(p)} sebelum',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            SoftCard(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              onTap: () async {
                final custom = await showDialog<Duration>(
                  context: ctx,
                  builder: (_) => const _CustomOffsetDialog(),
                );
                if (custom != null && ctx.mounted) {
                  Navigator.of(ctx).pop(custom);
                }
              },
              child: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: AppColors.bronze),
                  SizedBox(width: 14),
                  Text('Atur sendiri…', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CustomOffsetDialog extends StatefulWidget {
  const _CustomOffsetDialog();

  @override
  State<_CustomOffsetDialog> createState() => _CustomOffsetDialogState();
}

class _CustomOffsetDialogState extends State<_CustomOffsetDialog> {
  // Satuan dan kelipatannya dalam menit.
  static const _units = [('menit', 1), ('jam', 60), ('hari', 1440)];

  final _controller = TextEditingController();
  int _unit = 0;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 1) {
      setState(() => _error = 'Isi angka minimal 1.');
      return;
    }
    Navigator.of(context).pop(Duration(minutes: n * _units[_unit].$2));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atur sendiri'),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Jumlah',
                errorText: _error,
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _unit,
            items: [
              for (var i = 0; i < _units.length; i++)
                DropdownMenuItem(value: i, child: Text(_units[i].$1)),
            ],
            onChanged: (v) => setState(() => _unit = v ?? 0),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
