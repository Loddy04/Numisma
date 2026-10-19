// screens/auth/splash_screen.dart
// Layar pertama yang dilihat pengguna. Tugasnya cuma satu: cek
// apakah ada session yang masih valid, lalu pindah ke Home atau
// Login. Tidak ada UI rumit di sini karena durasinya sangat singkat.

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback: supaya navigasi dijalankan SETELAH frame
    // pertama selesai digambar, bukan di tengah initState (Flutter
    // akan error kalau Navigator dipanggil terlalu dini).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final user = await _authService.currentUser();

    if (!mounted) return;

    if (user != null) {
      // TODO (Hari 2): ganti ke HomeShell begitu bottom nav dibuat.
      // Untuk sekarang tampilkan pesan sementara supaya tetap bisa
      // diuji alurnya (lihat T05 di Bagian 10 panduan).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _TemporaryHomePlaceholder(username: user.username),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logo sementara: ikon koin + nama aplikasi. Bisa diganti aset
    // gambar asli nanti tanpa mengubah logika di atas.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on, size: 72),
            SizedBox(height: 12),
            Text('Numisma', style: TextStyle(fontSize: 24)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Placeholder sementara pengganti HomeShell (Bagian 4.3) yang baru
// dibuat Hari 2. Dipakai supaya target "tetap login setelah tutup
// aplikasi" (T05) sudah bisa dibuktikan hari ini juga.
// Tombol logout disertakan lebih awal supaya T21 juga bisa dites
// manual sebelum bottom nav sungguhan ada.
class _TemporaryHomePlaceholder extends StatelessWidget {
  final String username;
  const _TemporaryHomePlaceholder({required this.username});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Numisma'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await authService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text('Halo, $username! (sudah login, sesuai session)'),
      ),
    );
  }
}
