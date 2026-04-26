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
  File? _selectedFile;

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

  // The Preview Dialog
  void _previewDocument(BuildContext context) {
    if (_selectedFile == null) return;

    final filePath = _selectedFile!.path.toLowerCase();
    final isImage = filePath.endsWith('.jpg') || filePath.endsWith('.jpeg') || filePath.endsWith('.png');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Attachment Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: isImage
                ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedFile!, fit: BoxFit.contain)
            )
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
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.black87))
            ),
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
        mediaURL: uploadedUrl,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Create Post', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
            child: _isLoading
                ? const Center(
                child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                )
            )
                : TextButton(
              onPressed: _submitPost,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF6B8BFE).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Post', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // User Header inside create post
              Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.grey[200], child: const Icon(Icons.person, color: Colors.grey)),
                  const SizedBox(width: 12),
                  const Text('Posting to Community', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'What do you wanna post?',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
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
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(
                          _selectedFile!.path.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                          color: const Color(0xFF6B8BFE),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile!.path.split(Platform.pathSeparator).last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, color: Colors.black54),
                        onPressed: () => _previewDocument(context),
                        tooltip: 'Preview',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => setState(() => _selectedFile = null),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1),

              // --- Interactive Buttons (Bottom Bar) ---
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _pickDocument,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Row(
                          children: [
                            Icon(Icons.image_outlined, color: Color(0xFF6B8BFE)),
                            SizedBox(width: 8),
                            Text('Attach Media', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.w600))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}