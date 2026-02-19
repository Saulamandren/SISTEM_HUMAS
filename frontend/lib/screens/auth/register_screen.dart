// File: frontend/lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _nipController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _nipController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password harus diisi';
    }
    if (value.length < 8) {
      return 'Password minimal 8 karakter';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password harus mengandung huruf kapital';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password harus mengandung huruf kecil';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password harus mengandung angka';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password harus mengandung karakter khusus';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      nip: _nipController.text.trim().isEmpty
          ? null
          : _nipController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.isSuccess) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registrasi berhasil! Silakan login.'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to login
      Navigator.of(context).pop();
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Registrasi gagal'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 500 : double.infinity,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Daftar Akun Baru',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Lengkapi data berikut untuk mendaftar',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Full Name
                          CustomTextField(
                            controller: _fullNameController,
                            label: 'Nama Lengkap',
                            hint: 'Masukkan nama lengkap',
                            prefixIcon: const Icon(Icons.person_outline),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama lengkap harus diisi';
                              }
                              if (value.trim().length < 3) {
                                return 'Nama lengkap minimal 3 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Username
                          CustomTextField(
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'Masukkan username',
                            prefixIcon: const Icon(
                              Icons.account_circle_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Username harus diisi';
                              }
                              if (value.trim().length < 3) {
                                return 'Username minimal 3 karakter';
                              }
                              if (!RegExp(
                                r'^[a-zA-Z0-9._]+$',
                              ).hasMatch(value)) {
                                return 'Username hanya boleh huruf, angka, titik, dan underscore';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Masukkan email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email harus diisi';
                              }
                              if (!EmailValidator.validate(value)) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // NIP (Optional)
                          CustomTextField(
                            controller: _nipController,
                            label: 'NIP (Opsional)',
                            hint: 'Masukkan NIP 18 digit',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.badge_outlined),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (value.length != 18) {
                                  return 'NIP harus 18 digit';
                                }
                                if (!RegExp(r'^\d+$').hasMatch(value)) {
                                  return 'NIP harus berupa angka';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Masukkan password',
                            obscureText: true,
                            prefixIcon: const Icon(Icons.lock_outline),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 8),

                          // Password Requirements
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password harus mengandung:',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                _buildPasswordRequirement(
                                  '• Minimal 8 karakter',
                                ),
                                _buildPasswordRequirement(
                                  '• Huruf kapital (A-Z)',
                                ),
                                _buildPasswordRequirement(
                                  '• Huruf kecil (a-z)',
                                ),
                                _buildPasswordRequirement('• Angka (0-9)'),
                                _buildPasswordRequirement(
                                  '• Karakter khusus (!@#\$%^&*)',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password
                          CustomTextField(
                            controller: _confirmPasswordController,
                            label: 'Konfirmasi Password',
                            hint: 'Ulangi password',
                            obscureText: true,
                            prefixIcon: const Icon(Icons.lock_outline),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Konfirmasi password harus diisi';
                              }
                              if (value != _passwordController.text) {
                                return 'Password tidak cocok';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Register Button
                          CustomButton(
                            text: 'Daftar',
                            onPressed: _handleRegister,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 16),

                          // Login Link
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sudah punya akun? ',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Masuk',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
      ),
    );
  }
}
