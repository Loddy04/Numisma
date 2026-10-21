// screens/convert/collection_value_tab.dart
// Tab "Nilai Koleksi" (NUMISMA_GUIDE Bagian 7.7a): total nominal seluruh
// koin dan uang kertas milik pengguna, diubah ke IDR dan satu mata uang
// pilihan. Ini NILAI NOMINAL SETARA berdasarkan kurs hari itu, bukan
// harga pasar kolektor (Bagian 1.6), jadi labelnya wajib ditampilkan.

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../models/coin.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../services/rates_service.dart';
import '../../theme.dart';
import '../../widgets/currency_picker.dart';

class CollectionValueTab extends StatefulWidget {
  const CollectionValueTab({super.key});

  @override
  State<CollectionValueTab> createState() => _CollectionValueTabState();
}

class _CollectionValueTabState extends State<CollectionValueTab> {
  final _authService = AuthService();
  final _repo = CoinRepo();
  final _rates = RatesService();

  // Mata uang pilihan pengguna; IDR selalu ditampilkan di atasnya.
  String _target = 'USD';

  // Nomor pemuatan: hasil lama yang datang terlambat dibuang.
  int _loadNo = 0;

  bool _loading = true;
  String? _error;
  int _coinCount = 0;
  CollectionValue? _inIdr;
  CollectionValue? _inTarget;

  // Tab ini dibuat ulang tiap dibuka (tanpa keep-alive), jadi setelah
  // menambah koin di Koleksi, angkanya otomatis segar saat tab dibuka lagi.
  @override
  void initState() {
    super.initState();
    _load();
  }

  // `force` = tarik-untuk-menyegarkan: kurs diambil ulang dari API, dan
  // spinner bawaan RefreshIndicator sudah cukup (isi layar tidak diganti).
  Future<void> _load({bool force = false}) async {
    final myLoad = ++_loadNo;
    setState(() {
      _loading = !force;
      _error = null;
    });
    try {
      final user = await _authService.currentUser();
      if (user == null) throw Exception('Belum login');
      final List<Coin> coins = await _repo.list(user.id!);

      CollectionValue? inIdr;
      CollectionValue? inTarget;
      if (coins.isNotEmpty) {
        inIdr = await _rates.valueOfCoins(coins, 'IDR', forceRefresh: force);
        inTarget = _target == 'IDR'
            ? inIdr
            : await _rates.valueOfCoins(coins, _target, forceRefresh: force);
      }
      if (!mounted || myLoad != _loadNo) return;
      setState(() {
        _coinCount = coins.length;
        _inIdr = inIdr;
        _inTarget = inTarget;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || myLoad != _loadNo) return;
      setState(() {
        _error = 'Gagal menghitung nilai koleksi, coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        // Selalu bisa ditarik untuk menyegarkan, walau isinya pendek.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Nilai nominal setara',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jumlah nominal seluruh koin dan uang kertasmu, dikonversi '
            'dengan kurs hari ini. Bukan harga pasar kolektor.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          CurrencyPickerField(
            label: 'Mata uang pilihan',
            initialCode: _target,
            required: true,
            onChanged: (code) {
              if (code == null) return;
              _target = code;
              _load();
            },
          ),
          const SizedBox(height: 16),
          ..._buildBody(),
        ],
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
    final idr = _inIdr;
    final chosen = _inTarget;
    if (_coinCount == 0 || idr == null || chosen == null) {
      return const [
        Text('Koleksimu masih kosong. Tambahkan koin di menu Koleksi.'),
      ];
    }

    return [
      _valueCard('IDR', idr),
      if (_target != 'IDR') _valueCard(_target, chosen),
      const SizedBox(height: 8),
      Text(
        'Dihitung dari ${idr.counted} dari $_coinCount koin.',
        style: const TextStyle(fontSize: 12),
      ),
      if (idr.skipped > 0)
        Text(
          '${idr.skipped} koin tidak dihitung karena kursnya tidak tersedia.',
          style: const TextStyle(fontSize: 12, color: AppColors.danger),
        ),
      if (idr.oldestRateDate != null)
        Text(
          'Tanggal kurs: ${formatRateDate(idr.oldestRateDate!)}'
          '${idr.anyFromCache ? ' (sebagian dari cache, internet tidak terjangkau)' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
    ];
  }

  Widget _valueCard(String code, CollectionValue v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total dalam $code',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              // Tidak ada satu pun kurs yang didapat: jangan tampilkan "0".
              v.counted == 0
                  ? 'Tidak tersedia'
                  : '${formatNumber(v.total)} $code',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.bronze,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
