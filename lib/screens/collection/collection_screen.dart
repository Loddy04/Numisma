// screens/collection/collection_screen.dart
// Daftar koleksi milik pengguna yang sedang login, lengkap dengan
// pencarian, filter, urutan, dan multi-pilih (K11, NUMISMA_GUIDE
// Bagian 7.11). Data dimuat ulang dari CoinRepo setiap layar dibuka,
// setiap kali kembali dari form/detail, dan setiap pencarian/filter
// berubah (Bagian 4.4: setState + muat ulang).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../models/coin.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../services/rates_service.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/field_label.dart';
import '../../widgets/soft_card.dart';
import 'coin_detail_screen.dart';
import 'coin_form_screen.dart';
import 'collection_filter_sheet.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _authService = AuthService();
  final _repo = CoinRepo();
  final _searchController = TextEditingController();


  int? _userId;
  List<Coin> _coins = [];
  bool _loading = true;

  String _query = '';
  CoinFilters _filters = const CoinFilters();
  Timer? _debounce;

  // Setiap _load() diberi nomor. Kalau ada pemuatan lebih baru yang
  // sudah dimulai, hasil pemuatan lama dibuang, supaya ketikan cepat
  // tidak membuat daftar "melompat" ke hasil yang sudah usang.
  int _loadId = 0;

  // ID koin yang sedang dipilih. Tidak kosong = mode multi-pilih aktif.
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  final _rates = RatesService();
  String? _selectedValueText; // null = belum dihitung / tidak ada pilihan
  int _valueNo = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final myLoad = ++_loadId;
    try {
      // Layar tidak menerima userId lewat konstruktor; ia bertanya ke
      // AuthService siapa yang sedang login (sumber kebenarannya session).
      final user = await _authService.currentUser();
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final coins = await _repo.list(
        user.id!,
        query: _query,
        type: _filters.type,
        condition: _filters.condition,
        yearFrom: _filters.yearFrom,
        yearTo: _filters.yearTo,
        sort: _filters.sort,
      );
      if (!mounted || myLoad != _loadId) return;
      setState(() {
        _userId = user.id;
        _coins = coins;
        _loading = false;
        // Buang pilihan untuk koin yang tidak lagi tampil di daftar.
        final visible = coins.map((c) => c.id).toSet();
        _selected.removeWhere((id) => !visible.contains(id));
      });
      _refreshSelectedValue();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat koleksi, coba lagi.')),
      );
    }
  }

  // Menunda pencarian 300 ms setelah ketikan terakhir, supaya tidak
  // menanyai database di setiap huruf.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = text;
      _load();
    });
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<CoinFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CollectionFilterSheet(initial: _filters),
    );
    if (result == null) return;
    setState(() => _filters = result);
    _load();
  }

  Future<void> _openForm() async {
    if (_userId == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CoinFormScreen(userId: _userId!)),
    );
    _load();
  }

  Future<void> _openDetail(Coin coin) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CoinDetailScreen(coinId: coin.id)),
    );
    _load();
  }

  // --- Multi-pilih ----------------------------------------------------

  // Ketuk: di mode pilih = centang/lepas, di mode biasa = buka detail.
  void _onTap(Coin coin) {
    if (_selecting) {
      _toggle(coin.id);
    } else {
      _openDetail(coin);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
    _refreshSelectedValue();
  }

  void _clearSelection() {
    setState(_selected.clear);
    _refreshSelectedValue();
  }

  // "Total nilai nominal setara" koin terpilih dalam IDR (Bagian 7.11).
  // Dihitung ulang setiap pilihan berubah; kurs sudah di-cache sehingga
  // ketukan berikutnya hampir seketika. Nomor permintaan membuang hasil
  // lama bila pengguna mengetuk cepat.
  Future<void> _refreshSelectedValue() async {
    final myNo = ++_valueNo;
    if (_selected.isEmpty) {
      if (_selectedValueText != null) {
        setState(() => _selectedValueText = null);
      }
      return;
    }
    final chosen = _coins.where((c) => _selected.contains(c.id)).toList();
    final result = await _rates.valueOfCoins(chosen, 'IDR');
    if (!mounted || myNo != _valueNo) return;
    final text = result.counted == 0
        ? 'Nilai nominal setara: tidak tersedia'
        : 'Nilai nominal setara: ${formatNumber(result.total)} IDR'
              '${result.skipped > 0 ? ' (${result.skipped} koin tak dihitung)' : ''}';
    setState(() => _selectedValueText = text);
  }

  String? _selectedValueLabel() => _selectedValueText;

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final yakin = await confirmDialog(
      context,
      title: 'Hapus koin?',
      message: '$count koin terpilih akan dihapus. Lanjutkan?',
    );
    if (!yakin) return;

    try {
      // Salinan daftar, karena _selected akan berubah saat _load() jalan.
      for (final id in List<String>.from(_selected)) {
        await _repo.delete(id);
      }
      _selected.clear();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus, coba lagi.')),
      );
      _load();
    }
  }

  // --- Tampilan -------------------------------------------------------

  // Foto koin dalam kotak bersudut bulat. Tanpa foto (atau file hilang):
  // kotak emas bergradasi berisi nominalnya, supaya daftar tetap rapi.
  Widget _thumbnail(Coin coin) {
    const size = 64.0;
    final radius = BorderRadius.circular(16);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBD8AE), AppColors.gold],
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FittedBox(
          child: Text(
            coin.denominationLabel,
            style: AppText.serif(
              size: 22,
              weight: FontWeight.w700,
              color: AppColors.heroDark,
            ),
          ),
        ),
      ),
    );
    final path = coin.photoPath;
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (!_selecting) {
      return AppBar(
      );
    }

    final valueLabel = _selectedValueLabel();
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Batalkan pilihan',
        onPressed: _clearSelection,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_selected.length} dipilih'),
          if (valueLabel != null)
            Text(valueLabel, style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Hapus yang dipilih',
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  // Judul besar, ringkasan jumlah, dan chip total item.
  Widget _buildHeader() {
    final coins = _coins.where((c) => c.type == 'coin').length;
    final notes = _coins.length - coins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koleksi',
                  style: AppText.serif(size: 36, weight: FontWeight.w700),
                ),
                Text(
                  '$coins koin · $notes uang kertas',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tileActive,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_coins.length} item',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.bronze,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: appInput(
                hint: 'Cari negara, nominal, tahun',
                icon: Icons.search,
                radius: 30,
                suffix: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _query = '';
                          setState(() {});
                          _load();
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter lanjutan (jenis, kondisi, tahun, urutan) tetap lewat lembar
          // filter yang sama.
          Material(
            color: AppColors.card,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.cardBorder),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openFilter,
              child: SizedBox(
                width: 52,
                height: 52,
                // Center wajib: tanpa itu Badge meregang mengisi kotak 52x52
                // dan ikonnya menempel di pojok kiri atas, bukan di tengah.
                child: Center(
                  child: Badge(
                    isLabelVisible: _filters.isActive,
                    smallSize: 10,
                    // Titik penanda filter aktif berwarna cokelat tema. Warna
                    // bawaan Badge merah (warna "galat").
                    backgroundColor: AppColors.bronze,
                    child: const Icon(Icons.tune, color: AppColors.bronze),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_coins.isEmpty) {
      // Dua pesan berbeda: koleksi memang kosong, atau pencarian/filter
      // tidak menemukan apa pun.
      final searching = _query.trim().isNotEmpty || _filters.isFiltering;
      // ListView (bukan Center) supaya keadaan kosong pun bisa ditarik
      // untuk menyegarkan.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.brown,
                  boxShadow: AppShadows.soft,
                ),
                child: Icon(
                  searching ? Icons.search_off : Icons.collections_bookmark,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              searching ? 'Tidak ada yang cocok' : 'Koleksi masih kosong',
              textAlign: TextAlign.center,
              style: AppText.serif(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Coba ubah kata kunci atau filternya.'
                  : 'Tekan tombol Tambah untuk mencatat koin pertamamu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        itemCount: _coins.length,
        itemBuilder: (context, i) {
          final coin = _coins[i];
          final selected = _selected.contains(coin.id);
          final detail = [
            coin.country,
            if (coin.year != null) '${coin.year}',
            if (coin.condition != null) coin.condition!,
          ].join(' · ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              color: selected ? AppColors.tileActive : null,
              padding: const EdgeInsets.all(10),
              onTap: () => _onTap(coin),
              child: GestureDetector(
                // Tekan lama = masuk mode pilih dan langsung memilih koin ini.
                onLongPress: () => _toggle(coin.id),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    _thumbnail(coin),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${coin.denominationLabel} ${coin.currencyCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.serif(
                              size: 19,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
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
                    Icon(
                      _selecting
                          ? (selected
                                ? Icons.check_circle
                                : Icons.circle_outlined)
                          : Icons.chevron_right,
                      color: _selecting ? AppColors.bronze : AppColors.ink,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: tombol Kembali saat mode pilih hanya membatalkan
    // pilihan, tidak langsung keluar dari layar Koleksi.
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildList()),
          ],
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: _openForm,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
      ),
    );
  }
}
