import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/content_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/content_model.dart';

class ContentFormScreen extends StatefulWidget {
  final Content? content; // Null = Create mode, Not null = Edit mode

  const ContentFormScreen({
    Key? key,
    this.content,
  }) : super(key: key);

  @override
  State<ContentFormScreen> createState() => _ContentFormScreenState();
}

class _ContentFormScreenState extends State<ContentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _excerptController = TextEditingController();
  final _bodyController = TextEditingController();

  int? _selectedCategoryId;
  bool _isLoading = false;

  bool get isEditMode => widget.content != null;

  @override
  void initState() {
    super.initState();

    // Load categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });

    // If edit mode, populate form
    if (isEditMode) {
      _titleController.text = widget.content!.title;
      _excerptController.text = widget.content!.excerpt ?? '';
      _bodyController.text = widget.content!.body;
      _selectedCategoryId = widget.content!.categoryId;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      _showErrorSnackBar('Pilih kategori terlebih dahulu');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final contentProvider = context.read<ContentProvider>();

    try {
      final response = isEditMode
          ? await contentProvider.updateContent(
              id: widget.content!.id,
              title: _titleController.text.trim(),
              body: _bodyController.text.trim(),
              categoryId: _selectedCategoryId!,
              excerpt: _excerptController.text.trim().isNotEmpty
                  ? _excerptController.text.trim()
                  : null,
            )
          : await contentProvider.createContent(
              title: _titleController.text.trim(),
              body: _bodyController.text.trim(),
              categoryId: _selectedCategoryId!,
              excerpt: _excerptController.text.trim().isNotEmpty
                  ? _excerptController.text.trim()
                  : null,
            );

      if (response.isSuccess) {
        if (mounted) {
          _showSuccessSnackBar(
            isEditMode
                ? 'Konten berhasil diperbarui'
                : 'Konten berhasil dibuat',
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        _showErrorSnackBar(response.message ?? 'Terjadi kesalahan');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Konten' : 'Buat Konten Baru'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _handleSubmit,
              child: Text(
                isEditMode ? 'Simpan' : 'Buat',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditMode
                            ? 'Perbarui konten Anda. Status akan kembali menjadi Draft setelah disimpan.'
                            : 'Konten akan disimpan sebagai Draft. Anda bisa submit untuk review setelah selesai.',
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
            const SizedBox(height: 24),

            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Judul Konten *',
                hintText: 'Masukkan judul konten',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              maxLength: 255,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul tidak boleh kosong';
                }
                if (value.trim().length < 10) {
                  return 'Judul minimal 10 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: 'Kategori *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.category),
              ),
              hint: const Text('Pilih kategori'),
              items: categoryProvider.categories
                  .map<DropdownMenuItem<int>>((category) {
                return DropdownMenuItem<int>(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Pilih kategori';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Excerpt Field (Optional)
            TextFormField(
              controller: _excerptController,
              decoration: InputDecoration(
                labelText: 'Ringkasan (Opsional)',
                hintText: 'Ringkasan singkat konten',
                helperText: 'Kosongkan untuk auto-generate dari body',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.short_text),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // Body Field
            TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: 'Isi Konten *',
                hintText: 'Tulis konten Anda di sini...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              minLines: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Isi konten tidak boleh kosong';
                }
                if (value.trim().length < 50) {
                  return 'Isi konten minimal 50 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Character Count Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Judul',
                    '${_titleController.text.length}/255',
                    Icons.title,
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade400),
                  _buildStatItem(
                    'Ringkasan',
                    '${_excerptController.text.length}/500',
                    Icons.short_text,
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade400),
                  _buildStatItem(
                    'Isi',
                    '${_bodyController.text.length}',
                    Icons.article,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(isEditMode ? 'Simpan Perubahan' : 'Buat Konten'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _excerptController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
