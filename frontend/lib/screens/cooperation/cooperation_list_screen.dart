import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cooperation_provider.dart';
import '../../models/cooperation_model.dart';
import '../../models/response_model.dart';
import '../../widgets/sidebar.dart';
import '../../utils/file_viewer.dart';
import 'cooperation_form_screen.dart';

class CooperationListScreen extends StatefulWidget {
  const CooperationListScreen({Key? key}) : super(key: key);

  @override
  State<CooperationListScreen> createState() => _CooperationListScreenState();
}

class _CooperationListScreenState extends State<CooperationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CooperationProvider>().loadCooperations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final coopProvider = context.watch<CooperationProvider>();
    final user = authProvider.currentUser;
    final isStaff = user?.role == 'Staff Jashumas';
    final isKasubbag = user?.role == 'Kasubbag Jashumas';
    final hasAccepted = !isStaff &&
        !isKasubbag &&
        coopProvider.items.any((item) => item.status == 'approved');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Kerjasama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              coopProvider.loadCooperations();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: RefreshIndicator(
        onRefresh: () => coopProvider.loadCooperations(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.handshake_outlined,
                        color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isStaff || isKasubbag
                            ? 'Kelola dan tinjau pengajuan kerjasama dari pengguna.'
                            : 'Ajukan kerjasama dan pantau status pengajuan Anda di sini.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (hasAccepted)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pengajuan kerja sama Anda telah diterima.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasAccepted) const SizedBox(height: 12),
            if (coopProvider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  coopProvider.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            if (coopProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (coopProvider.items.isEmpty)
              _buildEmptyState(context, isStaff || isKasubbag)
            else
              ...coopProvider.items.map(
                (item) => _buildCoopCard(
                  context,
                  item,
                  isStaff: isStaff,
                  isKasubbag: isKasubbag,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CooperationFormScreen(),
            ),
          );
          if (result == true) {
            coopProvider.loadCooperations();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(
          isStaff || isKasubbag ? 'Buat Pengajuan' : 'Ajukan Kerjasama',
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isAdminView) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                'Belum ada pengajuan kerjasama',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAdminView
                    ? 'Pengajuan dari pengguna akan muncul di sini.'
                    : 'Gunakan tombol di bawah untuk membuat pengajuan.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoopCard(
    BuildContext context,
    Cooperation item, {
    required bool isStaff,
    required bool isKasubbag,
  }) {
    final statusColor = _statusColor(item.status);
    final dateText = DateFormat('dd MMM yyyy').format(item.eventDate);
    final actions = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'detail',
        child: Text('Lihat Detail'),
      ),
    ];

    if (isStaff && item.status == 'pending') {
      actions.add(
        const PopupMenuItem(
          value: 'verify',
          child: Text('Terima (Verifikasi)'),
        ),
      );
      actions.add(
        const PopupMenuItem(
          value: 'reject',
          child: Text('Tolak'),
        ),
      );
    }

    if (isKasubbag && item.status == 'verified') {
      actions.add(
        const PopupMenuItem(
          value: 'approve',
          child: Text('Terima (Setujui)'),
        ),
      );
      actions.add(
        const PopupMenuItem(
          value: 'reject',
          child: Text('Tolak'),
        ),
      );
    }

    if (isKasubbag && item.status == 'pending') {
      actions.add(
        const PopupMenuItem(
          value: 'reject',
          child: Text('Tolak'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.handshake_outlined, color: statusColor),
        ),
        title: Text(
          item.institutionName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${item.contactName} • $dateText',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(item.status),
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleAction(context, item, value),
              itemBuilder: (context) => actions,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'DIVERIFIKASI';
      case 'approved':
        return 'DITERIMA';
      case 'rejected':
        return 'DITOLAK';
      case 'pending':
      default:
        return 'PENDING';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'verified':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    Cooperation item,
    String action,
  ) async {
    if (action == 'detail') {
      final user = context.read<AuthProvider>().currentUser;
      final canViewDocument = user?.role == 'Staff Jashumas' ||
          user?.role == 'Kasubbag Jashumas';
      await _showDetailDialog(
        context,
        item,
        canViewDocument: canViewDocument,
      );
      return;
    }

    final provider = context.read<CooperationProvider>();
    final actionLabel = action == 'approve'
        ? 'setujui'
        : action == 'verify'
            ? 'verifikasi'
            : 'tolak';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi $actionLabel'),
        content: Text(
          'Apakah Anda yakin ingin $actionLabel pengajuan ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'reject' ? Colors.red : null,
            ),
            child: const Text('Ya'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ApiResponse<void> response;
    if (action == 'verify') {
      response = await provider.verifyCooperation(item.id);
    } else if (action == 'approve') {
      response = await provider.approveCooperation(item.id);
    } else {
      response = await provider.rejectCooperation(item.id);
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.isSuccess
              ? 'Aksi berhasil'
              : response.message ?? 'Aksi gagal',
        ),
        backgroundColor: response.isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showDetailDialog(
    BuildContext context,
    Cooperation item, {
    required bool canViewDocument,
  }) async {
    final dateText = DateFormat('dd MMM yyyy').format(item.eventDate);
    final createdText = DateFormat('dd MMM yyyy, HH:mm')
        .format(item.createdAt.toLocal());

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Pengajuan Kerjasama'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Instansi', item.institutionName),
              _buildDetailRow('Nama Kontak', item.contactName),
              _buildDetailRow('Email', item.email),
              _buildDetailRow('Telepon', item.phone),
              _buildDetailRow('Tanggal Kegiatan', dateText),
              _buildDetailRow('Dokumen', item.documentName),
              _buildDetailRow('Status', _statusLabel(item.status)),
              _buildDetailRow('Diajukan', createdText),
              const SizedBox(height: 8),
              const Text(
                'Tujuan Kerjasama',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(item.purpose),
            ],
          ),
        ),
        actions: [
          if (canViewDocument)
            TextButton.icon(
              onPressed: () => _viewDocument(context, item),
              icon: const Icon(Icons.visibility),
              label: const Text('Lihat Dokumen'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _viewDocument(BuildContext context, Cooperation item) async {
    final provider = context.read<CooperationProvider>();
    final response = await provider.getDocument(item.id);

    if (!context.mounted) return;

    if (!response.isSuccess || response.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Gagal membuka dokumen'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = response.data!;
    final base64Data = data['document_base64'] as String?;
    final fileName = data['document_name'] as String? ?? 'document';
    final mimeType = data['document_mime'] as String? ?? 'application/pdf';

    if (base64Data == null || base64Data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen tidak tersedia'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await openDocumentFromBase64(
        base64Data: base64Data,
        fileName: fileName,
        mimeType: mimeType,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa membuka dokumen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
