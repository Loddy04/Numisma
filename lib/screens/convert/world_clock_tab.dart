// screens/convert/world_clock_tab.dart
// Tab "Jam Dunia" (NUMISMA_GUIDE Bagian 7.7b): kartu jam dunia (WIB, WITA, WIT,
// London). Acara kolektor, pengingat, dan uji notifikasi ada di menu Jelajah
// (tab Acara), yang juga menampilkan kartu jam yang sama.

import 'package:flutter/material.dart';

import '../../widgets/world_clock_card.dart';

class WorldClockTab extends StatelessWidget {
  const WorldClockTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        WorldClockCard(),
        SizedBox(height: 16),
        Text(
          'Acara kolektor beserta pengingatnya ada di menu Jelajah, tab Acara.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
