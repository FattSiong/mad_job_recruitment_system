import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_topic.dart';
import '../controllers/post_editor_controller.dart';
import '../widgets/community_chips.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/button_spinner.dart';

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

  /// Red (error) or green snackbar.
  void _snack(String message, {bool error = true}) {
    if (error) {
      SnackBarHelper.showError(context, message, duration: const Duration(seconds: 3));
    } else {
      SnackBarHelper.showSuccess(context, message, duration: const Duration(seconds: 3));
    }
  }

  /// Publishes the post, or saves it as a draft, then closes the screen.
  Future<void> _save({bool asDraft = false}) async {
    FocusScope.of(context).unfocus();
    final error = await _controller.save(asDraft: asDraft);
    if (!mounted) return;
    if (error != null) {
      _snack(error);
      return;
    }
    final String done;
    if (asDraft) {
      done = 'Draft saved. Find it under My Posts.';
    } else if (_controller.isEditing && !_controller.isEditingDraft) {
      done = 'Post updated.';
    } else {
      done = 'Post published.';
    }
    _snack(done, error: false);
    Navigator.pop(context, true);
  }

  /// Ask before throwing away unsaved text.
  Future<bool> _confirmLeave() async {
    if (!_controller.hasUnsavedChanges) return true;
    final leave = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: _controller.isEditing && !_controller.isEditingDraft
          ? 'Your changes to this post will be lost.'
          : 'Your post hasn\'t been published yet. Tap Save draft to keep it for later.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
    );
    return leave;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => PopScope(
        canPop: !_controller.hasUnsavedChanges && !_controller.isSaving,
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
              _controller.isEditingDraft
                  ? 'Edit Draft'
                  : (_controller.isEditing ? 'Edit Post' : 'Create Post'),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            actions: [
              if (_controller.canBeDraft)
                TextButton(
                  onPressed: _controller.canSaveDraft ? () => _save(asDraft: true) : null,
                  child: const Text(
                    'Save draft',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: _controller.canSave ? () => _save() : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.borderActive,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _controller.isSaving
                      ? const ButtonSpinner()
                      : Text(_controller.isEditing && !_controller.isEditingDraft ? 'Save' : 'Post'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _buildTopicPicker(),
                const SizedBox(height: 16),
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

  /// Topic of the post; readers can filter the feed by it.
  Widget _buildTopicPicker() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Topic',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Helps others find your post.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in PostTopic.values)
                OptionChip(
                  label: topic.label,
                  icon: topic.icon,
                  selected: topic == _controller.topic,
                  onTap: () {
                    if (!_controller.isSaving) _controller.setTopic(topic);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Add a PDF or image" button, or the chosen attachment with a remove button.
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
