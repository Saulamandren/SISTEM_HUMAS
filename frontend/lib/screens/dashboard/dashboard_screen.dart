import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/content_service.dart';
import '../../models/content_model.dart';
import '../../widgets/sidebar.dart';
import '../content/content_form_screen.dart';
import '../content/content_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _contentService = ContentService();
  bool _isLoadingStats = false;
  String? _statsError;
  int _totalContents = 0;
  int _pendingContents = 0;
  int _publishedContents = 0;
  int _draftContents = 0;
  List<Content> _recentContents = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      final results = await Future.wait([
        _contentService.getContents(perPage: 1),
        _contentService.getContents(status: 'pending', perPage: 1),
        _contentService.getContents(status: 'published', perPage: 1),
        _contentService.getContents(status: 'draft', perPage: 1),
        _contentService.getContents(perPage: 5),
      ]);

      final totalResp = results[0];
      final pendingResp = results[1];
      final publishedResp = results[2];
      final draftResp = results[3];
      final recentResp = results[4];

      if (!mounted) return;

      setState(() {
        _totalContents = totalResp.data?.total ?? 0;
        _pendingContents = pendingResp.data?.total ?? 0;
        _publishedContents = publishedResp.data?.total ?? 0;
        _draftContents = draftResp.data?.total ?? 0;
        _recentContents = recentResp.data?.contents ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsError = 'Gagal memuat data dashboard: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Show notifications
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur notifikasi akan segera hadir'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Notifikasi',
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Card
            _buildWelcomeCard(user?.fullName ?? 'User'),
            const SizedBox(height: 16),

            // Statistics Cards
            _buildStatisticsSection(),
            const SizedBox(height: 16),

            // Quick Actions
            _buildQuickActionsSection(),
            const SizedBox(height: 16),

            // Recent Activity
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Selamat Pagi';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
      greetingIcon = Icons.wb_twilight;
    } else {
      greeting = 'Selamat Malam';
      greetingIcon = Icons.nightlight_round;
    }

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1976D2),
              Color(0xFF1565C0),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              greetingIcon,
              size: 48,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selamat datang di Sistem Informasi HUMAS',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final isLoading = _isLoadingStats;
    final totalValue = isLoading ? '—' : _totalContents.toString();
    final pendingValue = isLoading ? '—' : _pendingContents.toString();
    final publishedValue = isLoading ? '—' : _publishedContents.toString();
    final draftValue = isLoading ? '—' : _draftContents.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_statsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _statsError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Konten',
                value: totalValue,
                icon: Icons.article,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Menunggu Review',
                value: pendingValue,
                icon: Icons.pending,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Dipublikasi',
                value: publishedValue,
                icon: Icons.public,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Draft',
                value: draftValue,
                icon: Icons.drafts,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aksi Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Buat Konten',
                icon: Icons.add_circle_outline,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContentFormScreen(),
                    ),
                  ).then((value) {
                    if (value == true) {
                      _loadDashboardData();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Lihat Konten',
                icon: Icons.list_alt,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContentListScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final isLoading = _isLoadingStats;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Aktivitas Terbaru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContentListScreen(),
                  ),
                );
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _recentContents.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada aktivitas',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aktivitas terbaru akan muncul di sini',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _recentContents.map((content) {
                          final createdAt = content.createdAt;
                          final timeText = dateFormat.format(createdAt);
                          final statusColor = _statusColor(content.status);
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.article_outlined,
                                color: statusColor,
                              ),
                            ),
                            title: Text(
                              content.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${content.categoryName} • $timeText',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                content.statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ContentListScreen(),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(ContentStatus status) {
    switch (status) {
      case ContentStatus.published:
        return Colors.green;
      case ContentStatus.approved:
        return Colors.blue;
      case ContentStatus.pending:
        return Colors.orange;
      case ContentStatus.rejected:
        return Colors.red;
      case ContentStatus.draft:
      default:
        return Colors.grey;
    }
  }
}
