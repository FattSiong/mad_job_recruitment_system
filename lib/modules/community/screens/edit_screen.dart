import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/community_service.dart';

const Color _editInk = Color(0xFF172033);
const Color _editPrimary = Color(0xFF1E4C8F);
const Color _editMuted = Color(0xFF6B7890);
const Color _editSoft = Color(0xFFEAF2FF);
const Color _editBorder = Color(0xFFD5E2F3);
const Color _editBackground = Color(0xFFF4F7FB);
const Color _editSurface = Color(0xFFF8FBFF);

class EditScreen extends StatefulWidget {
  final String targetID;
  final String initialContent;
  final String? initialMediaURL;
  final String currentUserID;
  final bool isPost;

  const EditScreen({
    super.key,
    required this.targetID,
    required this.initialContent,
    this.initialMediaURL,
    required this.currentUserID,
    required this.isPost,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final CommunityService _communityService = CommunityService();
  late final TextEditingController _contentController;

  bool _isSaving = false;
  String? _currentMediaURL;
  File? _selectedNewFile;

  bool get _hasDraftContent => _contentController.text.trim().isNotEmpty;

  bool get _hasMedia => _currentMediaURL != null || _selectedNewFile != null;

  bool get _isImageAttachment {
    final localPath = _selectedNewFile?.path.toLowerCase() ?? '';
    final remotePath = _currentMediaURL?.toLowerCase() ?? '';
    return localPath.endsWith('.jpg') ||
        localPath.endsWith('.jpeg') ||
        localPath.endsWith('.png') ||
        remotePath.endsWith('.jpg') ||
        remotePath.endsWith('.jpeg') ||
        remotePath.endsWith('.png') ||
        remotePath.contains('image');
  }

  String get _attachmentName {
    if (_selectedNewFile != null) {
      return _selectedNewFile!.path.split(Platform.pathSeparator).last;
    }

    final mediaUrl = _currentMediaURL ?? '';
    if (mediaUrl.isEmpty) {
      return '';
    }

    return mediaUrl.split('/').last.split('?').first;
  }

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _currentMediaURL = widget.initialMediaURL;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedNewFile = File(result.files.single.path!);
          _currentMediaURL = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _removeMedia() {
    setState(() {
      _selectedNewFile = null;
      _currentMediaURL = null;
    });
  }

  void _previewMedia(BuildContext context) {
    if (!_hasMedia) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            widget.isPost ? 'Attachment Preview' : 'Preview',
            style: const TextStyle(
              color: _editInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.48,
            child: _isImageAttachment
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _selectedNewFile != null
                        ? Image.file(_selectedNewFile!, fit: BoxFit.contain)
                        : Image.network(
                            _currentMediaURL!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPreviewFallback();
                            },
                          ),
                  )
                : _buildPreviewFallback(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: _editPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewFallback() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _editSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _editBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            size: 72,
            color: _editPrimary,
          ),
          const SizedBox(height: 18),
          Text(
            _attachmentName.isEmpty ? 'Attachment ready' : _attachmentName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _editInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This attachment will be kept with your updated post.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _editMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    final updatedText = _contentController.text.trim();
    final textChanged = updatedText != widget.initialContent;
    final mediaChanged =
        (_currentMediaURL != widget.initialMediaURL) || (_selectedNewFile != null);

    if (updatedText.isEmpty && _currentMediaURL == null && _selectedNewFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isPost
              ? 'Post cannot be completely empty.'
              : 'Comment cannot be completely empty.'),
        ),
      );
      return;
    }

    if (!textChanged && !mediaChanged) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalMediaUrl = _currentMediaURL;

      if (_selectedNewFile != null) {
        finalMediaUrl = await _communityService.uploadPostMedia(
          _selectedNewFile!,
          widget.currentUserID,
        );
        if (finalMediaUrl == null) {
          throw Exception('Failed to upload new attachment.');
        }
      }

      if (widget.isPost) {
        await _communityService.editPost(
          widget.targetID,
          updatedText,
          finalMediaUrl,
        );
      } else {
        await _communityService.editComment(widget.targetID, updatedText);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAttachmentCard(BuildContext context) {
    if (!_hasMedia) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _editBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _editSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _isImageAttachment
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_rounded,
              color: _editPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _attachmentName.isEmpty ? 'Existing attachment' : _attachmentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _editInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedNewFile != null
                      ? 'New attachment selected'
                      : 'Current attachment will be preserved',
                  style: const TextStyle(
                    color: _editMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _previewMedia(context),
            tooltip: 'Preview',
            icon: const Icon(
              Icons.visibility_outlined,
              color: _editPrimary,
            ),
          ),
          IconButton(
            onPressed: _removeMedia,
            tooltip: 'Remove attachment',
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
            border: Border.all(color: _editBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _editPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _editPrimary,
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
  Widget build(BuildContext context) {
    final title = widget.isPost ? 'Edit Post' : 'Edit Comment';
    final statusLabel = widget.isPost ? 'Editing community post' : 'Editing comment';
    final saveLabel = widget.isPost ? 'Save Changes' : 'Save Comment';

    return Scaffold(
      backgroundColor: _editBackground,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: _editInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
                          border: Border.all(color: _editBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: _editSoft,
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: _editPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        statusLabel,
                                        style: const TextStyle(
                                          color: _editInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                              decoration: BoxDecoration(
                                color: _editSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _editBorder),
                              ),
                              child: TextField(
                                controller: _contentController,
                                maxLines: null,
                                minLines: widget.isPost ? 8 : 5,
                                autofocus: true,
                                keyboardType: TextInputType.multiline,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  color: _editInk,
                                  fontSize: 17,
                                  height: 1.55,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.isPost
                                      ? 'Refine the post, add context, or tighten the message.'
                                      : 'Update the comment so it reads clearly.',
                                  hintStyle: const TextStyle(
                                    color: _editMuted,
                                    fontSize: 17,
                                    height: 1.55,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasMedia) ...[
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
                      color: _editBorder.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (widget.isPost)
                            _buildActionChip(
                              icon: Icons.swap_horiz_rounded,
                              label: 'Change Media',
                              onTap: _pickDocument,
                            ),
                          if (widget.isPost) const Spacer(),
                          Text(
                            _hasDraftContent || _hasMedia
                                ? 'Changes ready to save'
                                : 'Add content before saving',
                            style: const TextStyle(
                              color: _editMuted,
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
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _editPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _editPrimary.withValues(alpha: 0.55),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      saveLabel,
                                      style: const TextStyle(
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
