// screens/collection/collection_filter_sheet.dart
// Panel filter dan urutan untuk daftar koleksi (K11, NUMISMA_GUIDE
// Bagian 7.11): jenis, kondisi, rentang tahun, dan urutan.
// Dipisah dari collection_screen.dart supaya file layar utamanya tetap
// pendek. Panel hanya mengumpulkan pilihan; yang menjalankan pencarian
// tetap CoinRepo.list().

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/field_label.dart';
import '../../widgets/gradient_button.dart';

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

  // Satu baris pilihan berupa chip bulat. `value` null = opsi "Semua". Chip
  // terpilih berwarna cokelat, lainnya putih bergaris krem.
  Widget _chips<T>({
    required String title,
    required List<(T?, String)> options,
    required T? selected,
    required ValueChanged<T?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in options)
              _chip(
                label: label,
                active: selected == value,
                onTap: () => setState(() => onSelected(value)),
              ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? AppColors.bronze : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? AppColors.bronze : AppColors.cardBorder,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.bronze,
            ),
          ),
        ),
      ),
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter dan urutan',
                style: AppText.serif(size: 24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
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
              const FieldLabel('Rentang tahun'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _yearFrom,
                      keyboardType: TextInputType.number,
                      decoration: appInput(hint: 'Dari'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _yearTo,
                      keyboardType: TextInputType.number,
                      decoration: appInput(hint: 'Sampai'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
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
                    child: GradientButton(
                      label: 'Terapkan',
                      onPressed: _apply,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
