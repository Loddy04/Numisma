// screens/explore/explore_screen.dart
// Layar Jelajah (K5, LBS, NUMISMA_GUIDE 7.5): dua tab, Peta (posisi GPS,
// acara bertitik, jarak, terdekat) dan Acara (daftar, tambah, pengingat).

import 'package:flutter/material.dart';

import 'events_tab.dart';
import 'map_tab.dart';

class ExploreScreen extends StatelessWidget {
  // Tab yang terbuka lebih dulu: 0 = Peta, 1 = Acara (dari Daftar Acara di
  // Beranda).
  final int initialTab;
  const ExploreScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jelajah'),
          // Warna tab diatur tema global (tabBarTheme di theme.dart).
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Peta'),
              Tab(text: 'Acara'),
            ],
          ),
        ),
        body: const TabBarView(children: [MapTab(), EventsTab()]),
      ),
    );
  }
}
