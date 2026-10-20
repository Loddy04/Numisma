// screens/feedback/feedback_screen.dart
// Isi tab Saran (K6, NUMISMA_GUIDE Bagian 7.6): form saran dan kesan
// untuk mata kuliah Pemrograman Aplikasi Mobile, berisi rating bintang
// 1-5, kesan, dan saran (urutan ini juga dipakai di riwayat), lalu riwayat kiriman pengguna di bawahnya.
// Seperti ProfileScreen, ini hanya isi tab tanpa Scaffold sendiri,
// karena AppBar dan bottom nav milik HomeShell.

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/feedback_repo.dart';
import '../../theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _authService = AuthService();
  final _repo = FeedbackRepo();
  final _saranController = TextEditingController();
  final _kesanController = TextEditingController();

  int? _userId;
  int _rating = 0; // 0 = belum dipilih
  bool _ratingError = false;
  bool _textError = false;
  bool _saving = false;
  bool _loading = true;
  List<FeedbackEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saranController.dispose();
    _kesanController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await _authService.currentUser();
      final history = user == null ? <FeedbackEntry>[] : await _repo.list(user.id!);
      if (!mounted) return;
      setState(() {
        _userId = user?.id;
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Gagal memuat riwayat, coba lagi.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final userId = _userId;
    if (userId == null) return;

    // Rating wajib, dan minimal salah satu dari saran/kesan harus
    // diisi, supaya kiriman tidak kosong.
    final hasText = _saranController.text.trim().isNotEmpty ||
        _kesanController.text.trim().isNotEmpty;
    setState(() {
      _ratingError = _rating == 0;
      _textError = !hasText;
    });
    if (_rating == 0 || !hasText) return;

    setState(() => _saving = true);
    try {
      await _repo.add(
        userId: userId,
        rating: _rating,
        saran: _saranController.text,
        kesan: _kesanController.text,
      );
      _saranController.clear();
      _kesanController.clear();
      _rating = 0;
      await _load();
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Terima kasih atas saran dan kesanmu!');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Gagal menyimpan, coba lagi.');
    }
  }

  // "2026-10-21T..." (UTC) -> "21/10/2026 14:05" dalam waktu lokal HP.
  String _formatDateTime(String iso) {
    final d = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  // Baris bintang. `onSelect` null = hanya tampilan (di riwayat).
  Widget _stars(int value, {ValueChanged<int>? onSelect, double size = 32}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onSelect == null ? null : () => onSelect(i),
            child: Icon(
              i <= value ? Icons.star : Icons.star_border,
              size: size,
              color: AppColors.gold,
            ),
          ),
      ],
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mata kuliah Pemrograman Aplikasi Mobile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bagaimana saran dan kesanmu untuk mata kuliah ini?',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _stars(
              _rating,
              onSelect: (v) => setState(() {
                _rating = v;
                _ratingError = false;
              }),
            ),
            if (_ratingError)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Pilih rating bintang dulu.',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _kesanController,
              maxLines: 3,
              onChanged: (_) {
                if (_textError) setState(() => _textError = false);
              },
              decoration: const InputDecoration(labelText: 'Kesan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _saranController,
              maxLines: 3,
              onChanged: (_) {
                if (_textError) setState(() => _textError = false);
              },
              decoration: const InputDecoration(labelText: 'Saran'),
            ),
            if (_textError)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Isi saran atau kesan (boleh salah satu).',
                  style: TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kirim'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(FeedbackEntry e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stars(e.rating, size: 18),
                Text(
                  _formatDateTime(e.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            if (e.kesan != null) ...[
              const SizedBox(height: 8),
              const Text('Kesan',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(e.kesan!),
            ],
            if (e.saran != null) ...[
              const SizedBox(height: 8),
              const Text('Saran',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(e.saran!),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildForm(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Riwayat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada kiriman.'),
          )
        else
          for (final e in _history) _buildHistoryItem(e),
        const SizedBox(height: 16),
      ],
    );
  }
}
