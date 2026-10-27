// screens/explore/explore_screen.dart
// Layar Jelajah (K5, LBS, NUMISMA_GUIDE 7.5): dua tab, Peta (posisi GPS,
// acara bertitik, jarak, terdekat) dan Acara (daftar, tambah, pengingat).
// Peta memenuhi layar, dengan tombol kembali dan tab kapsul melayang di
// atasnya; di tab Acara, kepala itu berlatar krem supaya daftar yang
// digulir tidak tertimpa.

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/pill_tabs.dart';
import 'events_tab.dart';
import 'map_tab.dart';

class ExploreScreen extends StatefulWidget {
  // Tab yang terbuka lebih dulu: 0 = Peta, 1 = Acara (dari Beranda).
  final int initialTab;
  const ExploreScreen({super.key, this.initialTab = 0});

  // Tinggi kepala melayang (tombol kembali + tab), di luar bilah status.
  static const headerHeight = 76.0;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.creamTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: TabBarView(
              controller: _tabs,
              // Peta bisa digeser dengan jari, jadi geser antartab dimatikan.
              physics: const NeverScrollableScrollPhysics(),
              children: [MapTab(tabs: _tabs), const EventsTab()],
            ),
          ),
          // Kepala: krem pekat di tab Acara, transparan di atas peta.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _tabs.animation!,
              builder: (context, child) {
                final acara = _tabs.animation!.value > 0.5;
                return Container(
                  padding: EdgeInsets.fromLTRB(20, top + 8, 20, 12),
                  color: acara ? AppColors.creamTop : Colors.transparent,
                  child: child,
                );
              },
              child: Row(
                children: [
                  Material(
                    color: AppColors.card,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.chevron_left,
                          color: AppColors.bronze,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillTabs(
                      controller: _tabs,
                      labels: const ['Peta', 'Acara'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
