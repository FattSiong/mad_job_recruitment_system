import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/feed_post_model.dart';
import '../controllers/post_editor_controller.dart';

/// Create a post, or edit one (pass [post]). Pops with true when saved.
class PostEditorScreen extends StatefulWidget {
  final String currentUserID;
  final FeedPostModel? post;

  const PostEditorScreen({super.key, required this.currentUserID, this.post});

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen> {
  late final PostEditorController _controller =
      PostEditorController(currentUserID: widget.currentUserID, original: widget.post);
  late final TextEditingController _text = TextEditingController(text: widget.post?.content ?? '');

  @override
  void initState() {
    super.initState();
    _text.addListener(() => _controller.setContent(_text.text));
  }

  @override
  void dispose() {
    _text.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = true}) {
    SnackBarHelper.showStyled(
      context,
      message: message,
      icon: error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
      accentColor: error ? AppColors.errorRed : AppColors.successGreen,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final error = await _controller.save();
    if (!mounted) return;
    if (error != null) {
      _snack(error);
      return;
    }
    _snack(_controller.isEditing ? 'Post updated.' : 'Post published.', error: false);
    Navigator.pop(context, true);
  }

  /// Ask before throwing away unsaved text.
  Future<bool> _confirmLeave() async {
    if (!_controller.canSave) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Discard changes?'),
        content: Text(_controller.isEditing
            ? 'Your changes to this post will be lost.'
            : 'Your post hasn\'t been published yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => PopScope(
        canPop: !_controller.canSave && !_controller.isSaving,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || _controller.isSaving) return;
          final navigator = Navigator.of(context);
          if (await _confirmLeave()) navigator.pop();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.primary),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              _controller.isEditing ? 'Edit Post' : 'Create Post',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: _controller.canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.borderActive,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _controller.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_controller.isEditing ? 'Save' : 'Post'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _text,
                    enabled: !_controller.isSaving,
                    autofocus: !_controller.isEditing,
                    minLines: 6,
                    maxLines: 14,
                    maxLength: PostEditorController.maxLength,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textDark),
                    decoration: const InputDecoration(
                      hintText: 'Share a question, tip, experience or job-hunting update…',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAttachment(),
                const SizedBox(height: 16),
                const Text(
                  'Be kind and professional. Posts that break the community rules can be removed by an admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachment() {
    if (!_controller.hasAttachment) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _controller.isSaving ? null : () => _controller.pickAttachment(onError: _snack),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Row(
              children: [
                Icon(Icons.attach_file_rounded, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add a photo or PDF',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      SizedBox(height: 2),
                      Text('JPG, PNG or PDF, up to ${PostEditorController.maxAttachmentMB} MB',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final file = _controller.newFile;
    final url = _controller.existingMediaURL;
    final isImage = _controller.attachmentIsImage;

    Widget preview;
    if (isImage && file != null) {
      preview = Image.file(file, height: 200, width: double.infinity, fit: BoxFit.cover);
    } else if (isImage && url != null) {
      preview = Image.network(url, height: 200, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } else {
      preview = const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          preview,
          ListTile(
            leading: Icon(
              isImage ? Icons.image_outlined : Icons.picture_as_pdf_rounded,
              color: isImage ? AppColors.primary : AppColors.danger,
            ),
            title: Text(
              _controller.attachmentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            subtitle: Text(
              file != null ? 'New attachment' : 'Current attachment',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Preview',
                  onPressed: () => file != null
                      ? FilePreviewHelper.previewLocalFile(context, file, title: 'Attachment')
                      : FilePreviewHelper.previewNetworkFile(context, url!, title: 'Attachment'),
                  icon: const Icon(Icons.visibility_outlined, color: AppColors.primary),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: _controller.isSaving ? null : _controller.removeAttachment,
                  icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
