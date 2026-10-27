// screens/convert/convert_screen.dart
// Menu Konversi (NUMISMA_GUIDE Bagian 7.7): satu layar yang menggabungkan
// Kurs dan Nilai Koleksi. Pengguna memilih mata uang tujuan, lalu memilih satu
// atau beberapa koin di daftar koleksinya; tiap koin menampilkan hasil
// konversinya, dan koin yang dipilih dijumlahkan. Total seluruh koleksi
// didapat dengan "Pilih semua", jadi tidak perlu perhitungan terpisah.
//
// Ini NILAI NOMINAL SETARA berdasarkan kurs hari itu, bukan harga pasar
// kolektor (Bagian 1.6). Layar tidak memanggil HTTP/database langsung:
// semuanya lewat RatesService dan CoinRepo (aturan Bagian 4.1).

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../models/coin.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../services/rates_service.dart';
import '../../theme.dart';
import '../../widgets/currency_picker.dart';
import '../../widgets/field_label.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/soft_card.dart';

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  final _auth = AuthService();
  final _repo = CoinRepo();
  final _rates = RatesService();

  // Mata uang tujuan konversi.
  String _target = 'IDR';

  List<Coin> _coins = [];
  bool _loading = true;
  String? _error;

  // kode mata uang koin -> kurs ke mata uang tujuan (null = tidak tersedia).
  Map<String, RateInfo?> _rateOf = {};
  bool _ratesLoading = false;

  // id koin yang dipilih di daftar.
  final Set<String> _selected = {};

  // Nomor pemuatan: hasil lama yang datang terlambat dibuang, supaya angka
  // tidak "melompat" mundur saat pengguna mengganti mata uang dengan cepat.
  int _ratesNo = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // `force` = tarik-untuk-menyegarkan: kurs diambil ulang dari API, dan
  // spinner bawaan RefreshIndicator sudah cukup (isi layar tidak diganti).
  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = !force;
      _error = null;
    });
    try {
      final user = await _auth.currentUser();
      if (user == null) throw Exception('Belum login');
      final coins = await _repo.list(user.id!);
      if (!mounted) return;
      setState(() {
        _coins = coins;
        _loading = false;
        // Buang pilihan untuk koin yang sudah tidak ada.
        final ids = coins.map((c) => c.id).toSet();
        _selected.removeWhere((id) => !ids.contains(id));
      });
      await _loadRates(force: force);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat koleksi, coba lagi.';
        _loading = false;
      });
    }
  }

  // Kurs dari tiap mata uang koin ke mata uang tujuan. Satu permintaan per
  // mata uang (bukan per koin): 30 koin JPY cukup satu kali minta kurs.
  Future<void> _loadRates({bool force = false}) async {
    final codes = {for (final c in _coins) c.currencyCode};
    if (codes.isEmpty) {
      setState(() => _rateOf = {});
      return;
    }
    final no = ++_ratesNo;
    setState(() => _ratesLoading = true);
    final entries = await Future.wait(
      codes.map((code) async {
        try {
          final info = await _rates.getRateInfo(
            code,
            _target,
            forceRefresh: force,
          );
          return MapEntry<String, RateInfo?>(code, info);
        } on RateUnavailable {
          return MapEntry<String, RateInfo?>(code, null);
        }
      }),
    );
    if (!mounted || no != _ratesNo) return;
    setState(() {
      _rateOf = Map.fromEntries(entries);
      _ratesLoading = false;
    });
  }

  // Nilai satu koin dalam mata uang tujuan; null bila kursnya tidak ada.
  double? _valueOf(Coin c) {
    final info = _rateOf[c.currencyCode];
    return info == null ? null : c.denomination * info.rate;
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _coins.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_coins.map((c) => c.id));
      }
    });
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
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: PageHeader(title: 'Konversi'),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(force: true),
                  child: ListView(
                    // Selalu bisa ditarik, walau isinya pendek.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final muted = AppColors.ink.withValues(alpha: 0.6);
    if (_loading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_error != null) {
      return [Text(_error!, style: const TextStyle(color: AppColors.danger))];
    }
    if (_coins.isEmpty) {
      return [
        Text(
          'Koleksimu masih kosong. Tambahkan koin di menu Koleksi.',
          style: TextStyle(color: muted),
        ),
      ];
    }
    return [
      Text(
        'Pilih mata uang tujuan, lalu pilih koin yang ingin dilihat nilainya. '
        'Tekan "Pilih semua" untuk total seluruh koleksi.',
        style: TextStyle(fontSize: 14, height: 1.4, color: muted),
      ),
      const SizedBox(height: 16),
      const FieldLabel('Konversi ke'),
      CurrencyPickerField(
        label: 'Pilih mata uang',
        initialCode: _target,
        required: true,
        onChanged: (code) {
          if (code == null) return;
          _target = code;
          _loadRates();
        },
      ),
      const SizedBox(height: 16),
      _summaryCard(),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              _selected.isEmpty
                  ? '${_coins.length} item'
                  : '${_selected.length} dari ${_coins.length} dipilih',
              style: TextStyle(fontSize: 14, color: muted),
            ),
          ),
          if (_ratesLoading)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Material(
            color: AppColors.card,
            shape: const StadiumBorder(
              side: BorderSide(color: AppColors.cardBorder),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _toggleAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _selected.length == _coins.length
                      ? 'Hapus pilihan'
                      : 'Pilih semua',
                  style: const TextStyle(fontSize: 14, color: AppColors.bronze),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final c in _coins) _coinRow(c),
      const SizedBox(height: 14),
      Text(
        'Nilai nominal setara berdasarkan kurs referensi Frankfurter, bukan '
        'harga pasar kolektor. Diperbarui pada hari kerja.',
        style: TextStyle(fontSize: 12, height: 1.4, color: muted),
      ),
    ];
  }

  // Jumlah koin yang dipilih dalam mata uang tujuan, beserta keterangan kurs,
  // di kartu hero bergradasi.
  Widget _summaryCard() {
    final light = Colors.white.withValues(alpha: 0.8);
    if (_selected.isEmpty) {
      return HeroCard(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOTAL TERPILIH',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: Color(0xFFE6CFA3),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '–',
              style: AppText.serif(
                size: 48,
                weight: FontWeight.w700,
                color: AppColors.creamTop,
              ),
            ),
            Text(
              'Belum ada koin dipilih.',
              style: TextStyle(fontSize: 14, color: light),
            ),
          ],
        ),
      );
    }
    final chosen = _coins.where((c) => _selected.contains(c.id)).toList();
    var sum = 0.0;
    var counted = 0;
    String? oldest;
    var anyFromCache = false;
    for (final c in chosen) {
      final v = _valueOf(c);
      if (v == null) continue;
      sum += v;
      counted++;
      final info = _rateOf[c.currencyCode]!;
      anyFromCache = anyFromCache || info.fromCache;
      final date = info.rateDate;
      // Tanggal ISO bisa dibandingkan sebagai teks; yang terlama dipakai
      // (jujur: totalnya sesegar kurs yang tertua).
      if (date != null && (oldest == null || date.compareTo(oldest) < 0)) {
        oldest = date;
      }
    }
    final skipped = chosen.length - counted;
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL TERPILIH (${chosen.length} ITEM)',
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: Color(0xFFE6CFA3),
            ),
          ),
          const SizedBox(height: 6),
          // Tidak ada satu pun kurs yang didapat: jangan tampilkan "0".
          if (counted == 0)
            Text(
              _ratesLoading ? 'Menghitung…' : 'Tidak tersedia',
              style: AppText.serif(
                size: 34,
                weight: FontWeight.w700,
                color: AppColors.creamTop,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '≈ ${formatNumber(sum)}',
                      style: AppText.serif(
                        size: 44,
                        weight: FontWeight.w700,
                        color: AppColors.creamTop,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_target, style: TextStyle(fontSize: 18, color: light)),
              ],
            ),
          if (skipped > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$skipped item tidak dihitung karena kursnya tidak tersedia.',
                style: const TextStyle(fontSize: 13, color: Color(0xFFFFB4A8)),
              ),
            ),
          if (oldest != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tanggal kurs: ${formatRateDate(oldest)}'
                '${anyFromCache ? ' (sebagian dari cache, internet tidak terjangkau)' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: anyFromCache ? const Color(0xFFFFB4A8) : light,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _coinRow(Coin c) {
    final value = _valueOf(c);
    final selected = _selected.contains(c.id);
    final detail = [
      c.country,
      if (c.year != null) '${c.year}',
      c.type == 'banknote' ? 'uang kertas' : 'koin',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 22,
        color: selected ? AppColors.tileActive : null,
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        onTap: () => _toggle(c.id),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: AppColors.bronze,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.denominationLabel} ${c.currencyCode}',
                    style: AppText.serif(size: 18, weight: FontWeight.w700),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value == null
                  ? (_ratesLoading ? '…' : '—')
                  : '≈ ${formatNumber(value)} $_target',
              style: TextStyle(
                fontSize: 15,
                color: value == null ? Colors.grey : AppColors.bronze,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
