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
import '../../widgets/field_label.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/soft_card.dart';

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
  Widget _stars(int value, {ValueChanged<int>? onSelect, double size = 36}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onSelect == null ? null : () => onSelect(i),
            child: Padding(
              padding: EdgeInsets.only(right: onSelect == null ? 2 : 6),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: AppColors.gold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.danger),
    ),
  );

  Widget _buildForm() {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Penilaian'),
          _stars(
            _rating,
            onSelect: (v) => setState(() {
              _rating = v;
              _ratingError = false;
            }),
          ),
          if (_ratingError) _error('Pilih rating bintang dulu.'),
          const SizedBox(height: 18),
          const FieldLabel('Kesan'),
          TextField(
            controller: _kesanController,
            maxLines: 3,
            onChanged: (_) {
              if (_textError) setState(() => _textError = false);
            },
            decoration: appInput(hint: 'Apa kesanmu selama mengikuti kuliah ini?'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Saran'),
          TextField(
            controller: _saranController,
            maxLines: 3,
            onChanged: (_) {
              if (_textError) setState(() => _textError = false);
            },
            decoration: appInput(hint: 'Apa saranmu untuk perkuliahan ini?'),
          ),
          if (_textError) _error('Isi saran atau kesan (boleh salah satu).'),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Kirim',
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(FeedbackEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stars(e.rating, size: 20),
                Text(
                  _formatDateTime(e.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            if (e.kesan != null) ...[
              const SizedBox(height: 12),
              const FieldLabel('Kesan'),
              Text(e.kesan!),
            ],
            if (e.saran != null) ...[
              const SizedBox(height: 12),
              const FieldLabel('Saran'),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Mata kuliah Pemrograman Aplikasi Mobile',
          style: AppText.serif(size: 20, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Bagaimana saran dan kesanmu untuk mata kuliah ini?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        _buildForm(),
        const SizedBox(height: 24),
        Text('Riwayat', style: AppText.serif(size: 20, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Text(
            'Belum ada kiriman.',
            style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6)),
          )
        else
          for (final e in _history) _buildHistoryItem(e),
      ],
    );
  }
}
