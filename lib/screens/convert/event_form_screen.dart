// screens/convert/event_form_screen.dart
// Form acara kolektor (NUMISMA_GUIDE 0.5, Bagian 7.7b), satu form untuk dua
// mode: tambah (event == null) dan ubah. Jam yang diisi SELALU dibaca WIB
// (tidak ada pilihan zona input); di database waktunya disimpan UTC, dan
// kartu/detail bisa menampilkannya di zona lain lewat pilihan zona.

import 'package:flutter/material.dart';

import '../../core/format_util.dart';
import '../../core/time_util.dart';
import '../../models/event.dart';
import '../../services/event_repo.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';

// Hasil yang dikembalikan form ke layar pemanggil.
enum EventFormResult { saved, deleted }

class EventFormScreen extends StatefulWidget {
  final int userId;
  final Event? event; // null = mode tambah
  const EventFormScreen({super.key, required this.userId, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  final _repo = EventRepo();

  DateTime? _date; // hanya tanggalnya (jam diabaikan)
  TimeOfDay? _time;
  bool _submitted =
      false; // supaya tanggal/jam kosong baru ditandai merah setelah Simpan
  bool _saving = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e == null) return;
    // Mode ubah: isi formulir dari acara yang ada. Waktu UTC di database
    // ditampilkan kembali sebagai jam WIB.
    _titleController.text = e.title;
    _locationController.text = e.location ?? '';
    _noteController.text = e.note ?? '';
    final t = toZone(e.startUtc, zoneWib);
    _date = DateTime(t.year, t.month, t.day);
    _time = TimeOfDay(hour: t.hour, minute: t.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // "Hari ini" menurut WIB, bukan zona HP, karena jam input dibaca WIB.
  DateTime _todayWib() {
    final t = toZone(DateTime.now().toUtc(), zoneWib);
    return DateTime(t.year, t.month, t.day);
  }

  Future<void> _pickDate() async {
    final today = _todayWib();
    // Acara lama yang sudah lewat tetap bisa dibuka tanggalnya: batas awal
    // dimundurkan ke tanggal acara itu.
    final current = _date;
    final first = (current != null && current.isBefore(today))
        ? current
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: first,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      // 24 jam supaya tidak ambigu antara AM dan PM.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) return;

    final startUtc = utcFromZone(
      zoneWib,
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    // Waktu dianggap "berubah" bila ini acara baru, atau tanggal/jamnya
    // berbeda dari yang tersimpan. Hanya waktu yang baru dipaksa di masa
    // depan, jadi mengubah catatan acara yang sudah lewat tetap boleh.
    final timeChanged =
        !_editing || !startUtc.isAtSameMomentAs(widget.event!.startUtc);
    if (timeChanged && !startUtc.isAfter(DateTime.now().toUtc())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu acara sudah lewat. Pilih waktu di masa depan.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editing) {
        final old = widget.event!;
        await _repo.update(
          Event(
            id: old.id,
            userId: old.userId,
            title: _titleController.text,
            startUtc: startUtc,
            location: _locationController.text,
            note: _noteController.text,
          ),
        );
        // Kelompok C: bila timeChanged, batalkan alarm pengingat acara ini
        // (NotifService.cancelEventReminder) dan beri tahu pengguna. Baris
        // reminders-nya sudah dihapus oleh EventRepo.update.
      } else {
        await _repo.add(
          userId: widget.userId,
          title: _titleController.text,
          startUtc: startUtc,
          location: _locationController.text,
          note: _noteController.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(EventFormResult.saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan acara, coba lagi.')),
      );
    }
  }

  Future<void> _delete() async {
    final event = widget.event!;
    final yakin = await confirmDialog(
      context,
      title: 'Hapus acara',
      message: 'Acara "${event.title}" akan dihapus. Lanjutkan?',
    );
    if (!yakin) return;

    setState(() => _saving = true);
    try {
      // Kelompok C: batalkan alarm pengingat (NotifService) sebelum baris
      // acaranya dihapus.
      await _repo.delete(event.id);
      if (!mounted) return;
      Navigator.of(context).pop(EventFormResult.deleted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus acara, coba lagi.')),
      );
    }
  }

  // Kotak pilihan tanggal/jam yang tampil seperti isian lain.
  Widget _pickerBox({
    required String label,
    required String? value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final missing = _submitted && value == null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: missing ? '$label wajib dipilih.' : null,
          suffixIcon: Icon(icon),
        ),
        child: Text(value ?? ' '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final time = _time;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah acara' : 'Tambah acara')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama acara'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama acara wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _locationController,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Lokasi (opsional)'),
            ),
            const SizedBox(height: 4),
            _pickerBox(
              label: 'Tanggal',
              value: date == null
                  ? null
                  : '${date.day} ${monthNamesId[date.month - 1]} ${date.year}',
              onTap: _pickDate,
              icon: Icons.calendar_today,
            ),
            const SizedBox(height: 16),
            _pickerBox(
              label: 'Jam (WIB)',
              value: time == null
                  ? null
                  : '${time.hour.toString().padLeft(2, '0')}:'
                        '${time.minute.toString().padLeft(2, '0')}',
              onTap: _pickTime,
              icon: Icons.access_time,
            ),
            const SizedBox(height: 8),
            const Text(
              'Waktu dalam WIB. Di daftar acara kamu bisa melihatnya di WITA, WIT, atau UTC.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
            if (_editing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus acara'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
