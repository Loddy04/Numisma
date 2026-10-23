// screens/explore/map_tab.dart
// Tab Peta di Jelajah (LBS, NUMISMA_GUIDE 7.5): posisi pengguna dari GPS,
// penanda acara milik pengguna yang punya titik lokasi, dan daftar acara
// terurut dari yang TERDEKAT lengkap dengan jaraknya. Mengetuk penanda atau
// baris membuka detail acara.
//
// GPS di dalam ruangan bisa lemah, jadi pengguna dapat menekan lama pada peta
// untuk menetapkan LOKASI MANUAL; jarak lalu dihitung dari titik itu. Acara
// tanpa titik tidak tampil di sini (hanya di tab Acara).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/event_repo.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/event_map.dart';
import '../convert/event_detail_screen.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with AutomaticKeepAliveClientMixin {
  final _auth = AuthService();
  final _events = EventRepo();
  final _location = LocationService();
  final _controller = MapController();

  List<Event> _list = [];
  GeoPoint? _position; // dari GPS atau manual
  bool _manual = false;
  bool _locating = false;
  String? _error;

  bool _mapReady = false;
  LatLng? _pendingCenter;

  // Peta dan daftar dipertahankan saat pengguna pindah ke tab Acara.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _locate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final user = await _auth.currentUser();
      if (user == null) return;
      final list = await _events.list(user.id!);
      if (!mounted) return;
      setState(() => _list = list);
    } catch (_) {
      if (!mounted) return;
      _snack('Gagal memuat acara.');
    }
  }

  // Mengambil posisi GPS. Dipakai saat tab dibuka, tombol "Lokasi saya", dan
  // "Coba lagi". Memakai GPS membatalkan lokasi manual.
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
      _manual = false;
    });
    try {
      final p = await _location.currentPosition();
      if (!mounted || _manual) return;
      setState(() {
        _position = p;
        _locating = false;
      });
      _moveTo(LatLng(p.lat, p.lng));
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = LocationService.errNoFix;
        _locating = false;
      });
    }
  }

  void _setManual(LatLng point) {
    setState(() {
      _position = GeoPoint(point.latitude, point.longitude);
      _manual = true;
      _locating = false;
      _error = null;
    });
  }

  void _moveTo(LatLng point) {
    if (_mapReady) {
      _controller.move(point, 14);
    } else {
      _pendingCenter = point;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Detail bisa mengubah atau menghapus acara, jadi daftar dimuat ulang saat
  // kembali.
  Future<void> _openDetail(Event e) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
    );
    _loadEvents();
  }

  // Pusat awal peta: acara bertitik pertama, atau Jogja.
  LatLng get _initialCenter {
    for (final e in _list) {
      if (e.hasPoint) return LatLng(e.lat!, e.lng!);
    }
    return jogjaCenter;
  }

  List<Marker> _markers() {
    return [
      for (final e in _list)
        if (e.hasPoint)
          eventMarker(LatLng(e.lat!, e.lng!), onTap: () => _openDetail(e)),
      if (_position != null)
        userMarker(LatLng(_position!.lat, _position!.lng)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // wajib untuk AutomaticKeepAliveClientMixin
    return Column(
      children: [
        Expanded(flex: 5, child: _mapArea()),
        if (_error != null) _errorBanner(),
        Expanded(flex: 4, child: _nearbyList()),
      ],
    );
  }

  Widget _mapArea() {
    return Stack(
      children: [
        EventMap(
          controller: _controller,
          center: _initialCenter,
          zoom: 13,
          markers: _markers(),
          onLongPress: _setManual,
          onReady: () {
            _mapReady = true;
            final pending = _pendingCenter;
            if (pending != null) _controller.move(pending, 14);
          },
        ),
        if (_manual)
          Positioned(
            top: 8,
            left: 8,
            child: ActionChip(
              avatar: const Icon(Icons.pin_drop, size: 18),
              label: const Text('Lokasi manual · pakai GPS'),
              onPressed: _locate,
            ),
          ),
        Positioned(
          right: 12,
          bottom: 28,
          child: FloatingActionButton.small(
            heroTag: 'map-my-location',
            tooltip: 'Lokasi saya',
            onPressed: _locating ? null : _locate,
            child: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner() {
    final forever = _error == LocationService.errDeniedForever;
    return Material(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!, style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: forever ? _location.openAppSettings : _locate,
              child: Text(forever ? 'Pengaturan' : 'Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyList() {
    final pos = _position;
    // Dengan posisi: urut terdekat. Tanpa posisi: urut waktu acara (urutan
    // dari repo), tanpa jarak.
    final rows = pos != null
        ? sortByDistance(_list, pos.lat, pos.lng)
        : [
            for (final e in _list)
              if (e.hasPoint) EventDistance(e, double.nan),
          ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text(
          pos == null ? 'Acara bertitik' : 'Acara terdekat',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Tekan lama pada peta untuk menentukan lokasi manual.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Belum ada acara bertitik. Tambahkan lokasi di peta saat '
              'membuat atau mengubah acara.',
            ),
          )
        else
          for (final r in rows) _row(r),
      ],
    );
  }

  Widget _row(EventDistance r) {
    final e = r.event;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _openDetail(e),
        leading: const Icon(Icons.location_on, color: AppColors.bronze),
        title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (e.location != null) e.location!,
            formatZone(e.startUtc, zoneWib),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: r.meters.isNaN
            ? null
            : Text(
                formatDistance(r.meters),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.bronze,
                ),
              ),
      ),
    );
  }
}
