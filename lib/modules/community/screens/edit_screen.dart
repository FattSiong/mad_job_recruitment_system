import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/community_service.dart';

class EditScreen extends StatefulWidget {
  final String targetID;
  final String initialContent;
  final String? initialMediaURL; // 👈 NEW: Accepts the existing image URL
  final String currentUserID;    // 👈 NEW: Needed for uploading files
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
      appBar: AppBar(
        title: Text(widget.isPost ? 'Edit Post' : 'Edit Comment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.blueAccent),
            onPressed: _isSaving ? null : _saveChanges,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),

              // --- Media Preview UI ---
              if (_currentMediaURL != null || _selectedNewFile != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_currentMediaURL?.contains('.pdf') ?? false) || (_selectedNewFile?.path.endsWith('.pdf') ?? false)
                            ? Icons.picture_as_pdf
                            : Icons.image,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedNewFile != null
                              ? _selectedNewFile!.path.split(Platform.pathSeparator).last // Show new file name
                              : "Existing Attachment", // Show generic text for old network file
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _removeMedia, // Deletes the image entirely
                        tooltip: 'Remove Attachment',
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(),

              // --- Bottom Toolbar ---
              if (widget.isPost) // Only allow media attachments for Posts
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.grey),
                      onPressed: _pickDocument,
                      tooltip: 'Change/Add Attachment',
                    ),
                    const Text("Attach Image/PDF", style: TextStyle(color: Colors.grey)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}