import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/role_model.dart';
import '../../widgets/sidebar.dart';
import 'user_form_screen.dart';
import 'user_detail_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedRoleId;
  String _activeFilter = 'all';
  int _currentPage = 1;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      userProvider.loadRoles();
      _loadUsers();
    });
  }

  Future<void> _loadUsers({int? page}) async {
    final userProvider = context.read<UserProvider>();
    final isActive = _activeFilter == 'all'
        ? null
        : _activeFilter == 'active'
            ? true
            : false;
    final search = _searchController.text.trim();
    final nextPage = page ?? _currentPage;

    setState(() => _currentPage = nextPage);

    await userProvider.loadUsers(
      page: nextPage,
      perPage: _perPage,
      roleId: _selectedRoleId,
      search: search.isEmpty ? null : search,
      isActive: isActive,
    );
  }

  Future<void> _openCreateUser(List<Role> roles) async {
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
        builder: (context) => UserFormScreen(roles: roleList),
      ),
    );

    if (result == true) {
      _loadUsers(page: 1);
    }
  }

  Future<void> _openEditUser(User user, List<Role> roles) async {
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
          user: user,
          roles: roleList,
        ),
      ),
    );

    if (result == true) {
      _loadUsers(page: _currentPage);
    }
  }

  Future<void> _openUserDetail(User user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailScreen(
          userId: user.id,
          initialUser: user,
        ),
      ),
    );

    if (result == true) {
      _loadUsers(page: _currentPage);
    }
  }

  Future<void> _handleResetPassword(User user) async {
    final confirmed = await _showConfirmDialog(
      'Reset Password',
      'Reset password untuk user "${user.username}"?',
    );

    if (!confirmed) return;

    final provider = context.read<UserProvider>();
    final response = await provider.resetPassword(user.id);

    if (!mounted) return;

    if (response.isSuccess) {
      final newPassword = response.data?['new_password'] ??
          response.data?['default_password'] ??
          '';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Baru'),
          content: SelectableText(
            newPassword.isEmpty ? '-' : newPassword,
          ),
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

  Future<void> _handleDeleteUser(User user) async {
    final confirmed = await _showConfirmDialog(
      'Hapus User',
      'Yakin ingin menghapus user "${user.username}"?',
      isDangerous: true,
    );

    if (!confirmed) return;

    final provider = context.read<UserProvider>();
    final response = await provider.deleteUser(user.id);

    if (!mounted) return;

    if (response.isSuccess) {
      _showSnackBar('User berhasil dihapus');
      _loadUsers(page: 1);
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
    final currentUser = authProvider.currentUser;
    final isKasubbag = currentUser?.isKasubbag == true;

    final roles = userProvider.roles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUsers(page: _currentPage),
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Cari user',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _loadUsers(page: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedRoleId,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Semua Role'),
                      ),
                      ...roles.map(
                        (role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedRoleId = value);
                      _loadUsers(page: 1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _activeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Aktif'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Nonaktif'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _activeFilter = value);
                      _loadUsers(page: 1);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (userProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                userProvider.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadUsers(page: _currentPage),
              child: userProvider.isLoading && userProvider.users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : userProvider.users.isEmpty
                      ? const Center(child: Text('Tidak ada pengguna'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: userProvider.users.length + 1,
                          itemBuilder: (context, index) {
                            if (index == userProvider.users.length) {
                              return _buildPagination(userProvider);
                            }

                            final user = userProvider.users[index];
                            return _buildUserCard(
                              user,
                              isKasubbag: isKasubbag,
                              onTap: () => _openUserDetail(user),
                              onEdit: () => _openEditUser(user, roles),
                              onResetPassword: () => _handleResetPassword(user),
                              onDelete: () => _handleDeleteUser(user),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: isKasubbag
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateUser(roles),
              icon: const Icon(Icons.person_add),
              label: const Text('Tambah User'),
            )
          : null,
    );
  }

  Widget _buildUserCard(
    User user, {
    required bool isKasubbag,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onResetPassword,
    required VoidCallback onDelete,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final lastLogin = user.lastLogin != null
        ? dateFormat.format(user.lastLogin!)
        : 'Belum pernah';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${user.username} • ${user.email}'),
            const SizedBox(height: 4),
            Text('Login terakhir: $lastLogin'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _buildBadge(user.role, Colors.blue),
                _buildBadge(
                  user.isActive ? 'Aktif' : 'Nonaktif',
                  user.isActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
        trailing: isKasubbag
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'reset') {
                    onResetPassword();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset),
                        SizedBox(width: 8),
                        Text('Reset Password'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPagination(UserProvider userProvider) {
    final pagination = userProvider.paginatedUsers;
    if (pagination == null || pagination.totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: pagination.hasPreviousPage
                ? () => _loadUsers(page: pagination.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Sebelumnya'),
          ),
          Text(
            'Halaman ${pagination.page} dari ${pagination.totalPages}',
            style: const TextStyle(fontSize: 12),
          ),
          OutlinedButton.icon(
            onPressed: pagination.hasNextPage
                ? () => _loadUsers(page: pagination.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
