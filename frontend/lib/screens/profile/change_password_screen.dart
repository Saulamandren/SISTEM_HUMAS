// File: frontend/lib/screens/profile/change_password_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.isSuccess) {
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Password Berhasil Diubah'),
          content: const Text(
            'Password Anda telah berhasil diubah. Silakan login kembali dengan password baru.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Navigate to login
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Gagal mengubah password'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Ubah Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon & Title
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lock_reset,
                                size: 48,
                                color: AppTheme.warningColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Ubah Password',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Masukkan password lama dan password baru Anda',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Old Password
                      CustomTextField(
                        controller: _oldPasswordController,
                        label: 'Password Lama',
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password lama harus diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      CustomTextField(
                        controller: _newPasswordController,
                        label: 'Password Baru',
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
                            _buildRequirement('• Minimal 8 karakter'),
                            _buildRequirement('• Huruf kapital (A-Z)'),
                            _buildRequirement('• Huruf kecil (a-z)'),
                            _buildRequirement('• Angka (0-9)'),
                            _buildRequirement('• Karakter khusus (!@#\$%^&*)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      CustomTextField(
                        controller: _confirmPasswordController,
                        label: 'Konfirmasi Password Baru',
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Konfirmasi password harus diisi';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Password tidak cocok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      CustomButton(
                        text: 'Ubah Password',
                        onPressed: _handleChangePassword,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
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
