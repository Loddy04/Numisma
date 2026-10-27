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
import '../../widgets/field_label.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/soft_card.dart';
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: PageHeader(
                  title: 'Detail acara',
                  trailing: event == null
                      ? null
                      : TextButton(
                          onPressed: _edit,
                          child: const Text(
                            'Ubah',
                            style: TextStyle(fontSize: 17),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : event == null
                    ? const Center(child: Text('Acara tidak ditemukan.'))
                    : _buildBody(event),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Event event) {
    final past = event.startUtc.isBefore(DateTime.now().toUtc());
    final muted = AppColors.ink.withValues(alpha: 0.6);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              // Kartu hero: nama, tempat, dan waktu mulai besar di zona pilihan.
              HeroCard(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: AppText.serif(
                        size: 32,
                        weight: FontWeight.w700,
                        color: AppColors.creamTop,
                      ),
                    ),
                    if (event.location != null &&
                        event.location!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (past)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Sudah lewat',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    // Waktu mulai di zona yang dipilih, sama seperti kartu
                    // daftar.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatZoneTime(event.startUtc, _zone),
                          style: AppText.serif(
                            size: 60,
                            weight: FontWeight.w700,
                            color: AppColors.creamTop,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${zoneAbbreviation(event.startUtc, _zone)} · '
                            '${formatZoneDate(event.startUtc, _zone)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ZonePicker(
                selected: _zone,
                onSelected: (z) => setState(() => _zone = z),
              ),
              const SizedBox(height: 16),
              if (event.hasPoint) ...[
                _locationCard(event, muted),
                const SizedBox(height: 12),
              ],
              _textCard('Catatan', event.note ?? 'Tidak ada catatan.'),
              const SizedBox(height: 12),
              _reminderCard(event),
            ],
          ),
        ),
        // Aksi utama selalu di dasar layar.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (event.hasPoint) ...[
                GradientButton(
                  label: 'Rute di Google Maps',
                  icon: Icons.navigation_outlined,
                  onPressed: () => _openRoute(event),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus acara'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Kartu teks dengan label kecil huruf kapital di atasnya.
  Widget _textCard(String label, String text) {
    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(label),
            Text(text, style: const TextStyle(fontSize: 16, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // Kartu lokasi (hanya untuk acara bertitik): koordinat dan jarak dari
  // posisimu bila sudah diketahui. Tombol Rute ada di dasar layar.
  Widget _locationCard(Event event, Color muted) {
    final distance = _distance;
    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Lokasi di peta'),
            Text(
              '${event.lat!.toStringAsFixed(5)}, '
              '${event.lng!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 16),
            ),
            if (distance != null) ...[
              const SizedBox(height: 4),
              Text(
                '${formatDistance(distance)} dari posisimu',
                style: const TextStyle(fontSize: 15, color: AppColors.bronze),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Keadaan pengingat diturunkan dari waktu (baris `reminders` tidak
  // dihapus sendiri setelah notifikasi berbunyi):
  //   acara sudah mulai          -> tanpa tombol
  //   belum ada pengingat        -> "Ingatkan saya"
  //   pengingat di masa depan    -> info + Ganti + Batalkan
  //   pengingat sudah lewat      -> "Pengingat sudah lewat" + "Ingatkan lagi"
  Widget _reminderCard(Event event) {
    final now = DateTime.now().toUtc();
    final started = !event.startUtc.isAfter(now);
    final remindAt = _remindAt;

    final String title;
    final String? subtitle;
    final List<Widget> actions;
    if (started) {
      title = 'Acara sudah dimulai';
      subtitle = 'Pengingat tidak tersedia.';
      actions = const [];
    } else if (remindAt == null) {
      title = 'Belum ada pengingat';
      subtitle = null;
      actions = [
        TextButton(
          onPressed: _busy ? null : _setReminder,
          child: const Text('Ingatkan saya'),
        ),
      ];
    } else if (remindAt.isAfter(now)) {
      final before = formatDuration(event.startUtc.difference(remindAt));
      title = '$before sebelum';
      subtitle = 'Berbunyi ${formatZone(remindAt, _zone)}';
      actions = [
        TextButton(
          onPressed: _busy ? null : _setReminder,
          child: const Text('Ganti'),
        ),
        TextButton(
          onPressed: _busy ? null : _cancelReminder,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Batalkan'),
        ),
      ];
    } else {
      final before = formatDuration(event.startUtc.difference(remindAt));
      title = 'Pengingat sudah lewat';
      subtitle = '$before sebelum acara';
      actions = [
        TextButton(
          onPressed: _busy ? null : _setReminder,
          child: const Text('Ingatkan lagi'),
        ),
      ];
    }

    return SoftCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none,
            color: AppColors.bronze,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
