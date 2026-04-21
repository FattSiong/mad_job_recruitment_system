import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  // void _previewDocument(BuildContext context) {
  //   if (_selectedFile == null) return;
  //
  //   // 1. Grab the file path and make it lowercase to check the extension safely
  //   final filePath = _selectedFile!.path.toLowerCase();
  //
  //   // 2. Determine what type of file we are dealing with
  //   final isImage =
  //       filePath.endsWith('.jpg') ||
  //       filePath.endsWith('.jpeg') ||
  //       filePath.endsWith('.png');
  //   final isPdf = filePath.endsWith('.pdf');
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Document Preview'),
  //         content: SizedBox(
  //           width: double.maxFinite,
  //           height: MediaQuery.of(context).size.height * 0.6,
  //           // 3. Show the correct widget based on the file type!
  //           child: isImage
  //               ? Image.file(
  //                   _selectedFile!,
  //                   fit: BoxFit
  //                       .contain, // Ensures the image fits inside the box without stretching
  //                 )
  //               : isPdf
  //               // 👉 CHANGED HERE: We read the file into raw bytes immediately
  //               ? SfPdfViewer.memory(
  //                   _selectedFile!.readAsBytesSync(),
  //                   onDocumentLoadFailed:
  //                       (PdfDocumentLoadFailedDetails details) {
  //                         print('🔥🔥🔥 PDF Load Error: ${details.error}');
  //                       },
  //                 )
  //               : const Center(
  //                   child: Text(
  //                     'Unsupported file format.\nPlease select a PDF, JPG, or PNG.',
  //                     textAlign: TextAlign.center,
  //                   ),
  //                 ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Close'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

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

  Future<void> _submitCompany() async {
    if (_nameController.text.isEmpty ||
        _regNumberController.text.isEmpty ||
        _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, Registration Number, and Document are required'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Upload the file first to get the URL
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

    // 2. Create the company model WITH the new URL
    final newCompany = CompanyModel(
      name: _nameController.text,
      description: _descriptionController.text,
      registrationNumber: _regNumberController.text,
      verificationDocumentURL: uploadedUrl,
    );

    // 3. Save to database
    final createdCompany = await _employerService.registerCompany(
      newCompany,
      '469885d6-45ac-4e96-b11f-a95fb0bafd78',
    );

    setState(() => _isLoading = false);

    if (createdCompany != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company Registered! Awaiting Admin Approval.')),
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
