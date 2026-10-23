// screens/collection/sync_screen.dart
// Layar Sinkron, dibuka dari AppBar Koleksi (NUMISMA_GUIDE 7.4). Perubahan
// koin diunggah otomatis saat online; layar ini menampilkan statusnya
// ("N belum diunggah") dan menyediakan tombol cadangan "Sinkronkan sekarang"
// serta "Pulihkan". Semua logika ada di SyncService, layar hanya menampilkan.

import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/account_remote.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../theme.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _auth = AuthService();
  final _sync = SyncService();

  User? _user;
  int _pending = 0;
  bool _loading = true;
  bool _busy = false;
  // Hasil operasi terakhir, tampil di bawah tombol.
  String? _message;
  List<String> _conflicts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.currentUser();
    final pending = user == null ? 0 : await _sync.pendingCount(user);
    if (!mounted) return;
    setState(() {
      _user = user;
      _pending = pending;
      _loading = false;
    });
  }

  // Menjalankan satu operasi, menampilkan hasilnya, lalu memuat ulang
  // status. Pesan error sudah ramah (AccountException).
  Future<void> _run(Future<SyncResult> Function(User user) action) async {
    final user = _user;
    if (user == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _conflicts = const [];
    });
    try {
      final result = await action(user);
      if (!mounted) return;
      _message = _describe(result);
      _conflicts = result.conflicts;
    } on AccountException catch (e) {
      _message = e.message;
    } catch (_) {
      _message = AccountRemote.errGeneric;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  String _describe(SyncResult r) {
    if (r.note != null) return r.note!;
    final parts = <String>[];
    if (r.coinsUploaded + r.blocksUploaded > 0) {
      parts.add(
        'Terunggah: ${r.coinsUploaded} koin, ${r.blocksUploaded} blok catatan.',
      );
    }
    if (r.coinsRestored + r.blocksRestored > 0) {
      parts.add(
        'Dipulihkan: ${r.coinsRestored} koin, ${r.blocksRestored} blok catatan.',
      );
    }
    if (r.hasConflict) parts.add('Ada konflik rantai, tidak ada yang ditimpa.');
    return parts.isEmpty ? 'Tidak ada yang perlu diproses.' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sinkron')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      _pending == 0 ? Icons.cloud_done : Icons.cloud_upload,
                      color: AppColors.bronze,
                    ),
                    title: Text(
                      _pending == 0
                          ? 'Semua sudah tersinkron'
                          : '$_pending belum diunggah',
                    ),
                    subtitle: const Text(
                      'Perubahan koin diunggah otomatis saat ada internet.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _run(_sync.upload),
                  icon: const Icon(Icons.cloud_sync),
                  label: const Text('Sinkronkan sekarang'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(_sync.restore),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Pulihkan dari cloud'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pulihkan hanya untuk perangkat yang masih kosong (misalnya '
                  'setelah aplikasi dipasang ulang). Data di HP ini tidak '
                  'pernah ditimpa. Catatan koin tidak bisa dibuka setelah '
                  'dipulihkan di HP lain.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 20),
                  Text(_message!),
                  for (final c in _conflicts)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        c,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
