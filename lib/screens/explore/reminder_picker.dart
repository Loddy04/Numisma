// screens/explore/reminder_picker.dart
// Pemilih "berapa lama sebelum acara" untuk pengingat (NUMISMA_GUIDE 0.5,
// Bagian 7.12). Pengguna memilih SELISIH, bukan jam alarm: jam pengingat
// dihitung otomatis sebagai waktu_mulai - selisih. Pilihan cepat tersedia,
// dan "Atur sendiri" untuk angka + satuan (menit, jam, hari).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format_util.dart';

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Ingatkan berapa lama sebelum acara?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final p in _presets)
            ListTile(
              title: Text('${formatDuration(p)} sebelum'),
              onTap: () => Navigator.of(ctx).pop(p),
            ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Atur sendiri…'),
            onTap: () async {
              final custom = await showDialog<Duration>(
                context: ctx,
                builder: (_) => const _CustomOffsetDialog(),
              );
              if (custom != null && ctx.mounted) {
                Navigator.of(ctx).pop(custom);
              }
            },
          ),
        ],
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
