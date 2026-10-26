// screens/game/game_screen.dart
// Mini game (NUMISMA_GUIDE 7.10): dua mode dalam satu layar, dipisah jadi
// dua tab seperti layar Konversi. Tebak Asal Koin ada di tebak_asal_tab.dart,
// Coin Flip (accelerometer) di coin_flip_tab.dart.

import 'package:flutter/material.dart';

import 'coin_flip_tab.dart';
import 'tebak_asal_tab.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game'),
          // Warna tab diatur tema global (tabBarTheme di theme.dart).
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tebak Asal Koin'),
              Tab(text: 'Coin Flip'),
            ],
          ),
        ),
        body: const TabBarView(children: [TebakAsalTab(), CoinFlipTab()]),
      ),
    );
  }
}
