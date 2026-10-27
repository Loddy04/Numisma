// widgets/world_clock_card.dart
// Kartu jam dunia: satu jam yang berdetak tiap detik, dengan zona waktu yang
// dipilih sendiri oleh pengguna (WIB, WITA, WIT, London). Dipakai di tab Acara
// (Jelajah), jadi ditulis sekali di sini. Tampilan: kartu hero bergradasi
// dengan jam serif besar, dan pilihan zona berbentuk kapsul di bawahnya.
// Timer-nya milik kartu ini saja, sehingga layar yang memakainya tidak ikut
// dibangun ulang tiap detik.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/time_util.dart';
import '../theme.dart';
import 'hero_card.dart';
import 'zone_picker.dart';

class WorldClockCard extends StatefulWidget {
  const WorldClockCard({super.key});

  @override
  State<WorldClockCard> createState() => _WorldClockCardState();
}

class _WorldClockCardState extends State<WorldClockCard> {
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();
  String _zone = zoneWib;

  @override
  void initState() {
    super.initState();
    // Satu timer cukup: setiap detik hanya memperbarui "sekarang", lalu
    // jam menghitung ulang dari nilai itu.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    // Wajib dibatalkan, kalau tidak timer terus jalan setelah kartu ditutup.
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final option = zoneOptions.firstWhere(
      (z) => z.name == _zone,
      orElse: () => zoneOptions.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCard(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${option.label} · ${option.city}'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: Color(0xFFE6CFA3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatClock(_nowUtc, _zone),
                style: AppText.serif(
                  size: 54,
                  weight: FontWeight.w700,
                  color: AppColors.creamTop,
                ),
              ),
              const SizedBox(height: 2),
              // Tanggal ikut tampil: dekat tengah malam, zona berbeda bisa
              // berada di hari yang berbeda.
              Text(
                '${formatZoneDate(_nowUtc, _zone)} · '
                '${zoneAbbreviation(_nowUtc, _zone)}',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ZonePicker(
          selected: _zone,
          onSelected: (z) => setState(() => _zone = z),
        ),
      ],
    );
  }
}
