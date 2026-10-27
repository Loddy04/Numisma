// screens/game/tebak_asal_tab.dart
// Tebak Asal Koin (NUMISMA_GUIDE 7.10a): 10 soal, tiap soal menampilkan satu
// koin/uang kertas generik (nominal + kode mata uang) dan DUA pilihan negara,
// kiri dan kanan. Menjawab dengan MEMIRINGKAN HP ke kiri atau kanan memakai
// GYROSCOPE (sensor K8), atau dengan mengetuk kartu pilihan sebagai cadangan
// (HP tanpa gyroscope, atau saat demo). Skor disimpan ke game_scores, skor
// tertinggi ditampilkan.
//
// Gyroscope melaporkan KECEPATAN putar (rad/detik), bukan sudut. Seperti di
// tilt_photo.dart, kecepatan dijumlahkan dari waktu ke waktu menjadi sudut
// miring, lalu sudutnya perlahan "bocor" kembali ke tengah supaya tidak
// melayang. Agar jawaban tidak terpicu getaran tangan, miringnya harus
// melewati ambang dan BERTAHAN sebentar. Setelah menjawab, kontrol terkunci
// sampai HP kembali ke tengah, supaya sisa kemiringan tidak langsung
// menjawab soal berikutnya.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../services/auth_service.dart';
import '../../services/game_service.dart';
import '../../theme.dart';
import '../../widgets/coin_face.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/hero_card.dart';

class TebakAsalTab extends StatefulWidget {
  // Dipakai untuk tahu apakah tab ini sedang terlihat: sensor hanya menjawab
  // saat tab Tebak Asal aktif.
  final TabController tabs;
  const TebakAsalTab({super.key, required this.tabs});

  @override
  State<TebakAsalTab> createState() => _TebakAsalTabState();
}

