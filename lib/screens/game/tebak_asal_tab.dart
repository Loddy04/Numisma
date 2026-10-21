// screens/game/tebak_asal_tab.dart
// Tebak Asal Koin (NUMISMA_GUIDE 7.10a): 10 soal, tiap soal menampilkan satu
// koin/uang kertas generik (nominal + kode mata uang) dan empat pilihan
// negara. Skor disimpan ke game_scores, skor tertinggi ditampilkan.

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/game_service.dart';
import '../../theme.dart';
import '../../widgets/coin_face.dart';

class TebakAsalTab extends StatefulWidget {
  const TebakAsalTab({super.key});

  @override
  State<TebakAsalTab> createState() => _TebakAsalTabState();
}

// Dijaga hidup supaya pindah ke tab Coin Flip tidak mengulang permainan.
class _TebakAsalTabState extends State<TebakAsalTab>
    with AutomaticKeepAliveClientMixin {
  final _game = GameService();
  final _auth = AuthService();

  List<QuizQuestion> _questions = [];
  int _index = 0;
  int _score = 0;
  // Pilihan yang diketuk pada soal ini; null = belum menjawab.
  String? _chosen;
  bool _finished = false;
  bool _loading = true;
  String? _error;
  BestScore? _best;
  int? _userId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _index = 0;
      _score = 0;
      _chosen = null;
      _finished = false;
    });
    try {
      final user = await _auth.currentUser();
      _userId = user?.id;
      final questions = await _game.buildQuiz();
      final best = _userId == null ? null : await _game.bestScore(_userId!);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _best = best;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Soal gagal dimuat. Coba lagi.';
        _loading = false;
      });
    }
  }

  void _answer(String option) {
    // Satu soal hanya boleh dijawab sekali.
    if (_chosen != null) return;
    setState(() {
      _chosen = option;
      if (option == _questions[_index].answer) _score++;
    });
  }

  Future<void> _next() async {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _chosen = null;
      });
      return;
    }
    setState(() => _finished = true);
    await _saveScore();
  }

  // Gagal menyimpan skor tidak boleh merusak layar hasil: permainan tetap
  // selesai, hanya skor tertingginya yang mungkin tidak diperbarui.
  Future<void> _saveScore() async {
    final id = _userId;
    if (id == null) return;
    try {
      await _game.saveScore(
        userId: id,
        score: _score,
        total: _questions.length,
      );
      final best = await _game.bestScore(id);
      if (mounted) setState(() => _best = best);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _start, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    return _finished ? _buildResult() : _buildQuestion();
  }

  Widget _bestText() {
    final best = _best;
    return Text(
      best == null
          ? 'Skor tertinggi: belum ada'
          : 'Skor tertinggi: ${best.score}/${best.total}',
      style: const TextStyle(color: Colors.grey),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_index];
    final coin = q.coin;
    final isBanknote = coin.type == 'banknote';
    final nominal = coin.denomination % 1 == 0
        ? coin.denomination.toInt().toString()
        : coin.denomination.toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Soal ${_index + 1} dari ${_questions.length} · Skor $_score',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        _bestTextCentered(),
        const SizedBox(height: 20),
        Center(
          child: CoinFace(
            title: nominal,
            subtitle:
                '${coin.currencyCode}'
                '${coin.year == null ? '' : ' · ${coin.year}'}',
            banknote: isBanknote,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isBanknote ? 'Uang kertas' : 'Koin',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        const Text(
          'Mata uang ini berasal dari negara mana?',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        for (final option in q.options) _optionButton(q, option),
        if (_chosen != null) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _next,
            child: Text(
              _index + 1 < _questions.length
                  ? 'Soal berikutnya'
                  : 'Lihat hasil',
            ),
          ),
        ],
      ],
    );
  }

  Widget _bestTextCentered() => Center(child: _bestText());

  // Setelah menjawab: jawaban benar hijau, pilihan yang salah merah, sisanya
  // diredupkan, supaya pengguna langsung tahu letak jawabannya.
  Widget _optionButton(QuizQuestion q, String option) {
    final answered = _chosen != null;
    Color? bg;
    if (answered && option == q.answer) {
      bg = AppColors.success;
    } else if (answered && option == _chosen) {
      bg = AppColors.danger;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: answered ? null : () => _answer(option),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: bg == null ? null : Colors.white,
          disabledBackgroundColor: bg ?? Colors.grey.shade300,
          disabledForegroundColor: bg == null ? Colors.grey : Colors.white,
        ),
        child: Text(option),
      ),
    );
  }

  Widget _buildResult() {
    final total = _questions.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: AppColors.gold),
            const SizedBox(height: 12),
            Text(
              'Skor kamu $_score dari $total',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _bestText(),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _start, child: const Text('Main lagi')),
          ],
        ),
      ),
    );
  }
}
