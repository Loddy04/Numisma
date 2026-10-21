// widgets/currency_picker.dart
// Isian "pilih mata uang" untuk form koin. Pengguna tidak mengetik
// bebas: ia memilih dari daftar (bisa dicari lewat kode, nama, atau
// negara), jadi kode yang tersimpan selalu valid untuk konversi kurs.
// Mata uang di luar daftar tetap bisa lewat opsi "Lainnya…" (ketik
// kode 3 huruf), mis. untuk kode yang dikembalikan AI di Hari 4.
//
// Dibuat sebagai FormField supaya ikut validasi Form seperti isian lain.

import 'package:flutter/material.dart';

import '../services/currency_service.dart';

class CurrencyPickerField extends FormField<String> {
  CurrencyPickerField({
    super.key,
    required String label,
    String? initialCode,
    bool required = false,
    ValueChanged<String?>? onChanged,
  }) : super(
         initialValue: initialCode,
         validator: (code) =>
             (required && code == null) ? 'Mata uang wajib dipilih.' : null,
         builder: (state) {
           Future<void> open() async {
             final result = await showModalBottomSheet<String>(
               context: state.context,
               isScrollControlled: true,
               builder: (_) =>
                   _CurrencySheet(allowClear: !required && state.value != null),
             );
             if (result == null) return; // sheet ditutup tanpa memilih
             // String kosong = pengguna memilih "Kosongkan".
             final code = result.isEmpty ? null : result;
             state.didChange(code);
             onChanged?.call(code);
           }

           return InkWell(
             borderRadius: BorderRadius.circular(12),
             onTap: open,
             child: InputDecorator(
               decoration: InputDecoration(
                 labelText: label,
                 errorText: state.errorText,
                 suffixIcon: const Icon(Icons.arrow_drop_down),
               ),
               // FutureBuilder: mengubah kode tersimpan ("IDR") menjadi
               // nama yang enak dibaca ("Rupiah (IDR)"). Sebelum daftar
               // termuat, atau untuk kode di luar daftar, tampil kodenya.
               child: FutureBuilder<List<CurrencyOption>>(
                 future: CurrencyService.load(),
                 builder: (context, snap) {
                   final code = state.value;
                   if (code == null) return const Text(' ');
                   final match = snap.data
                       ?.where((c) => c.code == code)
                       .firstOrNull;
                   return Text(match?.label ?? code);
                 },
               ),
             ),
           );
         },
       );
}

class _CurrencySheet extends StatefulWidget {
  final bool allowClear;
  const _CurrencySheet({required this.allowClear});

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  String _query = '';

  Future<void> _askCustomCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CustomCodeDialog(),
    );
    if (code != null && mounted) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = tinggi keyboard, supaya daftar tidak tertutup.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari nama, negara, atau kode',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CurrencyOption>>(
                future: CurrencyService.load(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final results = CurrencyService.search(snap.data!, _query);
                  return ListView(
                    children: [
                      if (widget.allowClear)
                        ListTile(
                          leading: const Icon(Icons.clear),
                          title: const Text('Kosongkan'),
                          onTap: () => Navigator.of(context).pop(''),
                        ),
                      for (final c in results)
                        ListTile(
                          title: Text(c.label),
                          subtitle: Text(c.country),
                          onTap: () => Navigator.of(context).pop(c.code),
                        ),
                      if (results.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Tidak ditemukan di daftar.'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Lainnya…'),
                        subtitle: const Text('Ketik kode 3 huruf sendiri'),
                        onTap: _askCustomCode,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog kecil untuk mengetik kode di luar daftar. Divalidasi 3 huruf
// supaya tetap berbentuk kode ISO 4217 yang rapi.
class _CustomCodeDialog extends StatefulWidget {
  const _CustomCodeDialog();

  @override
  State<_CustomCodeDialog> createState() => _CustomCodeDialogState();
}

class _CustomCodeDialogState extends State<_CustomCodeDialog> {
  static final _pattern = RegExp(r'^[A-Za-z]{3}$');
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (!_pattern.hasMatch(text)) {
      setState(() => _error = 'Gunakan 3 huruf, mis. THB.');
      return;
    }
    Navigator.of(context).pop(text.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kode mata uang'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 3,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: 'IDR', errorText: _error),
        onSubmitted: (_) => _submit(),
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