// Dijaga hidup supaya pindah ke tab Coin Flip tidak mengulang permainan.
class _TebakAsalTabState extends State<TebakAsalTab>
    with AutomaticKeepAliveClientMixin {
  // --- Kalibrasi gyroscope (hasil tebakan awal; sesuaikan lewat uji di HP) ---
  // Sudut (radian) yang harus dilewati agar dihitung "miring": 0,30 = sekitar
  // 17 derajat.
  static const _threshold = 0.30;
  // Selama miring melewati ambang, harus bertahan selama ini sebelum menjawab.
  static const _hold = Duration(milliseconds: 250);
  // Sudut di bawah ini dianggap "kembali ke tengah" (sekitar 7 derajat).
  static const _centerBand = 0.12;
  // Seberapa cepat sudut kembali ke tengah (per detik). Kecil = miring
  // bertahan lebih lama.
  static const _returnRate = 0.4;
  static const _maxAngle = 0.9;
  // Kalau kiri-kanan terasa terbalik di HP, ubah ini menjadi -1.
  static const _direction = 1.0;
  // Jeda sebelum lanjut otomatis ke soal berikutnya. Bila dijawab dengan
  // memiringkan HP, HP juga harus sudah kembali ke tengah.
  static const _autoAdvance = Duration(milliseconds: 1400);

  final _game = GameService();
  final _auth = AuthService();

  StreamSubscription<GyroscopeEvent>? _sub;
  Timer? _advanceTimer;
  double _angle = 0; // positif = miring ke kanan (setelah _direction)
  DateTime? _lastTs;
  int _holdSide = 0; // -1 kiri, 1 kanan, 0 tidak ada
  DateTime? _holdSince;
  bool _locked = true; // true = tunggu HP kembali ke tengah dulu
  bool _sensorOk = true;
  bool _answeredByTilt = false;
  DateTime? _answeredAt;

  List<QuizQuestion> _questions = [];
  int _index = 0;
  int _score = 0;
  // Pilihan yang dipilih pada soal ini; null = belum menjawab.
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
    try {
      _sub = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen(
            _onGyro,
            // HP tanpa gyroscope (atau emulator): kartu tetap bisa diketuk.
            onError: (_) {
              if (mounted) setState(() => _sensorOk = false);
            },
            cancelOnError: true,
          );
    } catch (_) {
      _sensorOk = false;
    }
  }

  @override
  void dispose() {
    // Wajib dibatalkan, kalau tidak sensor terus membaca setelah layar ditutup.
    _sub?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _index = 0;
      _score = 0;
      _chosen = null;
      _finished = false;
      _locked = true;
      _answeredByTilt = false;
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

  // --- Gyroscope -------------------------------------------------------

  void _onGyro(GyroscopeEvent e) {
    final last = _lastTs;
    _lastTs = e.timestamp;
    if (last == null) return;
    // Selang waktu antar-pembacaan, dibatasi supaya lonjakan (mis. setelah
    // aplikasi dijeda) tidak membuat sudut melompat.
    final dt = (e.timestamp.difference(last).inMicroseconds / 1e6).clamp(
      0.0,
      0.1,
    );
    if (dt == 0) return;

    // Gerak "miring ke kanan" bisa berupa memutar HP seperti kemudi (sumbu z)
    // atau menghadapkan layar ke kanan (sumbu y); keduanya dijumlahkan dengan
    // tanda yang searah, supaya cara memiringkan yang mana pun terbaca.
    final lateral = e.y - e.z;
    final leak = math.exp(-_returnRate * dt);
    _angle = ((_angle + _direction * lateral * dt) * leak).clamp(
      -_maxAngle,
      _maxAngle,
    );
    if (!mounted) return;

    final visible = widget.tabs.index == 0 && !widget.tabs.indexIsChanging;
    if (!visible || _loading || _finished || _error != null) {
      _holdSide = 0;
      _holdSince = null;
      return;
    }

    final now = DateTime.now();

    // Sudah menjawab: lanjut otomatis bila sudah cukup lama (dan, bila dijawab
    // dengan miring, HP sudah kembali ke tengah).
    if (_chosen != null) {
      if (!_tryAdvance()) setState(() {});
      return;
    }

    // Terkunci sampai HP kembali ke tengah (awal soal atau setelah menjawab).
    if (_locked) {
      if (_angle.abs() < _centerBand) _locked = false;
      setState(() {});
      return;
    }

    final side = _angle >= _threshold ? 1 : (_angle <= -_threshold ? -1 : 0);
    if (side == 0) {
      _holdSide = 0;
      _holdSince = null;
    } else if (side != _holdSide) {
      _holdSide = side;
      _holdSince = now;
    } else if (now.difference(_holdSince!) >= _hold) {
      final options = _questions[_index].options;
      _answer(options[side == -1 ? 0 : 1], byTilt: true);
      return;
    }
    setState(() {});
  }

  // --- Jawaban ---------------------------------------------------------

  void _answer(String option, {bool byTilt = false}) {
    // Satu soal hanya boleh dijawab sekali.
    if (_chosen != null) return;
    setState(() {
      _chosen = option;
      _answeredByTilt = byTilt;
      _answeredAt = DateTime.now();
      _locked = true;
      _holdSide = 0;
      _holdSince = null;
      if (option == _questions[_index].answer) _score++;
    });
    // Dijawab dengan miring: lanjut otomatis setelah jeda (dan HP kembali ke
    // tengah). Dijawab dengan ketukan: pemain lanjut lewat tombol.
    _advanceTimer?.cancel();
    if (byTilt) _advanceTimer = Timer(_autoAdvance, _tryAdvance);
  }

  // Lanjut ke soal berikutnya bila syaratnya terpenuhi; true = sudah lanjut.
  bool _tryAdvance() {
    final at = _answeredAt;
    if (_chosen == null || at == null || !_answeredByTilt) return false;
    if (DateTime.now().difference(at) < _autoAdvance) return false;
    if (_angle.abs() >= _centerBand) return false;
    _next();
    return true;
  }

  Future<void> _next() async {
    if (_chosen == null) return;
    _advanceTimer?.cancel();
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _chosen = null;
        _answeredByTilt = false;
        _locked = true; // tunggu HP kembali ke tengah
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

  // --- Tampilan --------------------------------------------------------

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

  String get _bestLabel {
    final best = _best;
    return best == null
        ? 'Skor tertinggi: belum ada'
        : 'Skor tertinggi: ${best.score}/${best.total}';
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tileActive,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.bronze),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_index];
    final coin = q.coin;
    final isBanknote = coin.type == 'banknote';
    final nominal = coin.denomination % 1 == 0
        ? coin.denomination.toInt().toString()
        : coin.denomination.toString();

    // Seberapa jauh miring ke tiap sisi (0..1), untuk menyalakan kartunya.
    final leftTilt = (-_angle / _threshold).clamp(0.0, 1.0);
    final rightTilt = (_angle / _threshold).clamp(0.0, 1.0);

    final answered = _chosen != null;
    final correct = answered && _chosen == q.answer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chip('Soal ${_index + 1} dari ${_questions.length}'),
            const SizedBox(width: 8),
            _chip('Skor $_score'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _bestLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.ink.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 22),
        // Koin ikut miring sedikit mengikuti HP.
        Center(
          child: Transform.rotate(
            angle: _angle * 0.35,
            child: CoinFace(
              title: nominal,
              subtitle:
                  coin.currencyCode +
                  (coin.year == null ? '' : ' · ${coin.year}'),
              banknote: isBanknote,
              size: 150,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isBanknote ? 'Uang kertas' : 'Koin',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.ink.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 18),
        Text(
          'Mata uang ini berasal dari negara mana?',
          textAlign: TextAlign.center,
          style: AppText.serif(size: 21, weight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _optionCard(
                q,
                q.options[0],
                left: true,
                tilt: leftTilt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _optionCard(
                q,
                q.options[1],
                left: false,
                tilt: rightTilt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _tiltMeter(),
        const SizedBox(height: 14),
        if (!answered)
          Text(
            _sensorOk
                ? 'Miringkan HP ke kiri atau kanan untuk menjawab'
                : 'Sensor tidak tersedia di perangkat ini. Ketuk pilihan untuk '
                      'menjawab.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          )
        else ...[
          Text(
            correct ? 'Benar!' : 'Salah. Jawabannya ${q.answer}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: correct ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: _index + 1 < _questions.length
                ? 'Soal berikutnya'
                : 'Lihat hasil',
            onPressed: _next,
          ),
        ],
      ],
    );
  }

  // Penunjuk kemiringan: jalur tipis dengan titik yang bergeser mengikuti
  // sudut, dan penanda ambang di kiri dan kanan. Membantu melihat bahwa sensor
  // merespons dan seberapa jauh harus miring.
  Widget _tiltMeter() {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final x = (_angle / _maxAngle).clamp(-1.0, 1.0) * (w / 2 - 8);
        final mark = _threshold / _maxAngle * (w / 2 - 8);
        Widget tick(double dx) => Positioned(
          left: w / 2 + dx - 1,
          top: 2,
          child: Container(
            width: 2,
            height: 10,
            color: AppColors.bronze.withValues(alpha: 0.5),
          ),
        );
        return SizedBox(
          height: 14,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 6,
                child: Container(
                  height: 2,
                  color: AppColors.cardBorder,
                ),
              ),
              tick(-mark),
              tick(mark),
              Positioned(
                left: w / 2 + x - 7,
                top: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.brown,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Kartu pilihan. Sebelum menjawab, menyala mengikuti seberapa jauh HP
  // miring ke sisinya. Setelah menjawab: jawaban benar hijau, pilihan salah
  // merah, sisanya diredupkan.
  Widget _optionCard(
    QuizQuestion q,
    String option, {
    required bool left,
    required double tilt,
  }) {
    final answered = _chosen != null;
    Color fill = Color.lerp(AppColors.card, AppColors.tileActive, tilt)!;
    Color border = Color.lerp(AppColors.cardBorder, AppColors.bronze, tilt)!;
    Color text = AppColors.ink;
    if (answered && option == q.answer) {
      fill = AppColors.success;
      border = AppColors.success;
      text = Colors.white;
    } else if (answered && option == _chosen) {
      fill = AppColors.danger;
      border = AppColors.danger;
      text = Colors.white;
    } else if (answered) {
      text = AppColors.ink.withValues(alpha: 0.4);
    }

    final arrow = Icon(
      left ? Icons.arrow_back : Icons.arrow_forward,
      size: 22,
      color: answered && (option == q.answer || option == _chosen)
          ? Colors.white
          : AppColors.bronze,
    );

    return Transform.scale(
      scale: answered ? 1.0 : 1.0 + 0.05 * tilt,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1 + tilt),
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: answered ? null : () => _answer(option),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  arrow,
                  const SizedBox(height: 8),
                  Text(
                    option,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(
                      size: 20,
                      weight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final total = _questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Spacer(),
          HeroCard(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 56,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 10),
                Text(
                  'SKOR KAMU',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_score / $total',
                  style: AppText.serif(
                    size: 56,
                    weight: FontWeight.w700,
                    color: AppColors.creamTop,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _bestLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GradientButton(
            label: 'Main lagi',
            icon: Icons.replay,
            onPressed: _start,
          ),
        ],
      ),
    );
  }
}
