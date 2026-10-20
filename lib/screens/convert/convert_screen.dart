// screens/convert/convert_screen.dart
// Menu Konversi (NUMISMA_GUIDE Bagian 7.7). Dua tab: Kurs (sekarang) dan
// Jam Dunia (Hari 3 berikutnya, masih placeholder). Layar tidak memanggil
// HTTP/database langsung: semuanya lewat RatesService (aturan Bagian 4.1).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/rates_service.dart';
import '../../theme.dart';
import '../../widgets/currency_picker.dart';

class ConvertScreen extends StatelessWidget {
  const ConvertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konversi'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Kurs'), Tab(text: 'Jam Dunia')],
          ),
        ),
        body: const TabBarView(
          children: [
            _KursTab(),
            Center(child: Text('Jam Dunia — segera hadir')),
          ],
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

class _KursTabState extends State<_KursTab>
    with AutomaticKeepAliveClientMixin {
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

  Future<void> _recalculate() async {
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
      final info = await _service.getRateInfo(_from, _to);
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
    return ListView(
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

// Format angka gaya Indonesia: titik pemisah ribuan, koma desimal.
// Jumlah desimal menyesuaikan besar angka supaya kurs kecil (0,008781)
// tidak tampil "0,00".
String formatNumber(double value) {
  final abs = value.abs();
  final decimals = abs >= 100 ? 2 : (abs >= 1 ? 4 : 6);
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final negative = parts[0].startsWith('-');
  final digits = negative ? parts[0].substring(1) : parts[0];

  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  // Buang nol di belakang desimal ("113,8800" -> "113,88").
  final fraction = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return '${negative ? '-' : ''}$grouped${fraction.isEmpty ? '' : ',$fraction'}';
}

// "2026-10-20" -> "20 Okt 2026". Dibuat manual (tanpa paket intl) karena
// formatnya sederhana dan hanya dipakai di sini.
String formatRateDate(String isoDate) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return isoDate;
  return '${int.parse(parts[2])} ${months[month - 1]} ${parts[0]}';
}
