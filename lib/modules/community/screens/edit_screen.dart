import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/community_service.dart';

class EditScreen extends StatefulWidget {
  final String targetID;
  final String initialContent;
  final String? initialMediaURL;
  final String currentUserID;
  final bool isPost;

  const EditScreen({
    Key? key,
    required this.targetID,
    required this.initialContent,
    this.initialMediaURL,
    required this.currentUserID,
    required this.isPost,
  }) : super(key: key);

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final CommunityService _communityService = CommunityService();
  late TextEditingController _contentController;

  bool _isSaving = false;

  // Media State Variables
  String? _currentMediaURL; // Holds the URL if keeping the old image
  File? _selectedNewFile;   // Holds a newly picked file

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _currentMediaURL = widget.initialMediaURL; // Start with the existing image
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // Same picker logic from your Create Screen
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedNewFile = File(result.files.single.path!);
          _currentMediaURL = null; // Wipe the old URL because we have a new file
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedNewFile = null;
      _currentMediaURL = null; // Wiping both means the post will have NO media
    });
  }

  Future<void> _saveChanges() async {
    final updatedText = _contentController.text.trim();

    // Check if anything ACTUALLY changed
    bool textChanged = updatedText != widget.initialContent;
    bool mediaChanged = (_currentMediaURL != widget.initialMediaURL) || (_selectedNewFile != null);

    if (updatedText.isEmpty && _currentMediaURL == null && _selectedNewFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post cannot be completely empty.")));
      return;
    }

    if (!textChanged && !mediaChanged) {
      Navigator.pop(context, false); // No changes made, just go back
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalMediaUrl = _currentMediaURL;

      // If they picked a NEW file, upload it first!
      if (_selectedNewFile != null) {
        finalMediaUrl = await _communityService.uploadPostMedia(_selectedNewFile!, widget.currentUserID);
        if (finalMediaUrl == null) throw Exception("Failed to upload new attachment.");
      }

      if (widget.isPost) {
        await _communityService.editPost(widget.targetID, updatedText, finalMediaUrl);
      } else {
        // Comments usually don't have images in this UI, but we leave the text update here
        await _communityService.editComment(widget.targetID, updatedText);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
        Navigator.pop(context, true); // Return 'true' to refresh the feed
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
            widget.isPost ? 'Edit Post' : 'Edit Comment',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
            child: _isSaving
                ? const Center(
                child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                )
            )
                : TextButton(
              onPressed: _saveChanges,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF6B8BFE).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Save', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // User Header inside edit screen
              Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.grey[200], child: const Icon(Icons.person, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Text(
                      widget.isPost ? 'Editing Post' : 'Editing Comment',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)
                  ),
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
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                    border: InputBorder.none,
                  ),
                ),
              ),

              // --- Media Preview UI ---
              if (_currentMediaURL != null || _selectedNewFile != null) ...[
                const SizedBox(height: 12),
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
                          (_currentMediaURL?.contains('.pdf') ?? false) || (_selectedNewFile?.path.endsWith('.pdf') ?? false)
                              ? Icons.picture_as_pdf
                              : Icons.image,
                          color: const Color(0xFF6B8BFE),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedNewFile != null
                              ? _selectedNewFile!.path.split(Platform.pathSeparator).last
                              : "Existing Attachment",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: _removeMedia,
                        tooltip: 'Remove Attachment',
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 1),

              // --- Bottom Toolbar ---
              if (widget.isPost) // Only allow media attachments for Posts
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
                              Text('Change Media', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.w600))
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}