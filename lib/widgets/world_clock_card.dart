// widgets/world_clock_card.dart
// Kartu jam dunia: satu jam yang berdetak tiap detik, dengan zona waktu yang
// dipilih sendiri oleh pengguna (WIB, WITA, WIT, London). Dipakai di tab Jam
// Dunia (Konversi) dan di tab Acara (Jelajah), jadi ditulis sekali di sini.
// Timer-nya milik kartu ini saja, sehingga layar yang memakainya tidak ikut
// dibangun ulang tiap detik.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/time_util.dart';
import '../theme.dart';
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              formatClock(_nowUtc, _zone),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: AppColors.bronze,
              ),
            ),
            const SizedBox(height: 4),
            // Tanggal ikut tampil: dekat tengah malam, zona berbeda bisa
            // berada di hari yang berbeda.
            Text(
              '${formatZoneDate(_nowUtc, _zone)} · '
              '${zoneAbbreviation(_nowUtc, _zone)}',
            ),
            const SizedBox(height: 12),
            ZonePicker(
              selected: _zone,
              onSelected: (z) => setState(() => _zone = z),
            ),
          ],
        ),
      ),
    );
  }
}
