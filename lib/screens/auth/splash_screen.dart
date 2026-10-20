// screens/auth/splash_screen.dart
// Layar pertama yang dilihat pengguna. Tugasnya cuma satu: cek
// apakah ada session yang masih valid, lalu pindah ke Home atau
// Login. Tidak ada UI rumit di sini karena durasinya sangat singkat.

import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../home/home_shell.dart';
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
    // Kalau pembacaan session gagal (mis. penyimpanan tidak bisa
    // dibuka), anggap belum login dan tampilkan Login. Tanpa ini,
    // Splash berputar selamanya tanpa pesan apa pun.
    User? found;
    try {
      found = await _authService.currentUser();
    } catch (_) {
      found = null;
    }
    // Salinan final supaya Dart mengenali nilainya tidak null di dalam
    // closure builder di bawah.
    final user = found;

    if (!mounted) return;

    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShell(username: user.username),
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
