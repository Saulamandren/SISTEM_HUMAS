// File: frontend/lib/screens/dashboard/staff_dashboard.dart

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'user_dashboard.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard Staff HUMAS'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.successColor, Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Staff HUMAS 👨‍💼',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola verifikasi konten dan pengajuan kerjasama',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Verification Queue Stats
            Text(
              'Antrean Verifikasi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 768 ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  context,
                  'Konten Pending',
                  '0',
                  Icons.pending_actions,
                  AppTheme.warningColor,
                ),
                _buildStatCard(
                  context,
                  'Kerjasama Pending',
                  '0',
                  Icons.business_outlined,
                  AppTheme.errorColor,
                ),
                _buildStatCard(
                  context,
                  'Terverifikasi Hari Ini',
                  '0',
                  Icons.check_circle_outline,
                  AppTheme.successColor,
                ),
                _buildStatCard(
                  context,
                  'Total User',
                  '0',
                  Icons.people_outline,
                  AppTheme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions for Staff
            Text('Aksi Cepat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionButton(
                  context,
                  'Verifikasi Konten',
                  Icons.verified_outlined,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur akan segera hadir')),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Tinjau Kerjasama',
                  Icons.rate_review_outlined,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur akan segera hadir')),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Lihat Audit Log',
                  Icons.history,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fitur akan segera hadir')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.successColor),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
