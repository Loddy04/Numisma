// screens/convert/world_clock_tab.dart
// Tab "Jam Dunia" (NUMISMA_GUIDE Bagian 7.7b): satu jam yang berdetak tiap
// detik, dan daftar acara kolektor milik akun yang login. Zona waktu jam dan
// zona tiap kartu acara dipilih sendiri oleh pengguna (WIB, WITA, WIT, London),
// jadi layar tidak penuh menampilkan semua zona sekaligus. Mengetuk kartu
// membuka layar detail; hapus dan ubah ada di sana, bukan di kartu.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/event_repo.dart';
import '../../services/notif_service.dart';
import '../../theme.dart';
import '../../widgets/zone_picker.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

class WorldClockTab extends StatefulWidget {
  const WorldClockTab({super.key});

  @override
  State<WorldClockTab> createState() => _WorldClockTabState();
}

class _WorldClockTabState extends State<WorldClockTab> {
  final _authService = AuthService();
  final _events = EventRepo();
  final _notif = NotifService();
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();

  // Zona jam utama, dan zona tiap kartu acara (kunci = id acara). Kartu
  // yang belum pernah dipilih memakai WIB.
  String _clockZone = zoneWib;
  final Map<int, String> _eventZone = {};

  int? _userId;
  List<Event> _list = [];
  // id acara -> waktu pengingat (UTC), untuk ringkasan di kartu.
  Map<int, DateTime> _reminders = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Satu timer cukup: setiap detik hanya memperbarui "sekarang", lalu
    // jam menghitung ulang dari nilai itu.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
    _loadEvents();
  }

  @override
  void dispose() {
    // Wajib dibatalkan, kalau tidak timer terus jalan setelah tab ditutup.
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      // Acara milik akun yang sedang login; session adalah sumber kebenaran
      // siapa penggunanya (sama seperti layar Koleksi).
      final user = await _authService.currentUser();
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final list = await _events.list(user.id!);
      final reminders = await _notif.reminderMap();
      if (!mounted) return;
      setState(() {
        _userId = user.id;
        _list = list;
        _reminders = reminders;
        // Lupakan pilihan zona acara yang sudah terhapus.
        _eventZone.removeWhere((id, _) => !list.any((e) => e.id == id));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat daftar acara.')),
      );
    }
  }

  Future<void> _openForm() async {
    final userId = _userId;
    if (userId == null) return;
    final result = await Navigator.of(context).push<EventFormResult>(
      MaterialPageRoute(builder: (_) => EventFormScreen(userId: userId)),
    );
    if (result == EventFormResult.saved) _loadEvents();
  }

  // Detail bisa mengubah atau menghapus acara, jadi daftar selalu dimuat
  // ulang saat kembali.
  Future<void> _openDetail(Event e) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id)),
    );
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _clockCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Acara kolektor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _userId == null ? null : _openForm,
                icon: const Icon(Icons.add),
                label: const Text('Tambah acara'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_list.isEmpty)
            const Text('Belum ada acara.')
          else
            for (final e in _list) _eventCard(e),
          const SizedBox(height: 16),
          _testSection(),
        ],
      ),
    );
  }

  // --- Uji notifikasi (khusus demo, Bagian 7.12) -------------------------

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _testNow() async {
    try {
      await _notif.showTestNow();
    } on NotifException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Gagal menampilkan notifikasi uji.');
    }
  }

  // Memakai jalur penjadwalan yang sama dengan pengingat acara: tutup
  // aplikasi setelah menekan tombol ini untuk membuktikan notifikasi tetap
  // muncul walau aplikasi mati.
  Future<void> _testIn10s() async {
    try {
      final exact = await _notif.showTestIn(const Duration(seconds: 10));
      if (!mounted) return;
      _snack(
        exact
            ? 'Notifikasi muncul dalam 10 detik. Coba tutup aplikasinya.'
            : 'Notifikasi muncul dalam sekitar 10 detik, bisa terlambat '
                  'karena izin alarm eksak belum aktif.',
      );
    } on NotifException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Gagal menjadwalkan notifikasi uji.');
    }
  }

  Widget _testSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uji notifikasi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Untuk memastikan notifikasi berfungsi di HP ini.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _testNow,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Kirim sekarang'),
                ),
                OutlinedButton.icon(
                  onPressed: _testIn10s,
                  icon: const Icon(Icons.timer),
                  label: const Text('Uji dalam 10 detik'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clockCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              formatClock(_nowUtc, _clockZone),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: AppColors.bronze,
              ),
            ),
            const SizedBox(height: 4),
            // Tanggal ikut tampil: dekat tengah malam, zona berbeda bisa
            // berada di hari yang berbeda.
            Text(
              '${formatZoneDate(_nowUtc, _clockZone)} · '
              '${zoneAbbreviation(_nowUtc, _clockZone)}',
            ),
            const SizedBox(height: 12),
            ZonePicker(
              selected: _clockZone,
              onSelected: (z) => setState(() => _clockZone = z),
            ),
          ],
        ),
      ),
    );
  }

  // Ringkasan pengingat di kartu (aksinya ada di layar detail): ikon lonceng
  // + "N menit sebelum" bila pengingat masih berlaku, atau "Pengingat sudah
  // lewat". Acara yang sudah mulai atau tanpa pengingat: tidak ada apa-apa.
  Widget _reminderInfo(Event e) {
    final remindAt = _reminders[e.id];
    if (remindAt == null || !e.startUtc.isAfter(_nowUtc)) {
      return const SizedBox.shrink();
    }
    final active = remindAt.isAfter(_nowUtc);
    final before = formatDuration(e.startUtc.difference(remindAt));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            active ? Icons.notifications_active : Icons.notifications_off,
            size: 16,
            color: active ? AppColors.bronze : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            active ? 'Pengingat: $before sebelum' : 'Pengingat sudah lewat',
            style: TextStyle(
              fontSize: 12,
              color: active ? AppColors.bronze : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Event e) {
    final zone = _eventZone[e.id] ?? zoneWib;
    final past = e.startUtc.isBefore(_nowUtc);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Clip supaya efek ketukan mengikuti sudut membulat kartu.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(e),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: past ? Colors.grey : AppColors.textDark,
                ),
              ),
              if (e.location != null)
                Text(e.location!, style: const TextStyle(fontSize: 12)),
              if (past)
                const Text(
                  'Sudah lewat',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              const SizedBox(height: 8),
              // Waktu mulai di zona yang dipilih untuk kartu ini saja.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatZoneTime(e.startUtc, zone),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bronze,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${formatZoneDate(e.startUtc, zone)} · '
                    '${zoneAbbreviation(e.startUtc, zone)}',
                  ),
                ],
              ),
              _reminderInfo(e),
              const SizedBox(height: 8),
              ZonePicker(
                selected: zone,
                onSelected: (z) => setState(() => _eventZone[e.id] = z),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
