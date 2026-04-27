import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/community_service.dart';

const Color _createInk = Color(0xFF172033);
const Color _createPrimary = Color(0xFF1E4C8F);
const Color _createMuted = Color(0xFF6B7890);
const Color _createSoft = Color(0xFFEAF2FF);
const Color _createBorder = Color(0xFFD5E2F3);
const Color _createBackground = Color(0xFFF4F7FB);
const Color _createSurface = Color(0xFFF8FBFF);

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

  bool get _hasContent => _contentController.text.trim().isNotEmpty;

  bool get _isImageAttachment {
    final filePath = _selectedFile?.path.toLowerCase() ?? '';
    return filePath.endsWith('.jpg') ||
        filePath.endsWith('.jpeg') ||
        filePath.endsWith('.png');
  }

  String get _attachmentName =>
      _selectedFile?.path.split(Platform.pathSeparator).last ?? '';

  Future<void> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  void _previewDocument(BuildContext context) {
    if (_selectedFile == null) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Attachment Preview',
            style: TextStyle(
              color: _createInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.48,
            child: _isImageAttachment
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(_selectedFile!, fit: BoxFit.contain),
                  )
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _createSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _createBorder),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 72,
                          color: _createPrimary,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'PDF attached successfully',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _createInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'The file is ready to be published with your post.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _createMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: _createPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some text or an attachment.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedUrl;

      if (_selectedFile != null) {
        uploadedUrl = await _communityService.uploadPostMedia(
          _selectedFile!,
          widget.currentUserID,
        );
        if (uploadedUrl == null) {
          throw Exception('Failed to upload attachment.');
        }
      }

      await _communityService.createCommunityPost(
        authorID: widget.currentUserID,
        content: content,
        mediaURL: uploadedUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAttachmentCard(BuildContext context) {
    if (_selectedFile == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _createBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _createSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _isImageAttachment
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_rounded,
              color: _createPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _attachmentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _createInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isImageAttachment ? 'Image ready to share' : 'PDF ready to share',
                  style: const TextStyle(
                    color: _createMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _previewDocument(context),
            tooltip: 'Preview',
            icon: const Icon(
              Icons.visibility_outlined,
              color: _createPrimary,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedFile = null),
            tooltip: 'Remove',
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _createBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _createPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _createPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _createBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE9F1FB),
              Color(0xFFF4F7FB),
              Color(0xFFF8FAFD),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF163B65),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Post',
                            style: TextStyle(
                              color: _createInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _createBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Posting to Community',
                                        style: TextStyle(
                                          color: _createInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                              decoration: BoxDecoration(
                                color: _createSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _createBorder),
                              ),
                              child: TextField(
                                controller: _contentController,
                                maxLines: null,
                                minLines: 8,
                                autofocus: true,
                                keyboardType: TextInputType.multiline,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  color: _createInk,
                                  fontSize: 17,
                                  height: 1.55,
                                ),
                                decoration: const InputDecoration(
                                  hintText:
                                      'What do you want to share today?\n\nTry a progress update, question, idea, or helpful resource.',
                                  hintStyle: TextStyle(
                                    color: _createMuted,
                                    fontSize: 17,
                                    height: 1.55,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 16),
                        _buildAttachmentCard(context),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: _createBorder.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildActionChip(
                            icon: Icons.attach_file_rounded,
                            label: 'Attach Media',
                            onTap: _pickDocument,
                          ),
                          const Spacer(),
                          Text(
                            _hasContent || _selectedFile != null
                                ? 'Ready to publish'
                                : 'Add text or media',
                            style: const TextStyle(
                              color: _createMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _createPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _createPrimary.withValues(alpha: 0.55),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Publish Post',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateHintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CreateHintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _createSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _createPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _createPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
