import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _regNumberController = TextEditingController();

  final _employerService = EmployerService();
  bool _isLoading = false;
  File? _selectedFile; // 👉 Variable to hold the chosen file

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;

  // 👉 Function to open the device's file explorer
  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  void _previewDocument(BuildContext context) {
    if (_selectedFile == null) return;

    final filePath = _selectedFile!.path.toLowerCase();
    final isImage = filePath.endsWith('.jpg') || filePath.endsWith('.jpeg') || filePath.endsWith('.png');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Document Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: isImage
                ? Image.file(
              _selectedFile!,
              fit: BoxFit.contain,
            )
            // 🛑 For PDFs, we bypass the emulator's native rendering limitations
                : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'PDF Attached Successfully!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '(PDF rendering is restricted on this emulator. Preview will function on a physical device.)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Future<void> _openLocationPicker() async {
  //   // Wait for the map screen to pop and hand back the data map
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => const CompanyMapPicker(),
  //     ),
  //   );
  //
  //   // If the user actually picked a location and didn't just hit the back button
  //   if (result != null && result is Map<String, dynamic>) {
  //     setState(() {
  //       _selectedLat = result['latitude'];
  //       _selectedLng = result['longitude'];
  //       _selectedAddress = result['address'];
  //     });
  //   }
  // }

  // 🚧 TEMPORARY BYPASS: Simulates picking a location until the map is ready
  void _openLocationPicker() {
    setState(() {
      // Inserting dummy coordinates for testing
      _selectedLat = 3.2162;
      _selectedLng = 101.7289;
      _selectedAddress = 'TAR UMT Campus, Setapak, Kuala Lumpur (Test Location)';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test location automatically inserted!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _submitCompany() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return;

    // 👉 Updated validation to require location
    if (_nameController.text.isEmpty ||
        _regNumberController.text.isEmpty ||
        _selectedFile == null ||
        _selectedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, Registration Number, Document, and Location are required'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? uploadedUrl = await _employerService.uploadVerificationDocument(
      _selectedFile!,
      _nameController.text,
    );

    if (uploadedUrl == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload document.')),
      );
      return;
    }

    final newCompany = CompanyModel(
      name: _nameController.text,
      description: _descriptionController.text,
      registrationNumber: _regNumberController.text,
      verificationDocumentURL: uploadedUrl,
      // 👉 Pass the coordinates to the model
      latitude: _selectedLat,
      longitude: _selectedLng,
    );

    final createdCompany = await _employerService.registerCompany(
      newCompany,
      currentUser.id,
    );

    setState(() => _isLoading = false);

    if (createdCompany != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company Registered! Awaiting Admin Approval.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Your Company')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _regNumberController,
            decoration: const InputDecoration(
              labelText: 'SSM / Registration Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Company HQ Location',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedAddress ?? 'No location selected yet.',
                  style: TextStyle(
                      fontSize: 16,
                      color: _selectedAddress == null ? Colors.red : Colors.black
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openLocationPicker,
                  icon: const Icon(Icons.map),
                  label: Text(_selectedLat == null ? 'Search or Pick on Map' : 'Change Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade900,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 👉 File selection UI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Show the actual file name instead of just "Document ready"
                Text(
                  _selectedFile == null
                      ? 'No document selected'
                      // Grabs just the file name from the long device path
                      : 'Selected: ${_selectedFile!.path.split(Platform.pathSeparator).last}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _selectedFile == null ? 'Upload PDF' : 'Change File',
                      ),
                    ),
                    // Only show the Review button IF a file has been picked
                    if (_selectedFile != null) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _previewDocument(context),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Review'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Company Description (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),

          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _submitCompany,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Submit for Verification',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }
}
