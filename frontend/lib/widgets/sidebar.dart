import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/content/content_list_screen.dart';
import '../screens/category/category_list_screen.dart';
import '../screens/cooperation/cooperation_list_screen.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(context, null),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerHeader(context, user),
                const Divider(height: 1),
                _buildMenuSection(context, user),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, User? user) {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1976D2),
            Color(0xFF1565C0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Logo or Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user != null ? _getInitials(user.fullName) : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // User Name
          Text(
            user?.fullName ?? 'Guest',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // User Role
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user?.role ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, User user) {
    return Column(
      children: [
        // Dashboard
        _buildMenuItem(
          context: context,
          icon: Icons.dashboard,
          title: 'Dashboard',
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
            );
          },
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // Content Management Section
        _buildSectionHeader('Manajemen Konten'),

        // Menu Konten (untuk semua role)
        _buildMenuItem(
          context: context,
          icon: Icons.article_outlined,
          title: 'Konten',
          subtitle: 'Kelola artikel & berita',
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ContentListScreen(),
              ),
            );
          },
        ),

        // Menu Kategori (hanya untuk Staff & Kasubbag)
        if (user.isStaff || user.isKasubbag)
          _buildMenuItem(
            context: context,
            icon: Icons.category_outlined,
            title: 'Kategori',
            subtitle: 'Kelola kategori konten',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryListScreen(),
                ),
              );
            },
          ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // User Management Section (untuk Staff & Kasubbag)
        if (user.isStaff || user.isKasubbag) ...[
          _buildSectionHeader('Manajemen Pengguna'),
          _buildMenuItem(
            context: context,
            icon: Icons.people_outline,
            title: 'Pengguna',
            subtitle: 'Kelola data pengguna',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to User Management Screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur User Management akan segera hadir'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],

        // Cooperation Section (akan dikembangkan)
        _buildSectionHeader('Kerjasama'),
        _buildMenuItem(
          context: context,
          icon: Icons.handshake_outlined,
          title: 'Pengajuan Kerjasama',
          subtitle: (user.isStaff || user.isKasubbag)
              ? 'Kelola pengajuan kerjasama'
              : 'Ajukan pengajuan kerjasama',
          onTap: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CooperationListScreen(),
              ),
            );
          },
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),

        // Reports Section (untuk Kasubbag)
        if (user.isKasubbag) ...[
          _buildSectionHeader('Laporan'),
          _buildMenuItem(
            context: context,
            icon: Icons.analytics_outlined,
            title: 'Laporan & Statistik',
            subtitle: 'Lihat laporan dan analisis',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to Reports Screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur Laporan akan segera hadir'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],

        // Settings Section
        _buildSectionHeader('Pengaturan'),

        // Profile
        _buildMenuItem(
          context: context,
          icon: Icons.person_outline,
          title: 'Profil',
          subtitle: 'Lihat dan edit profil',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          },
        ),

        // Settings
        _buildMenuItem(
          context: context,
          icon: Icons.settings_outlined,
          title: 'Pengaturan',
          subtitle: 'Pengaturan aplikasi',
          onTap: () {
            Navigator.pop(context);
            // TODO: Navigate to Settings Screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fitur Pengaturan akan segera hadir'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),

        const Divider(height: 1, indent: 16, endIndent: 16),

        // Help & About
        _buildSectionHeader('Bantuan'),

        _buildMenuItem(
          context: context,
          icon: Icons.help_outline,
          title: 'Bantuan',
          onTap: () {
            Navigator.pop(context);
            _showHelpDialog(context);
          },
        ),

        _buildMenuItem(
          context: context,
          icon: Icons.info_outline,
          title: 'Tentang',
          onTap: () {
            Navigator.pop(context);
            _showAboutDialog(context);
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Konfirmasi Logout'),
              content: const Text('Apakah Anda yakin ingin keluar?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );

          if (confirmed == true && context.mounted) {
            final authProvider = context.read<AuthProvider>();
            await authProvider.logout();

            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            }
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Bantuan'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sistem Informasi HUMAS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                'Dashboard',
                'Lihat ringkasan dan statistik konten',
              ),
              _buildHelpItem(
                'Konten',
                'Kelola artikel dan berita. Buat, edit, dan submit konten untuk review.',
              ),
              _buildHelpItem(
                'Kategori',
                'Kelola kategori konten (Staff & Kasubbag only)',
              ),
              _buildHelpItem(
                'Profil',
                'Lihat dan edit informasi profil Anda',
              ),
              const SizedBox(height: 16),
              const Text(
                'Butuh bantuan lebih lanjut?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hubungi administrator sistem untuk bantuan teknis.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Tentang Aplikasi'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo atau Image placeholder
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Center(
              child: Text(
                'Sistem Informasi HUMAS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),

            const Center(
              child: Text(
                'Politeknik Siber dan Sandi Negara',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            _buildInfoRow('Versi', '1.0.0'),
            _buildInfoRow('Release Date', 'February 2026'),
            _buildInfoRow('Platform', 'Flutter Web'),

            const SizedBox(height: 16),

            const Text(
              'Sistem manajemen konten dan kerjasama untuk Humas Politeknik SSN.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            const Center(
              child: Text(
                '© 2026 Politeknik SSN',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $title',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
