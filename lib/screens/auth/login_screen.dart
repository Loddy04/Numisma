// screens/auth/login_screen.dart
// Form login: email + password, plus tombol "Masuk dengan sidik
// jari" (Bagian 7.3) yang hanya muncul bila fitur itu sudah dinyalakan
// di Profil dan HP-nya mendukung.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/account_remote.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../theme.dart';
import '../../widgets/gradient_button.dart';
import 'auth_widgets.dart';
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


  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  // Kepala halaman bergradasi di atas, lembar krem bersudut bulat di bawahnya
  // yang menimpa kepala sebesar [overlap]. Seluruh halaman bisa digulir (HP
  // kecil atau keyboard terbuka); lembar diberi tinggi minimum supaya selalu
  // sampai ke dasar layar.
  @override
  Widget build(BuildContext context) {
    const heroHeight = 300.0;
    const overlap = 32.0;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.creamBottom,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SingleChildScrollView(
          child: Stack(
            children: [
              const AuthHero(height: heroHeight),
              Column(
                children: [
                  const SizedBox(height: heroHeight - overlap),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: media.size.height - (heroHeight - overlap),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      24 + media.padding.bottom,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppGradients.page,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: _form(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masuk',
            style: AppText.serif(size: 32, weight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Email'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: authInput(
              hint: 'kamu@email.com',
              icon: Icons.mail_outline,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const FieldLabel('Password'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: authInput(
              hint: 'Password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Masuk',
            loading: _isLoading,
            onPressed: _isLoading ? null : _handleLogin,
          ),
          if (_canBiometric) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'atau',
                    style: TextStyle(
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleBiometricLogin,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Masuk dengan sidik jari'),
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: InkWell(
              onTap: _isLoading ? null : _openRegister,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text.rich(
                  TextSpan(
                    text: 'Belum punya akun? ',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
                    children: const [
                      TextSpan(
                        text: 'Daftar',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.bronze,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
