// widgets/zone_picker.dart
// Deretan pilihan zona waktu (WIB, WITA, WIT, UTC), dipakai oleh jam utama,
// kartu acara, dan layar detail acara supaya semuanya berpilihan sama.
// Menambah zona (mis. London) cukup menambah satu baris di `zoneOptions`.

import 'package:flutter/material.dart';

import '../core/time_util.dart';
import '../theme.dart';

class ZoneOption {
  final String label; // yang dilihat pengguna
  final String name; // nama zona IANA untuk paket timezone
  const ZoneOption(this.label, this.name);
}

const zoneOptions = [
  ZoneOption('WIB', zoneWib),
  ZoneOption('WITA', zoneWita),
  ZoneOption('WIT', zoneWit),
  ZoneOption('UTC', zoneUtc),
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
      children: [
        for (final z in zoneOptions)
          ChoiceChip(
            label: Text(z.label),
            selected: z.name == selected,
            visualDensity: VisualDensity.compact,
            selectedColor: AppColors.gold.withValues(alpha: 0.5),
            onSelected: (_) => onSelected(z.name),
          ),
      ],
    );
  }
}
