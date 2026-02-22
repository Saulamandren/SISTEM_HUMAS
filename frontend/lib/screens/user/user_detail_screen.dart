import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/role_model.dart';
import 'user_form_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  final User? initialUser;

  const UserDetailScreen({
    Key? key,
    required this.userId,
    this.initialUser,
  }) : super(key: key);

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    final provider = context.read<UserProvider>();
    final response = await provider.loadUserById(widget.userId);
    if (response.isSuccess && response.data != null) {
      setState(() => _user = response.data);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openEditUser(List<Role> roles) async {
    if (_user == null) return;
    final provider = context.read<UserProvider>();
    var roleList = roles;
    if (roleList.isEmpty) {
      final response = await provider.loadRoles();
      roleList = provider.roles;
      if (!response.isSuccess || roleList.isEmpty) {
        _showSnackBar('Data role belum tersedia', isError: true);
        return;
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(
          user: _user,
          roles: roleList,
        ),
      ),
    );

    if (result == true) {
      _loadUser();
    }
  }

  Future<void> _handleResetPassword() async {
    if (_user == null) return;
    final confirmed = await _showConfirmDialog(
      'Reset Password',
      'Reset password untuk user "${_user!.username}"?',
    );
    if (!confirmed) return;

    final provider = context.read<UserProvider>();
    final response = await provider.resetPassword(_user!.id);

    if (!mounted) return;

    if (response.isSuccess) {
      final newPassword = response.data?['new_password'] ??
          response.data?['default_password'] ??
          '';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Baru'),
          content: SelectableText(newPassword.isEmpty ? '-' : newPassword),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } else {
      _showSnackBar(response.message ?? 'Gagal reset password', isError: true);
    }
  }

  Future<void> _handleDeleteUser() async {
    if (_user == null) return;
    final confirmed = await _showConfirmDialog(
      'Hapus User',
      'Yakin ingin menghapus user "${_user!.username}"?',
      isDangerous: true,
    );
    if (!confirmed) return;

    final provider = context.read<UserProvider>();
    final response = await provider.deleteUser(_user!.id);

    if (!mounted) return;

    if (response.isSuccess) {
      Navigator.pop(context, true);
    } else {
      _showSnackBar(response.message ?? 'Gagal menghapus user', isError: true);
    }
  }

  Future<bool> _showConfirmDialog(
    String title,
    String message, {
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.red : null,
            ),
            child: const Text('Ya'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final isKasubbag = authProvider.currentUser?.isKasubbag == true;
    final roles = userProvider.roles;

    final user = _user;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pengguna'),
        actions: [
          if (isKasubbag && user != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openEditUser(roles),
            ),
        ],
      ),
      body: _isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('User tidak ditemukan'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                user.fullName.isNotEmpty
                                    ? user.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.role,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Username', user.username),
                    _buildInfoRow('Email', user.email),
                    _buildInfoRow('NIP', user.nip ?? '-'),
                    _buildInfoRow('Status', user.isActive ? 'Aktif' : 'Nonaktif'),
                    _buildInfoRow(
                      'Email Verifikasi',
                      user.emailVerified ? 'Terverifikasi' : 'Belum',
                    ),
                    _buildInfoRow(
                      'Last Login',
                      user.lastLogin != null
                          ? dateFormat.format(user.lastLogin!)
                          : '-',
                    ),
                    _buildInfoRow(
                      'Dibuat',
                      dateFormat.format(user.createdAt),
                    ),
                    if (isKasubbag) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _handleResetPassword,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Reset Password'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _handleDeleteUser,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Hapus User',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
