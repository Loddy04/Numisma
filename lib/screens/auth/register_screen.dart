// screens/auth/register_screen.dart
// Form registrasi: email, nama tampilan, password, konfirmasi password.
// Validasi format (panjang, pola, kekuatan password) dilakukan di sini
// SEBELUM dikirim ke auth_service, supaya pengguna dapat feedback instan.
// Aturannya diambil dari AuthService supaya hanya ada satu sumber; deretan
// chip syarat password hanya tampilan yang memeriksa aturan yang sama saat
// pengguna mengetik. Keunikan email dicek di auth_service (butuh database
// dan internet).

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/gradient_button.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  // Tombol mata di kolom Password dan Konfirmasi Password berdiri sendiri.
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Sengaja TIDAK auto-login (lihat auth_service.dart: register()
      // tidak lagi membuat session). Tampilkan pesan sukses, lalu
      // kembali ke layar Login (RegisterScreen ini dibuka lewat
      // Navigator.push dari LoginScreen, jadi pop() saja sudah pas).
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil, silakan login.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // Pesan dari auth_service (mis. errEmailTaken) sudah ramah,
      // langsung tampilkan isinya tanpa dibungkus lagi.
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Satu chip syarat password: hijau lembut dengan centang bila terpenuhi,
  // krem polos bila belum. Aturannya sama dengan AuthService.passwordProblem.
  Widget _requirementChip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ok ? AppColors.chipOk : AppColors.chipOff,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ok) ...[
            const Icon(Icons.check, size: 16, color: AppColors.chipOkText),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ok ? AppColors.chipOkText : AppColors.chipOffText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirements() {
    final p = _passwordController.text;
    final lengthOk =
        p.length >= AuthService.minPasswordLength &&
        p.length <= AuthService.maxPasswordLength;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _requirementChip('8-64 karakter', lengthOk),
          _requirementChip('Huruf besar', RegExp(r'[A-Z]').hasMatch(p)),
          _requirementChip('Huruf kecil', RegExp(r'[a-z]').hasMatch(p)),
          _requirementChip('Angka', RegExp(r'[0-9]').hasMatch(p)),
          _requirementChip('Simbol', RegExp(r'[^A-Za-z0-9\s]').hasMatch(p)),
        ],
      ),
    );
  }

  Widget _eye(bool obscured, VoidCallback onTap) => IconButton(
    icon: Icon(
      obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
    onPressed: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  sliver: SliverToBoxAdapter(child: _fields()),
                ),
                // Tombol dan catatan menempel di dasar layar bila isinya
                // pendek, dan ikut menggulir bila layar kecil.
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GradientButton(
                          label: 'Daftar',
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _handleRegister,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Password disimpan sebagai hash bcrypt. '
                          'Email disimpan terenkripsi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.ink.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Material(
              color: AppColors.card,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.cardBorder),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.chevron_left, color: AppColors.bronze),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Daftar',
              style: AppText.serif(size: 32, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Buat akun untuk menyimpan koleksimu. Daftar butuh internet.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppColors.ink.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Email'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: authInput(
            hint: 'kamu@email.com',
            icon: Icons.mail_outline,
          ),
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Email tidak boleh kosong';
            if (!AuthService.isValidEmail(v)) {
              return AuthService.errEmailInvalid;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        const FieldLabel('Nama tampilan'),
        TextFormField(
          controller: _usernameController,
          maxLength: AuthService.maxNameLength,
          decoration: authInput(
            hint: 'Nama yang tampil di Beranda',
            icon: Icons.person_outline,
            counterText: '',
          ),
          validator: (value) {
            if ((value?.trim() ?? '').isEmpty) {
              return 'Nama tampilan tidak boleh kosong';
            }
            return AuthService.displayNameProblem(value!);
          },
        ),
        const SizedBox(height: 16),
        const FieldLabel('Password'),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: (_) => setState(() {}), // memperbarui chip syarat
          decoration: authInput(
            hint: 'Password',
            icon: Icons.lock_outline,
            suffix: _eye(
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) => AuthService.passwordProblem(value ?? ''),
        ),
        _requirements(),
        const SizedBox(height: 16),
        const FieldLabel('Konfirmasi password'),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: authInput(
            hint: 'Ulangi password',
            icon: Icons.lock_outline,
            suffix: _eye(
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Konfirmasi password tidak cocok';
            }
            return null;
          },
        ),
      ],
    );
  }
}
