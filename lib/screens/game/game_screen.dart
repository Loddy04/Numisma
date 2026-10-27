// screens/game/game_screen.dart
// Mini game (NUMISMA_GUIDE 7.10): dua mode dalam satu layar, dipisah jadi
// dua tab. Tebak Asal Koin (dijawab dengan memiringkan HP, gyroscope) ada di
// tebak_asal_tab.dart, Coin Flip (accelerometer) di coin_flip_tab.dart.

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pill_tabs.dart';
import 'coin_flip_tab.dart';
import 'tebak_asal_tab.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: PageHeader(title: 'Permainan'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: PillTabs(
                  controller: _tabs,
                  labels: const ['Tebak Asal', 'Coin Flip'],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [TebakAsalTab(tabs: _tabs), const CoinFlipTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
