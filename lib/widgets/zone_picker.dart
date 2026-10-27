// widgets/zone_picker.dart
// Deretan pilihan zona waktu (WIB, WITA, WIT, London) berbentuk kapsul, dipakai
// oleh jam utama, kartu acara, dan layar detail acara supaya semuanya
// berpilihan sama. Yang terpilih bergradasi cokelat.
// Empat zona ini sesuai slide dosen. London = Europe/London (satu-satunya zona
// London di database zona waktu; GMT di musim dingin, BST di musim panas).
// UTC tidak lagi jadi pilihan di layar, tetapi `zoneUtc` tetap ada di
// time_util.dart (dipakai tes). Menambah zona cukup menambah satu baris di
// `zoneOptions`.

import 'package:flutter/material.dart';

import '../core/time_util.dart';
import '../theme.dart';

class ZoneOption {
  final String label; // yang dilihat pengguna
  final String name; // nama zona IANA untuk paket timezone
  final String city; // kota acuan, tampil di kartu jam
  const ZoneOption(this.label, this.name, this.city);
}

const zoneOptions = [
  ZoneOption('WIB', zoneWib, 'Jakarta'),
  ZoneOption('WITA', zoneWita, 'Makassar'),
  ZoneOption('WIT', zoneWit, 'Jayapura'),
  ZoneOption('London', zoneLondon, 'London'),
];

class ZonePicker extends StatelessWidget {
  final String selected; // nama zona IANA yang aktif
  final ValueChanged<String> onSelected;

  const ZonePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final z in zoneOptions) _chip(z, z.name == selected),
      ],
    );
  }

  Widget _chip(ZoneOption z, bool active) {
    final radius = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: active ? AppGradients.brown : null,
        color: active ? null : AppColors.card,
        border: Border.all(
          color: active ? Colors.transparent : AppColors.cardBorder,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: () => onSelected(z.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              z.label,
              style: TextStyle(
                fontSize: 15,
                color: active ? Colors.white : AppColors.bronze,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
