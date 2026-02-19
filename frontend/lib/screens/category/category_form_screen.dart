import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';

class CategoryFormScreen extends StatefulWidget {
  final Category? category;

  const CategoryFormScreen({Key? key, this.category}) : super(key: key);

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIcon = 'article';
  String _selectedColor = '#1976D2';
  bool _isLoading = false;

  bool get isEditMode => widget.category != null;

  final List<Map<String, dynamic>> _iconOptions = [
    {'icon': Icons.article, 'name': 'article'},
    {'icon': Icons.newspaper, 'name': 'newspaper'},
    {'icon': Icons.campaign, 'name': 'campaign'},
    {'icon': Icons.event, 'name': 'event'},
    {'icon': Icons.emoji_events, 'name': 'emoji_events'},
  ];

  final List<String> _colorOptions = [
    '#1976D2', // Blue
    '#F57C00', // Orange
    '#388E3C', // Green
    '#7B1FA2', // Purple
    '#D32F2F', // Red
  ];

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _selectedIcon = widget.category!.icon;
      _selectedColor = widget.category!.color;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final categoryProvider = context.read<CategoryProvider>();

    final response = isEditMode
        ? await categoryProvider.updateCategory(
            id: widget.category!.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            icon: _selectedIcon,
            color: _selectedColor,
          )
        : await categoryProvider.createCategory(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            icon: _selectedIcon,
            color: _selectedColor,
          );

    setState(() => _isLoading = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.isSuccess
                ? (isEditMode
                    ? 'Kategori berhasil diperbarui'
                    : 'Kategori berhasil dibuat')
                : response.message ?? 'Terjadi kesalahan',
          ),
          backgroundColor: response.isSuccess ? Colors.green : Colors.red,
        ),
      );

      if (response.isSuccess) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Kategori' : 'Tambah Kategori'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kategori *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama kategori tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Deskripsi tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _iconOptions.map((option) {
                final isSelected = _selectedIcon == option['name'];
                return ChoiceChip(
                  label: Icon(option['icon'] as IconData),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedIcon = option['name']);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Warna:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _colorOptions.map((color) {
                final isSelected = _selectedColor == color;
                return ChoiceChip(
                  label: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceAll('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedColor = color);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(isEditMode ? 'Simpan Perubahan' : 'Tambah Kategori'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
