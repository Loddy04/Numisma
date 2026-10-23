// screens/explore/event_detail_screen.dart
// Detail satu acara kolektor (NUMISMA_GUIDE 0.5, Bagian 7.7b): nama, lokasi,
// waktu di satu zona pilihan, catatan, dan pengingat (Bagian 7.12). Dari
// sini pengguna mengubah atau menghapus acara, dan memasang atau
// membatalkan pengingat. Kartu daftar hanya menampilkan ringkasannya.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format_util.dart';
import '../../core/geo_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/event_repo.dart';
import '../../services/location_service.dart';
import '../../services/notif_service.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/zone_picker.dart';
import 'event_form_screen.dart';
import 'reminder_picker.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _repo = EventRepo();
  final _notif = NotifService();

  Event? _event;
  DateTime? _remindAt; // waktu pengingat (UTC); null = belum ada
  bool _loading = true;
  bool _busy = false; // sedang memasang/membatalkan pengingat
  String _zone = zoneWib;
  // Jarak dari posisi pengguna ke titik acara (meter); null = belum diketahui
  // (GPS belum siap, izin ditolak, atau acara tanpa titik).
  double? _distance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Menghitung jarak dengan GPS. Gagal tidak mengganggu: kartu lokasi tetap
  // tampil dan Rute tetap bisa dipakai (Google Maps yang mencari posisimu).
  Future<void> _loadDistance(Event event) async {
    if (!event.hasPoint) return;
    try {
      final p = await LocationService().currentPosition();
      if (!mounted) return;
      setState(
        () => _distance = distanceMeters(p.lat, p.lng, event.lat!, event.lng!),
      );
    } catch (_) {}
  }

  // Membuka Google Maps dengan petunjuk arah ke titik acara (Maps URLs).
  // Tanpa SDK dan tanpa API key; tujuan saja yang dikirim, posisi asal
  // ditentukan Google Maps sendiri.
  Future<void> _openRoute(Event event) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${event.lat},${event.lng}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('Tidak bisa membuka Google Maps.');
    } catch (_) {
      if (mounted) _snack('Tidak bisa membuka Google Maps.');
    }
  }

  Future<void> _load() async {
    try {
      final event = await _repo.getById(widget.eventId);
      if (!mounted) return;
      if (event == null) {
        // Acara sudah tidak ada (mis. terhapus): kembali ke daftar.
        Navigator.of(context).pop(true);
        return;
      }
      final reminders = await _notif.reminderMap();
      if (!mounted) return;
      setState(() {
        _event = event;
        _remindAt = reminders[event.id];
        _loading = false;
      });
      _loadDistance(event);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Gagal memuat acara, coba lagi.');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit() async {
    final event = _event;
    if (event == null) return;
    final result = await Navigator.of(context).push<EventFormResult>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(userId: event.userId, event: event),
      ),
    );
    if (!mounted) return;
    if (result == EventFormResult.deleted) {
      Navigator.of(context).pop(true); // terhapus dari form: kembali ke daftar
    } else if (result == EventFormResult.saved) {
      _load();
    }
  }

  Future<void> _delete() async {
    final event = _event;
    if (event == null) return;
    final yakin = await confirmDialog(
      context,
      title: 'Hapus acara',
      message: 'Acara "${event.title}" akan dihapus. Lanjutkan?',
    );
    if (!yakin) return;

    try {
      // Alarm dibatalkan dulu; baris acaranya (dan pengingatnya) dihapus
      // sesudahnya.
      await _notif.cancelEventReminder(event.id);
      await _repo.delete(event.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _snack('Gagal menghapus acara, coba lagi.');
    }
  }

  // --- Pengingat --------------------------------------------------------

  Future<void> _setReminder() async {
    final event = _event;
    if (event == null) return;
    final before = await pickReminderOffset(context);
    if (before == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final exact = await _notif.scheduleEventReminder(event, before);
      if (!mounted) return;
      if (!exact) {
        _snack(
          'Izin alarm eksak belum aktif, pengingat bisa terlambat beberapa menit.',
        );
      }
      await _load();
    } on NotifException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Gagal memasang pengingat, coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelReminder() async {
    final event = _event;
    if (event == null) return;
    setState(() => _busy = true);
    try {
      await _notif.cancelEventReminder(event.id);
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (mounted) _snack('Gagal membatalkan pengingat, coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail acara'),
        actions: [
          if (event != null) ...[
            IconButton(
              tooltip: 'Ubah',
              icon: const Icon(Icons.edit),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : event == null
          ? const Center(child: Text('Acara tidak ditemukan.'))
          : _buildBody(event),
    );
  }

  Widget _buildBody(Event event) {
    final past = event.startUtc.isBefore(DateTime.now().toUtc());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (event.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(event.location!)),
                    ],
                  ),
                ],
                if (past)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Sudah lewat',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: 12),
                // Waktu mulai di zona yang dipilih, sama seperti kartu daftar.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatZoneTime(event.startUtc, _zone),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.bronze,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatZoneDate(event.startUtc, _zone)} · '
                      '${zoneAbbreviation(event.startUtc, _zone)}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ZonePicker(
                  selected: _zone,
                  onSelected: (z) => setState(() => _zone = z),
                ),
              ],
            ),
          ),
        ),
        if (event.hasPoint) ...[
          const SizedBox(height: 12),
          _locationCard(event),
        ],
        const SizedBox(height: 12),
        _reminderCard(event),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catatan',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(event.note ?? 'Tidak ada catatan.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Kartu lokasi (hanya untuk acara bertitik): koordinat, jarak dari
  // posisimu bila sudah diketahui, dan tombol Rute.
  Widget _locationCard(Event event) {
    final distance = _distance;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lokasi di peta',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              '${event.lat!.toStringAsFixed(5)}, '
              '${event.lng!.toStringAsFixed(5)}',
            ),
            if (distance != null) ...[
              const SizedBox(height: 4),
              Text(
                '${formatDistance(distance)} dari posisimu',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.bronze,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openRoute(event),
              icon: const Icon(Icons.directions),
              label: const Text('Rute'),
            ),
          ],
        ),
      ),
    );
  }

  // Keadaan pengingat diturunkan dari waktu (baris `reminders` tidak
  // dihapus sendiri setelah notifikasi berbunyi):
  //   acara sudah mulai          -> tidak ada tombol
  //   belum ada pengingat        -> "Ingatkan saya"
  //   pengingat di masa depan    -> info + Ganti + Batalkan
  //   pengingat sudah lewat      -> "Pengingat sudah lewat" + "Ingatkan lagi"
  Widget _reminderCard(Event event) {
    final now = DateTime.now().toUtc();
    final started = !event.startUtc.isAfter(now);
    final remindAt = _remindAt;

    final String text;
    final List<Widget> actions;
    if (started) {
      text = 'Acara sudah dimulai, pengingat tidak tersedia.';
      actions = const [];
    } else if (remindAt == null) {
      text = 'Belum ada pengingat.';
      actions = [
        FilledButton.icon(
          onPressed: _busy ? null : _setReminder,
          icon: const Icon(Icons.notifications_active),
          label: const Text('Ingatkan saya'),
        ),
      ];
    } else if (remindAt.isAfter(now)) {
      final before = formatDuration(event.startUtc.difference(remindAt));
      text =
          'Pengingat: $before sebelum acara\n'
          'Berbunyi ${formatZone(remindAt, _zone)}';
      actions = [
        OutlinedButton(
          onPressed: _busy ? null : _setReminder,
          child: const Text('Ganti'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _cancelReminder,
          child: const Text('Batalkan'),
        ),
      ];
    } else {
      final before = formatDuration(event.startUtc.difference(remindAt));
      text = 'Pengingat sudah lewat ($before sebelum acara).';
      actions = [
        FilledButton.icon(
          onPressed: _busy ? null : _setReminder,
          icon: const Icon(Icons.notifications_active),
          label: const Text('Ingatkan lagi'),
        ),
      ];
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengingat',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(text),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
