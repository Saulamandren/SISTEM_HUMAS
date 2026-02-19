import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';
import '../../widgets/sidebar.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({Key? key}) : super(key: key);

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories(activeOnly: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Konten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              categoryProvider.loadCategories(activeOnly: false);
            },
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: categoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : categoryProvider.categories.isEmpty
              ? const Center(child: Text('Tidak ada kategori'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categoryProvider.categories.length,
                  itemBuilder: (context, index) {
                    final category = categoryProvider.categories[index];
                    return _CategoryCard(
                      category: category,
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryFormScreen(
                              category: category,
                            ),
                          ),
                        ).then((_) {
                          categoryProvider.loadCategories(activeOnly: false);
                        });
                      },
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Hapus Kategori'),
                            content: Text(
                              'Yakin ingin menghapus kategori "${category.name}"?',
                            ),
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
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          final response = await categoryProvider
                              .deleteCategory(category.id);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  response.isSuccess
                                      ? 'Kategori berhasil dihapus'
                                      : response.message ??
                                          'Gagal hapus kategori',
                                ),
                                backgroundColor: response.isSuccess
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CategoryFormScreen(),
            ),
          ).then((_) {
            categoryProvider.loadCategories(activeOnly: false);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori'),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _parseColor(category.color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.article,
            color: _parseColor(category.color),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(category.description ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: category.isActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                category.isActive ? 'Aktif' : 'Nonaktif',
                style: TextStyle(
                  fontSize: 12,
                  color: category.isActive ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
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
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(
        int.parse(colorString.replaceAll('#', '0xFF')),
      );
    } catch (e) {
      return Colors.blue;
    }
  }
}
