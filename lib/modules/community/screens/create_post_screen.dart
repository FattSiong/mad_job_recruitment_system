import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/community_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String currentUserID;

  const CreatePostScreen({super.key, required this.currentUserID});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final CommunityService _communityService = CommunityService();

  bool _isLoading = false;
  File? _selectedFile; // Holds the chosen file

  // Function to open the device's file explorer
  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  // The Preview Dialog you used in Company Registration
  void _previewDocument(BuildContext context) {
    if (_selectedFile == null) return;

    final filePath = _selectedFile!.path.toLowerCase();
    final isImage = filePath.endsWith('.jpg') || filePath.endsWith('.jpeg') || filePath.endsWith('.png');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Attachment Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: isImage
                ? Image.file(_selectedFile!, fit: BoxFit.contain)
                : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                SizedBox(height: 16),
                Text('PDF Attached Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('(PDF preview requires physical device)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some text or an attachment.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedUrl;

      // 1. If a file was selected, upload it first
      if (_selectedFile != null) {
        uploadedUrl = await _communityService.uploadPostMedia(_selectedFile!, widget.currentUserID);
        if (uploadedUrl == null) {
          throw Exception('Failed to upload attachment.');
        }
      }

      // 2. Save the post to the database (with the URL if it exists)
      await _communityService.createCommunityPost(
        authorID: widget.currentUserID,
        content: content,
        mediaURL: uploadedUrl, // Passes the new URL
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post published successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _submitPost,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, color: Colors.blue),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'What do you want to talk about?',
                  border: InputBorder.none,
                ),
              ),
            ),

            // --- The Attached File UI ---
            if (_selectedFile != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedFile!.path.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile!.path.split(Platform.pathSeparator).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () => _previewDocument(context),
                      tooltip: 'Preview',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _selectedFile = null),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),

            const Divider(),

            // --- Interactive Buttons ---
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.grey),
                  onPressed: _pickDocument,
                  tooltip: 'Attach Image/Document',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}