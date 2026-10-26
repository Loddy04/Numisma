// screens/auth/login_screen.dart
// Form login: email + password, plus tombol "Masuk dengan sidik
// jari" (Bagian 7.3) yang hanya muncul bila fitur itu sudah dinyalakan
// di Profil dan HP-nya mendukung.

import 'package:flutter/material.dart';

import '../../services/account_remote.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/double_rule.dart';
import 'register_screen.dart';
import 'splash_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _biometricService = BiometricService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _canBiometric = false; // true = tombol sidik jari ditampilkan

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final can = await _biometricService.canLoginWithBiometric();
    if (!mounted) return;
    setState(() => _canBiometric = can);
  }

  // Login lewat sidik jari. Gagal/dibatalkan: pesan ramah, dan login
  // dengan password tetap bisa dipakai.
  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _biometricService.loginWithBiometric();
      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sidik jari tidak dikenali atau dibatalkan. Gunakan password.',
            ),
          ),
        );
        return;
      }

      // Sama seperti login password: lewat SplashScreen supaya logika
      // cek session tidak ditulis dua kali.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login sidik jari gagal, coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (user == null) {
        // Pesan digabung (tidak membedakan "email salah" vs
        // "password salah") -- lihat alasannya di auth_service.dart.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AuthService.errLoginFailed)),
        );
        return;
      }

      // Login berhasil -> arahkan lewat SplashScreen (bukan langsung
      // ke Home), supaya logika "cek session" tidak ditulis dua kali
      // di tempat berbeda -- SplashScreen yang akan membaca session
      // yang baru saja dibuat oleh AuthService.login() di atas.
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            // AccountException sudah berpesan ramah (mis. tanpa internet).
            e is AccountException ? e.message : 'Terjadi kesalahan: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 88)),
                  const SizedBox(height: 12),
                  Text(
                    'NUMISMA',
                    textAlign: TextAlign.center,
                    style: AppText.serif(
                      size: 30,
                      spacing: 6,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Buku koleksi koin dan uang kertas',
                    textAlign: TextAlign.center,
                    style: AppText.serif(size: 15, italic: true),
                  ),
                  const SizedBox(height: 16),
                  const DoubleRule(),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Masuk'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text('Belum punya akun? Daftar di sini'),
                  ),
                  if (_canBiometric) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleBiometricLogin,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Masuk dengan sidik jari'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
