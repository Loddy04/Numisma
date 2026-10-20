// screens/collection/collection_screen.dart
// Daftar koleksi milik pengguna yang sedang login, lengkap dengan
// pencarian, filter, urutan, dan multi-pilih (K11, NUMISMA_GUIDE
// Bagian 7.11). Data dimuat ulang dari CoinRepo setiap layar dibuka,
// setiap kali kembali dari form/detail, dan setiap pencarian/filter
// berubah (Bagian 4.4: setState + muat ulang).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/coin.dart';
import '../../services/auth_service.dart';
import '../../services/coin_repo.dart';
import '../../theme.dart';
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
  }

  void _clearSelection() => setState(_selected.clear);

  // Ruang untuk "total nilai nominal setara" dari koin terpilih
  // (Bagian 7.11). Nilainya butuh kurs, jadi baru diisi di Hari 3
  // lewat RatesService.convert; selama null, baris ini tidak tampil.
  String? _selectedValueLabel() => null;

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus koin'),
        content: Text('$count koin terpilih akan dihapus. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;

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

  Widget _thumbnail(Coin coin) {
    const size = 56.0;
    final path = coin.photoPath;
    // Foto bisa tidak ada (koin tanpa foto, atau hasil Pulihkan nanti);
    // errorBuilder menjaga tampilan tetap rapi, bukan crash.
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(
        coin.type == 'banknote' ? Icons.payments : Icons.monetization_on,
        color: AppColors.bronze,
      ),
    );
    if (path == null) return fallback;
    return ClipOval(
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
    if (!_selecting) return AppBar(title: const Text('Koleksi'));

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
          icon: const Icon(Icons.delete),
          tooltip: 'Hapus yang dipilih',
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari negara, nominal, atau tahun',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
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
          IconButton(
            tooltip: 'Filter dan urutan',
            onPressed: _openFilter,
            icon: Badge(
              isLabelVisible: _filters.isActive,
              smallSize: 8,
              child: const Icon(Icons.tune),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            searching
                ? 'Tidak ada koin yang cocok.'
                : 'Koleksi masih kosong.\nTekan tombol Tambah untuk mencatat koin pertamamu.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      itemCount: _coins.length,
      itemBuilder: (context, i) {
        final coin = _coins[i];
        final selected = _selected.contains(coin.id);
        final jenis = coin.type == 'banknote' ? 'Uang kertas' : 'Koin';
        final detail = [
          jenis,
          if (coin.year != null) '${coin.year}',
          if (coin.condition != null) coin.condition!,
        ].join(' • ');
        return Card(
          color: selected ? AppColors.gold.withValues(alpha: 0.35) : null,
          child: ListTile(
            leading: _thumbnail(coin),
            title: Text(
              '${coin.denominationLabel} ${coin.currencyCode} — ${coin.country}',
            ),
            subtitle: Text(detail),
            trailing: _selecting
                ? Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: AppColors.bronze,
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _onTap(coin),
            // Tekan lama = masuk mode pilih dan langsung memilih koin ini.
            onLongPress: () => _toggle(coin.id),
          ),
        );
      },
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
