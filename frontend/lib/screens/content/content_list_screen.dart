import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/content_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/content_model.dart';
import '../../widgets/sidebar.dart';
import 'content_form_screen.dart';
import 'content_detail_screen.dart';

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({Key? key}) : super(key: key);

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  String? _selectedStatus;
  int? _selectedCategoryId;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final contentProvider = context.read<ContentProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    categoryProvider.loadCategories();
    contentProvider.loadContents(
      status: _selectedStatus,
      categoryId: _selectedCategoryId,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  void _applyFilters() {
    final contentProvider = context.read<ContentProvider>();
    contentProvider.loadContents(
      status: _selectedStatus,
      categoryId: _selectedCategoryId,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategoryId = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = context.watch<ContentProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isStaff = user?.role == 'Staff Jashumas';
    final isKasubbag = user?.role == 'Kasubbag Jashumas';
    final isUser = user?.role == 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Konten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: Column(
        children: [
          if (isUser == true) _buildUserNotification(contentProvider.contents),
          // Filter Section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        onPressed: _clearFilters,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari konten...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Status Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Semua Status'),
                            ),
                            ...ContentStatus.values.map((status) {
                              return DropdownMenuItem<String>(
                                value: status.value,
                                child: Text(status.displayName),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category Filter
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Semua Kategori'),
                            ),
                            ...categoryProvider.categories
                                .map<DropdownMenuItem<int>>((category) {
                              return DropdownMenuItem<int>(
                                value: category.id,
                                child: Text(category.name),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: contentProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : contentProvider.contents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada konten',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: contentProvider.contents.length,
                        itemBuilder: (context, index) {
                          final content = contentProvider.contents[index];
                          final actions = _buildContentActions(
                            content,
                            isStaff: isStaff,
                            isKasubbag: isKasubbag,
                          );
                          return _ContentCard(
                            content: content,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ContentDetailScreen(
                                    contentId: content.id,
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            actions: actions,
                            onActionSelected: (action) {
                              _handleContentAction(content, action);
                            },
                          );
                        },
                      ),
          ),

          // Pagination
          if (contentProvider.paginatedContent != null &&
              contentProvider.totalPages > 1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                    onPressed: contentProvider.hasPreviousPage
                        ? () {
                            contentProvider.loadContents(
                              page: contentProvider.currentPage - 1,
                              status: _selectedStatus,
                              categoryId: _selectedCategoryId,
                              search: _searchController.text.isNotEmpty
                                  ? _searchController.text
                                  : null,
                            );
                          }
                        : null,
                  ),
                  Text(
                    'Halaman ${contentProvider.currentPage} dari ${contentProvider.totalPages}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                    onPressed: contentProvider.hasNextPage
                        ? () {
                            contentProvider.loadContents(
                              page: contentProvider.currentPage + 1,
                              status: _selectedStatus,
                              categoryId: _selectedCategoryId,
                              search: _searchController.text.isNotEmpty
                                  ? _searchController.text
                                  : null,
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContentFormScreen(),
            ),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.add),
        label: const Text('Buat Konten'),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PopupMenuEntry<String>> _buildContentActions(
    Content content, {
    required bool isStaff,
    required bool isKasubbag,
  }) {
    final actions = <PopupMenuEntry<String>>[];

    if (isStaff && content.status == ContentStatus.pending) {
      actions.add(
        const PopupMenuItem(
          value: 'approve',
          child: Text('Terima (Approve)'),
        ),
      );
      actions.add(
        const PopupMenuItem(
          value: 'reject',
          child: Text('Tolak'),
        ),
      );
    }

    if (isKasubbag) {
      if (content.status == ContentStatus.pending) {
        actions.add(
          const PopupMenuItem(
            value: 'approve',
            child: Text('Terima (Approve)'),
          ),
        );
        actions.add(
          const PopupMenuItem(
            value: 'reject',
            child: Text('Tolak'),
          ),
        );
      } else if (content.status == ContentStatus.approved) {
        actions.add(
          const PopupMenuItem(
            value: 'publish',
            child: Text('Publikasikan'),
          ),
        );
        actions.add(
          const PopupMenuItem(
            value: 'reject',
            child: Text('Tolak'),
          ),
        );
      }
    }

    return actions;
  }

  Future<void> _handleContentAction(Content content, String action) async {
    final contentProvider = context.read<ContentProvider>();

    if (action == 'approve') {
      final notes = await _showNotesDialog(
        title: 'Terima Konten',
        isRequired: true,
      );
      if (notes == null || notes.isEmpty) return;
      final response =
          await contentProvider.approveContent(content.id, notes: notes);
      _showActionSnackBar(response.isSuccess,
          response.message ?? 'Approve konten selesai');
      _loadData();
      return;
    }

    if (action == 'publish') {
      final notes = await _showNotesDialog(
        title: 'Publikasikan Konten',
        isRequired: true,
      );
      if (notes == null) return;
      final response =
          await contentProvider.publishContent(content.id, notes: notes);
      _showActionSnackBar(response.isSuccess,
          response.message ?? 'Publikasi konten selesai');
      _loadData();
      return;
    }

    if (action == 'reject') {
      final notes = await _showNotesDialog(
        title: 'Tolak Konten',
        isRequired: true,
      );
      if (notes == null || notes.isEmpty) return;
      final response =
          await contentProvider.rejectContent(content.id, notes: notes);
      _showActionSnackBar(response.isSuccess,
          response.message ?? 'Konten ditolak');
      _loadData();
    }
  }

  Future<String?> _showNotesDialog({
    required String title,
    required bool isRequired,
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
            hintText: isRequired
                ? 'Catatan wajib diisi'
                : 'Catatan (opsional)',
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

  void _showActionSnackBar(bool success, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildUserNotification(List<Content> contents) {
    final approvedCount =
        contents.where((c) => c.status == ContentStatus.approved).length;
    final publishedCount =
        contents.where((c) => c.status == ContentStatus.published).length;
    final rejectedCount =
        contents.where((c) => c.status == ContentStatus.rejected).length;

    if (approvedCount == 0 && publishedCount == 0 && rejectedCount == 0) {
      return const SizedBox.shrink();
    }

    final messages = <String>[];
    if (approvedCount > 0) {
      messages.add('$approvedCount konten disetujui');
    }
    if (publishedCount > 0) {
      messages.add('$publishedCount konten dipublikasikan');
    }
    if (rejectedCount > 0) {
      messages.add('$rejectedCount konten ditolak');
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notifikasi: ${messages.join(', ')}. '
                'Cek detail konten untuk melihat catatan.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final Content content;
  final VoidCallback onTap;
  final List<PopupMenuEntry<String>> actions;
  final void Function(String action)? onActionSelected;

  const _ContentCard({
    required this.content,
    required this.onTap,
    this.actions = const [],
    this.onActionSelected,
  });

  Color _getStatusColor() {
    switch (content.status) {
      case ContentStatus.draft:
        return Colors.grey;
      case ContentStatus.pending:
        return Colors.orange;
      case ContentStatus.approved:
        return Colors.blue;
      case ContentStatus.published:
        return Colors.green;
      case ContentStatus.rejected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          content.categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      content.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (actions.isNotEmpty)
                    PopupMenuButton<String>(
                      onSelected: onActionSelected,
                      itemBuilder: (context) => actions,
                    ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                content.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (content.excerpt != null) ...[
                const SizedBox(height: 8),
                Text(
                  content.excerpt!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              // Meta Info
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    content.authorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(content.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (content.isPublished) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${content.views} views',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} menit lalu';
      }
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
