import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_approval.dart';
import '../../models/content_model.dart';
import 'content_form_screen.dart';
import 'package:intl/intl.dart';

class ContentDetailScreen extends StatefulWidget {
  final int contentId;

  const ContentDetailScreen({
    Key? key,
    required this.contentId,
  }) : super(key: key);

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  void _loadContent() {
    final contentProvider = context.read<ContentProvider>();
    contentProvider.loadContentById(widget.contentId);
    contentProvider.loadApprovalHistory(widget.contentId);
  }

  Future<void> _handleSubmit() async {
    final confirmed = await _showConfirmDialog(
      'Submit Konten',
      'Submit konten untuk review? Staff akan mereview konten Anda.',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    final contentProvider = context.read<ContentProvider>();
    final response = await contentProvider.submitContent(widget.contentId);

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      _showSuccessSnackBar('Konten berhasil di-submit untuk review');
      _loadContent(); // Reload to update status
    } else {
      _showErrorSnackBar(response.message ?? 'Gagal submit konten');
    }
  }

  Future<void> _handleApprove() async {
    final notes = await _showNotesDialog('Accept Konten', isRequired: true);
    if (notes == null) return; // User cancelled

    setState(() => _isLoading = true);

    final contentProvider = context.read<ContentProvider>();
    final response = await contentProvider.approveContent(
      widget.contentId,
      notes: notes.isNotEmpty ? notes : null,
    );

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      _showSuccessSnackBar('Konten berhasil diterima');
      _loadContent();
    } else {
      _showErrorSnackBar(response.message ?? 'Gagal menerima konten');
    }
  }

  Future<void> _handlePublish() async {
    final notes = await _showNotesDialog('Publish Konten', isRequired: true);
    if (notes == null) return;

    setState(() => _isLoading = true);

    final contentProvider = context.read<ContentProvider>();
    final response = await contentProvider.publishContent(
      widget.contentId,
      notes: notes.isNotEmpty ? notes : null,
    );

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      _showSuccessSnackBar('Konten berhasil dipublikasikan!');
      _loadContent();
    } else {
      _showErrorSnackBar(response.message ?? 'Gagal publish konten');
    }
  }

  Future<void> _handleReject() async {
    final notes = await _showNotesDialog(
      'Reject Konten',
      isRequired: true,
      hint: 'Alasan penolakan wajib diisi',
    );

    if (notes == null || notes.isEmpty) return;

    setState(() => _isLoading = true);

    final contentProvider = context.read<ContentProvider>();
    final response = await contentProvider.rejectContent(
      widget.contentId,
      notes: notes,
    );

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      _showSuccessSnackBar('Konten telah ditolak');
      _loadContent();
    } else {
      _showErrorSnackBar(response.message ?? 'Gagal reject konten');
    }
  }

  Future<void> _handleEdit() async {
    final contentProvider = context.read<ContentProvider>();
    final content = contentProvider.currentContent;

    if (content == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContentFormScreen(content: content),
      ),
    );

    if (result == true) {
      _loadContent();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await _showConfirmDialog(
      'Hapus Konten',
      'Yakin ingin menghapus konten ini? Tindakan ini tidak dapat dibatalkan.',
      isDangerous: true,
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    final contentProvider = context.read<ContentProvider>();
    final response = await contentProvider.deleteContent(widget.contentId);

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      _showSuccessSnackBar('Konten berhasil dihapus');
      Navigator.pop(context, true); // Go back with result
    } else {
      _showErrorSnackBar(response.message ?? 'Gagal hapus konten');
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

  Future<String?> _showNotesDialog(
    String title, {
    required bool isRequired,
    String? hint,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Catatan',
            hintText: hint ?? 'Tambahkan catatan (opsional)',
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (isRequired && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Catatan wajib diisi'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _getLatestActionForRole(
    List<ContentApproval> history,
    String role,
  ) {
    ContentApproval? latest;
    for (final item in history) {
      if (item.approverRole != role) continue;
      if (latest == null || item.createdAt.isAfter(latest.createdAt)) {
        latest = item;
      }
    }
    return latest?.action.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = context.watch<ContentProvider>();
    final authProvider = context.watch<AuthProvider>();
    final content = contentProvider.currentContent;
    final user = authProvider.currentUser;
    final approvalHistory = contentProvider.approvalHistory ?? [];

    if (contentProvider.isLoading || content == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Konten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAuthor = user?.id == content.authorId;
    final isStaff = user?.role == 'Staff Jashumas';
    final isKasubbag = user?.role == 'Kasubbag Jashumas';
    final staffLatestAction =
        _getLatestActionForRole(approvalHistory, 'Staff Jashumas');
    final kasubbagLatestAction =
        _getLatestActionForRole(approvalHistory, 'Kasubbag Jashumas');
    final staffAccepted = staffLatestAction == 'approve';
    final kasubbagAccepted = kasubbagLatestAction == 'approve';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Konten'),
        actions: [
          // Edit button (for author on draft/rejected)
          if (isAuthor && (content.isDraft || content.isRejected))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _handleEdit,
              tooltip: 'Edit',
            ),

          // Delete button (for author or kasubbag)
          if (isAuthor || isKasubbag)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _handleDelete,
              tooltip: 'Hapus',
            ),

          // More menu
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('Lihat History'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'refresh') {
                _loadContent();
              } else if (value == 'history') {
                _showHistoryBottomSheet();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadContent(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Badge
            _buildStatusBadge(content),
            const SizedBox(height: 16),

            // Title
            Text(
              content.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Meta Info
            _buildMetaInfo(content),
            const SizedBox(height: 24),

            // Featured Image (if exists)
            if (content.featuredImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  content.featuredImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 64),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Excerpt
            if (content.excerpt != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  content.excerpt!,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Body
            Text(
              content.body,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            _buildActionButtons(
              content,
              isAuthor,
              isStaff,
              isKasubbag,
              staffAccepted: staffAccepted,
              kasubbagAccepted: kasubbagAccepted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Content content) {
    Color color;
    IconData icon;

    switch (content.status) {
      case ContentStatus.draft:
        color = Colors.grey;
        icon = Icons.drafts;
        break;
      case ContentStatus.pending:
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case ContentStatus.approved:
        color = Colors.blue;
        icon = Icons.check_circle;
        break;
      case ContentStatus.published:
        color = Colors.green;
        icon = Icons.public;
        break;
      case ContentStatus.rejected:
        color = Colors.red;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            content.statusText.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(Content content) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Column(
      children: [
        _MetaRow(
          icon: Icons.category,
          label: 'Kategori',
          value: content.categoryName,
        ),
        const SizedBox(height: 8),
        _MetaRow(
          icon: Icons.person,
          label: 'Penulis',
          value: content.authorName,
        ),
        const SizedBox(height: 8),
        _MetaRow(
          icon: Icons.access_time,
          label: 'Dibuat',
          value: dateFormat.format(content.createdAt),
        ),
        if (content.publishedAt != null) ...[
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.public,
            label: 'Dipublikasi',
            value: dateFormat.format(content.publishedAt!),
          ),
        ],
        if (content.isPublished) ...[
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.visibility,
            label: 'Views',
            value: '${content.views}',
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(
    Content content,
    bool isAuthor,
    bool isStaff,
    bool isKasubbag, {
    required bool staffAccepted,
    required bool kasubbagAccepted,
  }) {
    final buttons = <Widget>[];
    final canReview = content.isPending || content.isApproved;

    // Author actions
    if (isAuthor) {
      if (content.isDraft) {
        buttons.add(
          _ActionButton(
            label: 'Submit untuk Review',
            icon: Icons.send,
            color: Colors.blue,
            onPressed: _isLoading ? null : _handleSubmit,
          ),
        );
      }

      if (content.isDraft || content.isRejected) {
        buttons.add(
          _ActionButton(
            label: 'Edit Konten',
            icon: Icons.edit,
            color: Colors.orange,
            onPressed: _isLoading ? null : _handleEdit,
          ),
        );
      }
    }

    // Staff actions
    if (isStaff && canReview && !staffAccepted) {
      buttons.add(
        _ActionButton(
          label: 'Accept',
          icon: Icons.check_circle,
          color: Colors.green,
          onPressed: _isLoading ? null : _handleApprove,
        ),
      );
      buttons.add(
        _ActionButton(
          label: 'Reject',
          icon: Icons.cancel,
          color: Colors.red,
          onPressed: _isLoading ? null : _handleReject,
        ),
      );
    }

    // Kasubbag actions
    if (isKasubbag && canReview && !kasubbagAccepted) {
      buttons.add(
        _ActionButton(
          label: 'Accept',
          icon: Icons.check_circle,
          color: Colors.green,
          onPressed: _isLoading ? null : _handleApprove,
        ),
      );
      buttons.add(
        _ActionButton(
          label: 'Reject',
          icon: Icons.cancel,
          color: Colors.red,
          onPressed: _isLoading ? null : _handleReject,
        ),
      );
    }

    if (isKasubbag && content.isApproved && staffAccepted && kasubbagAccepted) {
      buttons.add(
        _ActionButton(
          label: 'Publish Konten',
          icon: Icons.public,
          color: Colors.green,
          onPressed: _isLoading ? null : _handlePublish,
        ),
      );
      buttons.add(
        _ActionButton(
          label: 'Reject',
          icon: Icons.cancel,
          color: Colors.red,
          onPressed: _isLoading ? null : _handleReject,
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons,
    );
  }

  void _showHistoryBottomSheet() {
    final contentProvider = context.read<ContentProvider>();
    final history = contentProvider.approvalHistory ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  const Text(
                    'History Approval',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: history.isEmpty
                  ? const Center(
                      child: Text('Belum ada history'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return _HistoryItem(approval: item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final ContentApproval approval;

  const _HistoryItem({required this.approval});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    Color actionColor;
    IconData actionIcon;

    switch (approval.action) {
      case 'submit':
        actionColor = Colors.blue;
        actionIcon = Icons.send;
        break;
      case 'approve':
        actionColor = Colors.green;
        actionIcon = Icons.check_circle;
        break;
      case 'reject':
        actionColor = Colors.red;
        actionIcon = Icons.cancel;
        break;
      case 'publish':
        actionColor = Colors.purple;
        actionIcon = Icons.public;
        break;
      default:
        actionColor = Colors.grey;
        actionIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(actionIcon, color: actionColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  approval.actionText,
                  style: TextStyle(
                    color: actionColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(approval.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${approval.approverName} (${approval.approverRole})',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (approval.notes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  approval.notes!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
