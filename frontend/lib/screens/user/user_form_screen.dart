import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/role_model.dart';
import '../../providers/user_provider.dart';

class UserFormScreen extends StatefulWidget {
  final User? user;
  final List<Role> roles;

  const UserFormScreen({
    Key? key,
    this.user,
    required this.roles,
  }) : super(key: key);

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _nipController = TextEditingController();
  final _passwordController = TextEditingController();

  int? _selectedRoleId;
  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      final user = widget.user!;
      _usernameController.text = user.username;
      _emailController.text = user.email;
      _fullNameController.text = user.fullName;
      _nipController.text = user.nip ?? '';
      _isActive = user.isActive;
    }

    _selectedRoleId = _findRoleId(widget.user?.role) ??
        (widget.roles.isNotEmpty ? widget.roles.first.id : null);
  }

  int? _findRoleId(String? roleName) {
    if (roleName == null) return null;
    for (final role in widget.roles) {
      if (role.name == roleName) return role.id;
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) {
      _showSnackBar('Role wajib dipilih', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<UserProvider>();
    if (isEditMode) {
      final response = await provider.updateUser(
        id: widget.user!.id,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        nip: _nipController.text.trim().isEmpty
            ? null
            : _nipController.text.trim(),
        roleId: _selectedRoleId!,
        isActive: _isActive,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      if (response.isSuccess) {
        _showSnackBar('User berhasil diperbarui');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(response.message ?? 'Gagal memperbarui user',
            isError: true);
      }
    } else {
      final passwordText = _passwordController.text.trim();
      final response = await provider.createUser(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        fullName: _fullNameController.text.trim(),
        nip: _nipController.text.trim().isEmpty
            ? null
            : _nipController.text.trim(),
        roleId: _selectedRoleId!,
        password: passwordText.isEmpty ? null : passwordText,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      if (response.isSuccess) {
        final defaultPassword =
            response.data?['default_password']?.toString() ?? '';
        if (defaultPassword.isNotEmpty) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Password Akun Baru'),
              content: SelectableText(defaultPassword),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          );
        }
        _showSnackBar('User berhasil dibuat');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(response.message ?? 'Gagal membuat user', isError: true);
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit User' : 'Tambah User'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!isEditMode) ...[
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username *',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username wajib diisi';
                  }
                  if (value.trim().length < 3) {
                    return 'Username minimal 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama lengkap wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email wajib diisi';
                }
                if (!value.contains('@')) {
                  return 'Email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nipController,
              decoration: const InputDecoration(
                labelText: 'NIP (opsional)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _selectedRoleId,
              decoration: const InputDecoration(
                labelText: 'Role *',
              ),
              items: widget.roles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role.id,
                      child: Text(role.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedRoleId = value);
              },
            ),
            if (isEditMode) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Aktif'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
            if (!isEditMode) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password (opsional)',
                  helperText: 'Kosongkan untuk password default',
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(isEditMode ? 'Simpan Perubahan' : 'Tambah User'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _nipController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
