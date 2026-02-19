// File: frontend/lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nipController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _fullNameController.text = user.fullName;
      _emailController.text = user.email;
      _nipController.text = user.nip ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _nipController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.updateProfile(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      nip: _nipController.text.trim().isEmpty
          ? null
          : _nipController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.isSuccess) {
      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Gagal memperbarui profil'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        automaticallyImplyLeading: false,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _isEditing = true);
              },
              tooltip: 'Edit Profil',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Profile Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.role,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Information Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Informasi Profil',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (_isEditing)
                                TextButton(
                                  onPressed: () {
                                    setState(() => _isEditing = false);
                                    _loadUserData(); // Reset to original data
                                  },
                                  child: const Text('Batal'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Full Name
                          CustomTextField(
                            controller: _fullNameController,
                            label: 'Nama Lengkap',
                            enabled: _isEditing,
                            prefixIcon: const Icon(Icons.person_outline),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama lengkap harus diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            enabled: _isEditing,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email harus diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // NIP
                          CustomTextField(
                            controller: _nipController,
                            label: 'NIP (Opsional)',
                            enabled: _isEditing,
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          const SizedBox(height: 16),

                          // Username (Read-only)
                          CustomTextField(
                            controller: TextEditingController(
                              text: user.username,
                            ),
                            label: 'Username',
                            enabled: false,
                            prefixIcon: const Icon(
                              Icons.account_circle_outlined,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Account Status
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem(
                                  'Status Akun',
                                  user.isActive ? 'Aktif' : 'Nonaktif',
                                  user.isActive
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoItem(
                                  'Email Verified',
                                  user.emailVerified
                                      ? 'Terverifikasi'
                                      : 'Belum',
                                  user.emailVerified
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
                                ),
                              ),
                            ],
                          ),

                          if (_isEditing) ...[
                            const SizedBox(height: 24),
                            CustomButton(
                              text: 'Simpan Perubahan',
                              onPressed: _handleSave,
                              isLoading: _isLoading,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Security Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keamanan',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              color: AppTheme.warningColor,
                            ),
                          ),
                          title: const Text('Ubah Password'),
                          subtitle: const Text('Ubah password akun Anda'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
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

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
