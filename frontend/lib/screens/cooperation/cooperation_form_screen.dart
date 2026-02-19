import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/cooperation_provider.dart';

class CooperationFormScreen extends StatefulWidget {
  const CooperationFormScreen({Key? key}) : super(key: key);

  @override
  State<CooperationFormScreen> createState() => _CooperationFormScreenState();
}

class _CooperationFormScreenState extends State<CooperationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _institutionController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isSubmitting = false;
  DateTime? _selectedDate;
  PlatformFile? _selectedDocument;
  final _dateFieldKey = GlobalKey<FormFieldState<DateTime>>();
  final _documentFieldKey = GlobalKey<FormFieldState<PlatformFile>>();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateController.text =
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
    });
    _dateFieldKey.currentState?.didChange(picked);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedDocument = result.files.first;
    });
    _documentFieldKey.currentState?.didChange(_selectedDocument);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedDocument == null) {
      _dateFieldKey.currentState?.validate();
      _documentFieldKey.currentState?.validate();
      return;
    }

    final docBytes = _selectedDocument!.bytes;
    if (docBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen tidak terbaca, silakan pilih ulang'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    const maxSizeBytes = 5 * 1024 * 1024;
    if (docBytes.length > maxSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran dokumen maksimal 5MB'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CooperationProvider>();
    final response = await provider.createCooperation(
      institutionName: _institutionController.text.trim(),
      contactName: _contactNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      purpose: _purposeController.text.trim(),
      eventDate: _selectedDate!,
      documentName: _selectedDocument!.name,
      documentMime: _selectedDocument!.extension != null
          ? 'application/${_selectedDocument!.extension}'
          : null,
      documentBase64: base64Encode(docBytes),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan kerjasama berhasil dikirim'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Gagal mengirim pengajuan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Pengajuan Kerjasama'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _institutionController,
              decoration: const InputDecoration(
                labelText: 'Nama Instansi *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama instansi wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kontak *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama kontak wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email wajib diisi';
                }
                if (!value.contains('@')) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'No. Telepon *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'No. telepon wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FormField<DateTime>(
              key: _dateFieldKey,
              validator: (value) {
                if (value == null) {
                  return 'Tanggal kegiatan wajib diisi';
                }
                return null;
              },
              builder: (state) {
                return TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Kegiatan *',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                    errorText: state.errorText,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FormField<PlatformFile>(
              key: _documentFieldKey,
              validator: (value) {
                if (value == null) {
                  return 'Dokumen pendukung wajib diunggah';
                }
                return null;
              },
              builder: (state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _selectedDocument == null
                            ? 'Unggah Dokumen *'
                            : 'Ganti Dokumen',
                      ),
                    ),
                    if (_selectedDocument != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _selectedDocument!.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (state.errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          state.errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Tujuan Kerjasama *',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tujuan kerjasama wajib diisi';
                }
                if (value.trim().length < 20) {
                  return 'Tujuan kerjasama minimal 20 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim Pengajuan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
