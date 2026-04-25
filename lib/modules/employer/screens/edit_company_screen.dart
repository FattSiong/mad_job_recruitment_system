import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';

class EditCompanyScreen extends StatefulWidget {
  final CompanyModel company;

  const EditCompanyScreen({super.key, required this.company});

  @override
  State<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends State<EditCompanyScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  final _employerService = EmployerService();
  bool _isSaving = false;
  File? _newProfileImage;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text fields with the existing data
    _nameController = TextEditingController(text: widget.company.name);
    _descriptionController = TextEditingController(text: widget.company.description);
  }

  // 👉 Function to pick a new profile image
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image, // Restrict to images only
    );

    if (result != null) {
      setState(() {
        _newProfileImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name cannot be empty.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await _employerService.updateCompanyDetails(
      companyId: widget.company.companyID!,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      newLogoFile: _newProfileImage,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company details updated successfully!'), backgroundColor: Colors.green),
        );
        // Pop back to the detail screen and return 'true' to trigger a refresh
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update company details.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Company Profile'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // --- PROFILE PICTURE UPLOAD ---
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade50,
                  // If they picked a new image, show it. Otherwise, show a placeholder (or their existing URL if you have one)
                  backgroundImage: _newProfileImage != null
                      ? FileImage(_newProfileImage!) as ImageProvider
                      : null,
                  child: _newProfileImage == null
                      ? Icon(Icons.business, size: 60, color: Colors.blue.shade200)
                      : null,
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _pickImage,
                    tooltip: 'Change Profile Picture',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- TEXT FIELDS ---
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Company Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 40),

          // --- SAVE BUTTON ---
          ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Changes', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}