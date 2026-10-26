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
      appBar: AppBar(title: const Text('Konversi')),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          // Selalu bisa ditarik, walau isinya pendek.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: _buildBody(),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (_loading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_error != null) {
      return [Text(_error!, style: const TextStyle(color: AppColors.danger))];
    }
    if (_coins.isEmpty) {
      return const [
        Text('Koleksimu masih kosong. Tambahkan koin di menu Koleksi.'),
      ];
    }
    return [
      const Text(
        'Konversi koleksi',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Pilih mata uang tujuan, lalu pilih koin yang ingin dilihat nilainya. '
        'Tekan "Pilih semua" untuk total seluruh koleksi.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      const SizedBox(height: 12),
      CurrencyPickerField(
        label: 'Konversi ke',
        initialCode: _target,
        required: true,
        onChanged: (code) {
          if (code == null) return;
          _target = code;
          _loadRates();
        },
      ),
      const SizedBox(height: 8),
      _summaryCard(),
      Row(
        children: [
          Expanded(
            child: Text(
              _selected.isEmpty
                  ? '${_coins.length} item'
                  : '${_selected.length} dari ${_coins.length} dipilih',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          if (_ratesLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          TextButton(
            onPressed: _toggleAll,
            child: Text(
              _selected.length == _coins.length
                  ? 'Hapus pilihan'
                  : 'Pilih semua',
            ),
          ),
        ],
      ),
      for (final c in _coins) _coinRow(c),
      const SizedBox(height: 16),
      const Text(
        'Nilai nominal setara berdasarkan kurs referensi Frankfurter, bukan '
        'harga pasar kolektor. Diperbarui pada hari kerja.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ];
  }

  // Jumlah koin yang dipilih dalam mata uang tujuan, beserta keterangan kurs.
  Widget _summaryCard() {
    if (_selected.isEmpty) {
      return const Card(
        margin: EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Belum ada koin dipilih.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.latte,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total terpilih (${chosen.length} item)',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              // Tidak ada satu pun kurs yang didapat: jangan tampilkan "0".
              counted == 0
                  ? (_ratesLoading ? 'Menghitung…' : 'Tidak tersedia')
                  : '≈ ${formatNumber(sum)} $_target',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.bronze,
              ),
            ),
            if (skipped > 0)
              Text(
                '$skipped item tidak dihitung karena kursnya tidak tersedia.',
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            if (oldest != null)
              Text(
                'Tanggal kurs: ${formatRateDate(oldest)}'
                '${anyFromCache ? ' (sebagian dari cache, internet tidak terjangkau)' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: anyFromCache ? AppColors.danger : Colors.grey,
                ),
              ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _toggle(c.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => _toggle(c.id)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.denominationLabel} ${c.currencyCode}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  fontWeight: FontWeight.bold,
                  color: value == null ? Colors.grey : AppColors.bronze,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
