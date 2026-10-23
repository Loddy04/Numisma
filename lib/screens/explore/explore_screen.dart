// screens/explore/explore_screen.dart
// Layar Jelajah (K5, LBS, NUMISMA_GUIDE 7.5): dua tab, Peta (posisi GPS,
// acara bertitik, jarak, terdekat) dan Acara (daftar, tambah, pengingat).

import 'package:flutter/material.dart';

import 'events_tab.dart';
import 'map_tab.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jelajah'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
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
