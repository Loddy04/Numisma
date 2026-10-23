// widgets/event_map.dart
// Peta OpenStreetMap yang dipakai bersama oleh tab Peta di Jelajah dan layar
// pemilih lokasi acara (NUMISMA_GUIDE 7.5), plus penanda-penandanya. Satu
// komponen supaya pengaturan ubin dan atribusi OSM tidak ditulis dua kali.
//
// Ketentuan OSM: ubin publik hanya untuk skala kecil, wajib menyertakan
// userAgentPackageName (id aplikasi) dan atribusi "© OpenStreetMap
// contributors". Ubin butuh internet; tanpa internet peta tampil abu-abu,
// tetapi penanda dan daftar tetap bekerja.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

// Pusat peta bila belum ada posisi maupun acara bertitik: Yogyakarta.
const jogjaCenter = LatLng(-7.7956, 110.3695);

class EventMap extends StatelessWidget {
  final MapController controller;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<LatLng>? onLongPress;
  final VoidCallback? onReady;

  const EventMap({
    super.key,
    required this.controller,
    required this.center,
    required this.zoom,
    required this.markers,
    this.onTap,
    this.onLongPress,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3,
        maxZoom: 18,
        onTap: onTap == null ? null : (_, point) => onTap!(point),
        onLongPress: onLongPress == null
            ? null
            : (_, point) => onLongPress!(point),
        onMapReady: onReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.numisma.app',
        ),
        MarkerLayer(markers: markers),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

// Posisi pengguna: titik biru berbingkai putih.
Marker userMarker(LatLng point) => Marker(
  point: point,
  width: 26,
  height: 26,
  child: Container(
    decoration: BoxDecoration(
      color: Colors.blue,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
  ),
);

// Penanda acara berbentuk pin. `alignment: topCenter` menaruh pin DI ATAS
// titiknya, jadi ujung pin tepat di koordinat. `small` (abu-abu) untuk acara
// lain di pemilih lokasi (hanya tampilan); `highlight` (merah marun) untuk
// titik yang sedang dipilih.
Marker eventMarker(
  LatLng point, {
  VoidCallback? onTap,
  bool highlight = false,
  bool small = false,
}) {
  final size = small ? 26.0 : 42.0;
  final color = highlight
      ? AppColors.maroon
      : (small ? Colors.grey : AppColors.bronze);
  return Marker(
    point: point,
    width: size,
    height: size,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap: onTap,
      child: Icon(Icons.location_on, color: color, size: size),
    ),
  );
}
