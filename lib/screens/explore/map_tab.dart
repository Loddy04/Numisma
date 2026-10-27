// screens/explore/map_tab.dart
// Tab Peta di Jelajah (LBS, NUMISMA_GUIDE 7.5): posisi pengguna dari GPS,
// penanda acara milik pengguna yang punya titik lokasi, dan daftar acara
// terurut dari yang TERDEKAT lengkap dengan jaraknya. Mengetuk penanda atau
// baris membuka detail acara; tombol Rute membuka Google Maps.
//
// GPS di dalam ruangan bisa lemah, jadi pengguna dapat menekan lama pada peta
// untuk menetapkan LOKASI MANUAL; jarak lalu dihitung dari titik itu. Acara
// tanpa titik tidak tampil di sini (hanya di tab Acara).
//
// Tampilan: peta memenuhi layar, daftar "Terdekat dari kamu" berupa lembar
// bawah yang bisa ditarik. Atribusi OpenStreetMap ditulis di kepala lembar
// supaya selalu terlihat.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo_util.dart';
import '../../core/time_util.dart';
import '../../core/format_util.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/event_repo.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/event_map.dart';
import '../../widgets/gradient_button.dart';
import 'event_detail_screen.dart';
import 'explore_screen.dart';

class MapTab extends StatefulWidget {
  // Dipakai memuat ulang acara setiap pengguna kembali ke tab Peta.
  final TabController? tabs;
  const MapTab({super.key, this.tabs});

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
    widget.tabs?.addListener(_onTabChanged);
    _loadEvents();
    _locate();
  }

  // Karena tab ini dipertahankan hidup, acara yang ditambah, diubah, atau
  // dihapus di tab Acara tidak otomatis terlihat di sini. Karena itu acara
  // dimuat ulang setiap pengguna kembali ke tab Peta.
  void _onTabChanged() {
    final tabs = widget.tabs;
    if (tabs != null && !tabs.indexIsChanging && tabs.index == 0) {
      _loadEvents();
    }
  }

  @override
  void dispose() {
    widget.tabs?.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  // Segarkan manual (tombol): acara dimuat ulang, dan posisi GPS diambil lagi
  // kecuali pengguna sedang memakai lokasi manual.
  Future<void> _refresh() async {
    await _loadEvents();
    if (!_manual) await _locate();
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

  // Membuka Google Maps dengan petunjuk arah ke titik acara (Maps URLs).
  // Rute dimulai dari posisi yang sedang dipakai aplikasi (GPS atau lokasi
  // manual); bila belum ada, dicoba mengambil GPS sebentar. Tanpa posisi
  // sama sekali, Google Maps yang menentukan titik awalnya.
  Future<void> _openRoute(Event e) async {
    var origin = _position;
    if (origin == null) {
      try {
        origin = await _location.currentPosition();
      } catch (_) {}
    }
    final uri = routeUri(
      destLat: e.lat!,
      destLng: e.lng!,
      originLat: origin?.lat,
      originLng: origin?.lng,
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('Tidak bisa membuka Google Maps.');
    } catch (_) {
      if (mounted) _snack('Tidak bisa membuka Google Maps.');
    }
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
      if (_position != null) userMarker(LatLng(_position!.lat, _position!.lng)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // wajib untuk AutomaticKeepAliveClientMixin
    final top = MediaQuery.of(context).padding.top + ExploreScreen.headerHeight;
    return Stack(
      children: [
        Positioned.fill(
          child: EventMap(
            controller: _controller,
            center: _initialCenter,
            zoom: 13,
            markers: _markers(),
            showAttribution: false,
            onLongPress: _setManual,
            onReady: () {
              _mapReady = true;
              final pending = _pendingCenter;
              if (pending != null) _controller.move(pending, 14);
            },
          ),
        ),
        // Petunjuk atau status lokasi manual, di bawah kepala melayang.
        Positioned(top: top, left: 20, child: _hintChip()),
        Positioned(
          top: top,
          right: 20,
          child: Column(
            children: [
              _roundButton(
                icon: Icons.refresh,
                tooltip: 'Segarkan peta',
                onTap: _refresh,
              ),
              const SizedBox(height: 10),
              _roundButton(
                icon: Icons.my_location,
                tooltip: 'Lokasi saya',
                onTap: _locating ? null : _locate,
                loading: _locating,
              ),
            ],
          ),
        ),
        _sheet(),
      ],
    );
  }

  Widget _hintChip() {
    final manual = _manual;
    return Material(
      color: AppColors.card,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: manual ? _locate : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (manual) ...[
                const Icon(Icons.pin_drop, size: 16, color: AppColors.bronze),
                const SizedBox(width: 6),
              ],
              Text(
                manual
                    ? 'Lokasi manual · pakai GPS'
                    : 'Tekan lama pada peta untuk lokasi manual',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.card,
        elevation: 3,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: AppColors.bronze),
          ),
        ),
      ),
    );
  }

  // Lembar bawah yang bisa ditarik: judul, status GPS, atribusi OSM, dan daftar
  // acara terdekat.
  Widget _sheet() {
    final pos = _position;
    // Dengan posisi: urut terdekat. Tanpa posisi: urut waktu acara (urutan
    // dari repo), tanpa jarak.
    final rows = pos != null
        ? sortByDistance(_list, pos.lat, pos.lng)
        : [
            for (final e in _list)
              if (e.hasPoint) EventDistance(e, double.nan),
          ];
    final status = _manual
        ? 'Lokasi manual'
        : (pos != null ? 'GPS aktif' : 'GPS belum tersedia');

    return DraggableScrollableSheet(
      initialChildSize: 0.40,
      minChildSize: 0.16,
      maxChildSize: 0.85,
      snap: true,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.creamTop,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.heroDark.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      pos == null ? 'Acara bertitik' : 'Terdekat dari kamu',
                      style: AppText.serif(size: 26, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.ink.withValues(alpha: 0.4),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _errorBanner(),
              ],
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Belum ada acara bertitik. Tambahkan lokasi di peta saat '
                    'membuat atau mengubah acara.',
                    style: TextStyle(
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
                  ),
                )
              else
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _row(rows[i]),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _errorBanner() {
    final forever = _error == LocationService.errDeniedForever;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12))),
          TextButton(
            onPressed: forever ? _location.openAppSettings : _locate,
            child: Text(forever ? 'Pengaturan' : 'Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _row(EventDistance r) {
    final e = r.event;
    final local = toZone(e.startUtc, zoneWib);
    final when =
        '${local.day} ${monthNamesId[local.month - 1]} · '
        '${formatZoneTime(e.startUtc, zoneWib)} '
        '${zoneAbbreviation(e.startUtc, zoneWib)}'
        '${(e.location ?? '').trim().isEmpty ? '' : ' · ${e.location!.trim()}'}';
    return InkWell(
      onTap: () => _openDetail(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    when,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (!r.meters.isNaN) ...[
              const SizedBox(width: 8),
              Text(
                formatDistance(r.meters),
                style: const TextStyle(fontSize: 15, color: AppColors.bronze),
              ),
            ],
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: GradientButton(
                label: 'Rute',
                icon: Icons.navigation_outlined,
                height: 44,
                onPressed: () => _openRoute(e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
