// screens/convert/convert_screen.dart
// Menu Konversi (NUMISMA_GUIDE Bagian 7.7). Tiga tab: Kurs, Nilai Koleksi
// (collection_value_tab.dart), dan Jam Dunia (world_clock_tab.dart). Layar tidak memanggil
// HTTP/database langsung: semuanya lewat RatesService (aturan Bagian 4.1).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format_util.dart';
import '../../services/rates_service.dart';
import '../../theme.dart';
import '../../widgets/currency_picker.dart';
import 'collection_value_tab.dart';
import 'world_clock_tab.dart';

class ConvertScreen extends StatelessWidget {
  const ConvertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konversi'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Kurs'),
              Tab(text: 'Nilai Koleksi'),
              Tab(text: 'Jam Dunia'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_KursTab(), CollectionValueTab(), WorldClockTab()],
        ),
      ),
    );
  }
}

class _KursTab extends StatefulWidget {
  const _KursTab();

  @override
  State<_KursTab> createState() => _KursTabState();
}

class _KursTabState extends State<_KursTab> with AutomaticKeepAliveClientMixin {
  final _service = RatesService();
  final _amountController = TextEditingController(text: '1');
  // Kunci ke pemilih supaya tombol tukar bisa mengubah nilainya dari luar.
  final _fromKey = GlobalKey<FormFieldState<String>>();
  final _toKey = GlobalKey<FormFieldState<String>>();

  String _from = 'USD';
  String _to = 'IDR';

  Timer? _debounce;
  // Nomor permintaan: hasil yang datang terlambat dari ketikan lama
  // dibuang supaya angka di layar tidak "melompat" mundur.
  int _requestNo = 0;

  bool _loading = false;
  double? _result;
  RateInfo? _info;
  String? _error;

  // Tab tetap hidup saat berpindah ke Jam Dunia, jadi isian tidak hilang.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  // Menerima koma sebagai desimal (kebiasaan pengetikan Indonesia).
  double? _parseAmount() {
    final text = _amountController.text.trim().replaceAll(',', '.');
    return double.tryParse(text);
  }

  // Tertunda 400 ms supaya tidak memanggil API di setiap huruf yang diketik.
  void _scheduleRecalculate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _recalculate);
  }

  // `force` = tarik-untuk-menyegarkan: kurs diambil ulang dari API.
  Future<void> _recalculate({bool force = false}) async {
    final amount = _parseAmount();
    if (amount == null || amount < 0) {
      setState(() {
        _result = null;
        _info = null;
        _error = _amountController.text.trim().isEmpty
            ? null
            : 'Jumlah harus berupa angka.';
      });
      return;
    }

    final myRequest = ++_requestNo;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await _service.getRateInfo(_from, _to, forceRefresh: force);
      if (!mounted || myRequest != _requestNo) return;
      setState(() {
        _info = info;
        _result = amount * info.rate;
        _loading = false;
      });
    } on RateUnavailable catch (e) {
      if (!mounted || myRequest != _requestNo) return;
      setState(() {
        _result = null;
        _info = null;
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _swap() {
    final oldFrom = _from;
    _fromKey.currentState?.didChange(_to);
    _toKey.currentState?.didChange(oldFrom);
    setState(() {
      _from = _to;
      _to = oldFrom;
    });
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // wajib untuk AutomaticKeepAliveClientMixin
    return RefreshIndicator(
      onRefresh: () => _recalculate(force: true),
      child: ListView(
        // Selalu bisa ditarik, walau isinya muat di satu layar.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(labelText: 'Jumlah'),
            onChanged: (_) => _scheduleRecalculate(),
          ),
          const SizedBox(height: 12),
          CurrencyPickerField(
            key: _fromKey,
            label: 'Dari',
            initialCode: _from,
            required: true,
            onChanged: (code) {
              if (code == null) return;
              setState(() => _from = code);
              _recalculate();
            },
          ),
          Center(
            child: TextButton.icon(
              onPressed: _swap,
              icon: const Icon(Icons.swap_vert),
              label: const Text('Tukar'),
            ),
          ),
          CurrencyPickerField(
            key: _toKey,
            label: 'Ke',
            initialCode: _to,
            required: true,
            onChanged: (code) {
              if (code == null) return;
              setState(() => _to = code);
              _recalculate();
            },
          ),
          const SizedBox(height: 20),
          _buildResult(),
          const SizedBox(height: 12),
          const Text(
            'Kurs referensi dari Frankfurter, bukan harga jual-beli. '
            'Diperbarui pada hari kerja.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }
    final result = _result;
    final info = _info;
    if (result == null || info == null) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatNumber(result)} $_to',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bronze,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('1 $_from = ${formatNumber(info.rate)} $_to'),
            const SizedBox(height: 4),
            Text(
              info.rateDate == null
                  ? 'Mata uang sama, tanpa kurs.'
                  : 'Tanggal kurs: ${formatRateDate(info.rateDate!)}'
                        '${info.fromCache ? ' (dari cache, internet tidak terjangkau)' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: info.fromCache ? AppColors.danger : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
