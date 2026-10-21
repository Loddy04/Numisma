// screens/convert/world_clock_tab.dart
// Tab "Jam Dunia" (NUMISMA_GUIDE Bagian 7.7b): satu jam yang berdetak tiap
// detik, dan daftar acara kolektor CONTOH. Zona waktu jam dan zona tiap
// kartu acara dipilih sendiri oleh pengguna (WIB, WITA, WIT, UTC), jadi
// layar tidak penuh menampilkan semua zona sekaligus.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/event_repo.dart';
import '../../theme.dart';

class WorldClockTab extends StatefulWidget {
  const WorldClockTab({super.key});

  @override
  State<WorldClockTab> createState() => _WorldClockTabState();
}

class _WorldClockTabState extends State<WorldClockTab> {
  // Pilihan zona. Menambah zona (mis. London) cukup menambah satu baris di sini.
  static const _zones = [
    _Zone('WIB', zoneWib),
    _Zone('WITA', zoneWita),
    _Zone('WIT', zoneWit),
    _Zone('UTC', zoneUtc),
  ];

  final _events = EventRepo();
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();

  // Zona jam utama, dan zona tiap kartu acara (kunci = id acara). Kartu
  // yang belum pernah dipilih memakai WIB.
  String _clockZone = zoneWib;
  final Map<int, String> _eventZone = {};

  List<Event> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Satu timer cukup: setiap detik hanya memperbarui "sekarang", lalu
    // jam menghitung ulang dari nilai itu.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
    _loadEvents();
  }

  @override
  void dispose() {
    // Wajib dibatalkan, kalau tidak timer terus jalan setelah tab ditutup.
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final list = await _events.list();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat daftar acara.')),
      );
    }
  }

  // Deretan pilihan zona; dipakai oleh jam utama dan tiap kartu acara.
  Widget _zonePicker({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      children: [
        for (final z in _zones)
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _clockCard(),
          const SizedBox(height: 24),
          const Text(
            'Acara kolektor (contoh)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Data contoh untuk demo, bukan acara nyata.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_list.isEmpty)
            const Text('Belum ada acara.')
          else
            for (final e in _list) _eventCard(e),
        ],
      ),
    );
  }

  Widget _clockCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              formatClock(_nowUtc, _clockZone),
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
              '${formatZoneDate(_nowUtc, _clockZone)} · '
              '${zoneAbbreviation(_nowUtc, _clockZone)}',
            ),
            const SizedBox(height: 12),
            _zonePicker(
              selected: _clockZone,
              onSelected: (z) => setState(() => _clockZone = z),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(Event e) {
    final zone = _eventZone[e.id] ?? zoneWib;
    final past = e.startUtc.isBefore(_nowUtc);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: past ? Colors.grey : AppColors.textDark,
              ),
            ),
            if (e.location != null)
              Text(e.location!, style: const TextStyle(fontSize: 12)),
            if (past)
              const Text(
                'Sudah lewat',
                style: TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            const SizedBox(height: 8),
            // Waktu mulai di zona yang dipilih untuk kartu ini saja.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatZoneTime(e.startUtc, zone),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.bronze,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatZoneDate(e.startUtc, zone)} · '
                  '${zoneAbbreviation(e.startUtc, zone)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _zonePicker(
              selected: zone,
              onSelected: (z) => setState(() => _eventZone[e.id] = z),
            ),
          ],
        ),
      ),
    );
  }
}

class _Zone {
  final String label; // yang dilihat pengguna
  final String name; // nama zona IANA untuk paket timezone
  const _Zone(this.label, this.name);
}
