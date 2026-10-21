// screens/convert/event_detail_screen.dart
// Detail satu acara kolektor (NUMISMA_GUIDE 0.5, Bagian 7.7b): nama, lokasi,
// waktu di satu zona pilihan, dan catatan. Dari sini pengguna mengubah atau
// menghapus acara. Bagian pengingat ditambahkan di sini pada kelompok
// notifikasi (Bagian 7.12), bukan di kartu daftar.

import 'package:flutter/material.dart';

import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/event_repo.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/zone_picker.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _repo = EventRepo();

  Event? _event;
  bool _loading = true;
  String _zone = zoneWib;

  @override
  void initState() {
    super.initState();
    _load();
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
      setState(() {
        _event = event;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat acara, coba lagi.')),
      );
    }
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
      // Kelompok C: batalkan alarm pengingat (NotifService) sebelum baris
      // acaranya dihapus.
      await _repo.delete(event.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus acara, coba lagi.')),
      );
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
}
