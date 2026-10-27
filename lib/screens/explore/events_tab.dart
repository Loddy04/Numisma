// screens/explore/events_tab.dart
// Tab Acara di Jelajah (NUMISMA_GUIDE 7.5): daftar acara kolektor milik akun
// yang login, tombol tambah, ringkasan pengingat, dan uji notifikasi. Isinya
// dipindahkan dari tab Jam Dunia (Jam Dunia di Konversi tinggal jamnya).
// Zona waktu tiap kartu dipilih sendiri (WIB, WITA, WIT, London). Mengetuk
// kartu membuka layar detail; ubah dan hapus ada di sana.

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/event_repo.dart';
import '../../services/notif_service.dart';
import '../../theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/world_clock_card.dart';
import '../../widgets/zone_picker.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'explore_screen.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _authService = AuthService();
  final _events = EventRepo();
  final _notif = NotifService();

  // Zona tiap kartu acara (kunci = id acara). Kartu yang belum pernah
  // dipilih memakai WIB.
  final Map<int, String> _eventZone = {};

  int? _userId;
  List<Event> _list = [];
  // id acara -> waktu pengingat (UTC), untuk ringkasan di kartu.
  Map<int, DateTime> _reminders = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
    // Kepala melayang (tombol kembali + tab) dipasang ExploreScreen di atas
    // daftar ini, jadi daftar dimulai di bawahnya.
    final top = MediaQuery.of(context).padding.top + ExploreScreen.headerHeight;
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.page),
      child: RefreshIndicator(
        onRefresh: _loadEvents,
        edgeOffset: top,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, top + 4, 20, 32),
          children: [
            // Jam dunia di atas daftar, supaya waktu acara mudah dibandingkan
            // dengan waktu sekarang di tiap zona.
            const WorldClockCard(),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Acara kolektor',
                    style: AppText.serif(size: 24, weight: FontWeight.w700),
                  ),
                ),
                Material(
                  color: AppColors.card,
                  shape: const StadiumBorder(
                    side: BorderSide(color: AppColors.cardBorder),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _userId == null ? null : _openForm,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: AppColors.bronze),
                          SizedBox(width: 4),
                          Text(
                            'Tambah acara',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.bronze,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada acara.',
                  style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6)),
                ),
              )
            else
              for (final e in _list) _eventCard(e),
            const SizedBox(height: 14),
            _testSection(),
          ],
        ),
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
    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Uji notifikasi', style: TextStyle(fontSize: 17)),
            const SizedBox(height: 2),
            Text(
              'Untuk memastikan notifikasi berfungsi di HP ini.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.ink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _testNow,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Kirim sekarang'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _testIn10s,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Uji dalam 10 detik'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ringkasan pengingat di kartu (aksinya ada di layar detail): ikon lonceng
  // + "N menit sebelum" bila pengingat masih berlaku, atau "Pengingat sudah
  // lewat". Acara yang sudah mulai atau tanpa pengingat: tidak ada apa-apa.
  Widget _reminderInfo(Event e, DateTime nowUtc) {
    final remindAt = _reminders[e.id];
    if (remindAt == null || !e.startUtc.isAfter(nowUtc)) {
      return const SizedBox.shrink();
    }
    final active = remindAt.isAfter(nowUtc);
    final before = formatDuration(e.startUtc.difference(remindAt));
    final color = active ? AppColors.bronze : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Pengingat: $before sebelum' : 'Pengingat sudah lewat',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Event e) {
    final nowUtc = DateTime.now().toUtc();
    final zone = _eventZone[e.id] ?? zoneWib;
    final past = e.startUtc.isBefore(nowUtc);
    final muted = AppColors.ink.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.all(18),
        onTap: () => _openDetail(e),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                style: AppText.serif(
                  size: 21,
                  weight: FontWeight.w700,
                  color: past ? Colors.grey : AppColors.ink,
                ),
              ),
              if (e.location != null || e.hasPoint)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      // Pin kecil menandai acara yang punya titik di peta.
                      if (e.hasPoint)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.bronze,
                          ),
                        ),
                      if (e.location != null)
                        Expanded(
                          child: Text(
                            e.location!,
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                        ),
                    ],
                  ),
                ),
              if (past)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Sudah lewat',
                    style: TextStyle(fontSize: 13, color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 10),
              // Waktu mulai di zona yang dipilih untuk kartu ini saja.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatZoneTime(e.startUtc, zone),
                    style: AppText.serif(
                      size: 36,
                      weight: FontWeight.w700,
                      color: AppColors.bronze,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${formatZoneDate(e.startUtc, zone)} · '
                    '${zoneAbbreviation(e.startUtc, zone)}',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                ],
              ),
              _reminderInfo(e, nowUtc),
              const SizedBox(height: 12),
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
