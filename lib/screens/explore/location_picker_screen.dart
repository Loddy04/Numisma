// screens/explore/location_picker_screen.dart
// Layar memilih titik lokasi acara di peta (NUMISMA_GUIDE 7.5, butir 6).
// Pengguna mengetuk satu titik; acara lain yang sudah bertitik tampil sebagai
// pin abu-abu kecil (hanya tampilan, tidak bisa diketuk), titik terpilih
// tampil mencolok. Nama tempat tetap diketik manual di form (tanpa pencarian
// alamat). Titik opsional: bisa dihapus lewat "Hapus titik".
//
// Hasil lewat Navigator.pop: PickResult(point) = pakai titik ini,
// PickResult(null) = hapus titik, null (kembali tanpa memilih) = tidak berubah.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/event.dart';
import '../../services/location_service.dart';
import '../../widgets/event_map.dart';

class PickResult {
  final LatLng? point; // null = titik dihapus
  const PickResult(this.point);
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial; // titik acara yang sedang diubah, bila ada
  final List<Event> others; // acara lain (yang bertitik tampil abu-abu)

  const LocationPickerScreen({super.key, this.initial, this.others = const []});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _controller = MapController();
  final _location = LocationService();

  LatLng? _selected;
  bool _mapReady = false;
  LatLng? _pendingCenter; // posisi GPS yang tiba sebelum peta siap

  // Pusat awal: titik acara ini, atau acara bertitik pertama, atau Jogja.
  LatLng get _startCenter {
    if (widget.initial != null) return widget.initial!;
    for (final e in widget.others) {
      if (e.hasPoint) return LatLng(e.lat!, e.lng!);
    }
    return jogjaCenter;
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    // Acara baru belum punya titik: coba pusatkan peta ke posisi pengguna.
    // Gagal tidak apa-apa (diam), pengguna tetap bisa menggeser peta sendiri.
    if (widget.initial == null) _centerOnMe(silent: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point) {
    if (_mapReady) {
      _controller.move(point, 16);
    } else {
      _pendingCenter = point;
    }
  }

  Future<void> _centerOnMe({bool silent = false}) async {
    try {
      final p = await _location.currentPosition();
      if (!mounted) return;
      _moveTo(LatLng(p.lat, p.lng));
    } on LocationException catch (e) {
      if (!silent && mounted) _snack(e.message);
    } catch (_) {
      if (!silent && mounted) _snack(LocationService.errNoFix);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<Marker> _markers() {
    return [
      for (final e in widget.others)
        if (e.hasPoint) eventMarker(LatLng(e.lat!, e.lng!), small: true),
      if (_selected != null) eventMarker(_selected!, highlight: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih lokasi'),
        actions: [
          IconButton(
            tooltip: 'Lokasi saya',
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnMe,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: EventMap(
              controller: _controller,
              center: _startCenter,
              zoom: widget.initial != null ? 16 : 13,
              markers: _markers(),
              onTap: (p) => setState(() => _selected = p),
              onReady: () {
                _mapReady = true;
                final pending = _pendingCenter;
                if (pending != null) _controller.move(pending, 16);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selected == null
                        ? 'Ketuk peta untuk memilih titik lokasi.'
                        : 'Titik: ${selected.latitude.toStringAsFixed(5)}, '
                              '${selected.longitude.toStringAsFixed(5)}',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (widget.initial != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(const PickResult(null)),
                            child: const Text('Hapus titik'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selected == null
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(PickResult(selected)),
                          child: const Text('Pakai lokasi ini'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
