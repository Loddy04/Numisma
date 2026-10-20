// screens/collection/collection_filter_sheet.dart
// Panel filter dan urutan untuk daftar koleksi (K11, NUMISMA_GUIDE
// Bagian 7.11): jenis, kondisi, rentang tahun, dan urutan.
// Dipisah dari collection_screen.dart supaya file layar utamanya tetap
// pendek. Panel hanya mengumpulkan pilihan; yang menjalankan pencarian
// tetap CoinRepo.list().

import 'package:flutter/material.dart';

// Kumpulan pilihan filter. Nilai null berarti "semua / tidak dibatasi".
class CoinFilters {
  final String? type; // 'coin' atau 'banknote'
  final String? condition; // UNC, XF, VF, F, G
  final int? yearFrom;
  final int? yearTo;
  final String sort; // 'newest', 'year', 'denomination' (sesuai CoinRepo)

  const CoinFilters({
    this.type,
    this.condition,
    this.yearFrom,
    this.yearTo,
    this.sort = 'newest',
  });

  // Dipakai untuk menampilkan titik penanda di ikon filter.
  bool get isActive => isFiltering || sort != 'newest';

  // Hanya filter pembatas (tanpa urutan): dipakai untuk memilih pesan
  // kosong yang tepat ("tidak ada yang cocok" vs "koleksi masih kosong").
  bool get isFiltering =>
      type != null || condition != null || yearFrom != null || yearTo != null;
}

class CollectionFilterSheet extends StatefulWidget {
  final CoinFilters initial;
  const CollectionFilterSheet({super.key, required this.initial});

  @override
  State<CollectionFilterSheet> createState() => _CollectionFilterSheetState();
}

class _CollectionFilterSheetState extends State<CollectionFilterSheet> {
  static const _conditions = ['UNC', 'XF', 'VF', 'F', 'G'];

  late String? _type = widget.initial.type;
  late String? _condition = widget.initial.condition;
  late String _sort = widget.initial.sort;
  late final _yearFrom =
      TextEditingController(text: widget.initial.yearFrom?.toString() ?? '');
  late final _yearTo =
      TextEditingController(text: widget.initial.yearTo?.toString() ?? '');

  @override
  void dispose() {
    _yearFrom.dispose();
    _yearTo.dispose();
    super.dispose();
  }

  // Satu baris pilihan berupa chip. `value` null = opsi "Semua".
  Widget _chips<T>({
    required String title,
    required List<(T?, String)> options,
    required T? selected,
    required ValueChanged<T?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: selected == value,
                onSelected: (_) => setState(() => onSelected(value)),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _apply() {
    var from = int.tryParse(_yearFrom.text.trim());
    var to = int.tryParse(_yearTo.text.trim());
    // Kalau pengguna terbalik mengisi (dari > sampai), ditukar saja
    // daripada menampilkan hasil kosong yang membingungkan.
    if (from != null && to != null && from > to) {
      final tmp = from;
      from = to;
      to = tmp;
    }
    Navigator.of(context).pop(
      CoinFilters(
        type: _type,
        condition: _condition,
        yearFrom: from,
        yearTo: to,
        sort: _sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom = tinggi keyboard, supaya isian tahun tidak tertutup.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chips<String>(
              title: 'Jenis',
              options: const [
                (null, 'Semua'),
                ('coin', 'Koin'),
                ('banknote', 'Uang kertas'),
              ],
              selected: _type,
              onSelected: (v) => _type = v,
            ),
            _chips<String>(
              title: 'Kondisi',
              options: [
                (null, 'Semua'),
                for (final c in _conditions) (c, c),
              ],
              selected: _condition,
              onSelected: (v) => _condition = v,
            ),
            const Text('Rentang tahun',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearFrom,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dari'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _yearTo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sampai'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _chips<String>(
              title: 'Urutkan',
              options: const [
                ('newest', 'Terbaru'),
                ('year', 'Tahun'),
                ('denomination', 'Nominal'),
              ],
              selected: _sort,
              onSelected: (v) => _sort = v ?? 'newest',
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    // Reset = kembali ke pilihan bawaan (tanpa filter).
                    onPressed: () =>
                        Navigator.of(context).pop(const CoinFilters()),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
