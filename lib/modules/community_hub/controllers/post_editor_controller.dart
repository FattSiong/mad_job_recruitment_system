import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_topic.dart';
import 'post_list_controller.dart';

/// Create a new post, or edit an existing one (topic, text and one PDF/image).
/// A new post can be saved as a draft (only its author sees it) and published
/// later; a published post can't go back to being a draft.
class PostEditorController extends ChangeNotifier {
  final String currentUserID;

  /// null = new post.
  final FeedPostModel? original;

  PostEditorController({required this.currentUserID, this.original}) {
    _content = original?.content ?? '';
    _existingMediaURL = original?.mediaURL;
    _topic = original?.topic ?? PostTopic.general;
  }

  final _supabase = Supabase.instance.client;

  static const int maxLength = 2000;
  static const int maxAttachmentMB = 10;
  static const List<String> attachmentExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const String bucket = 'post_media';

  String _content = '';
  PostTopic _topic = PostTopic.general;
  String? _existingMediaURL;
  File? _newFile;
  bool _isSaving = false;

  bool get isEditing => original != null;

  /// Editing one of the user's drafts.
  bool get isEditingDraft => original?.isDraft ?? false;

  /// "Save draft" is offered for new posts and drafts.
  bool get canBeDraft => PostListController.draftsSupported && (!isEditing || isEditingDraft);
  bool get isSaving => _isSaving;
  String get content => _content;
  PostTopic get topic => _topic;
  File? get newFile => _newFile;
  String? get existingMediaURL => _existingMediaURL;

  bool get hasAttachment => _newFile != null || (_existingMediaURL?.isNotEmpty ?? false);

  String get attachmentName {
    if (_newFile != null) return _newFile!.path.split(Platform.pathSeparator).last;
    final url = _existingMediaURL;
    if (url == null || url.isEmpty) return '';
    final name = Uri.decodeComponent((Uri.tryParse(url)?.path ?? url).split('/').last);
    return name.replaceFirst(RegExp(r'^\d{10,}_'), '');
  }

  bool get attachmentIsImage {
    final name = attachmentName.toLowerCase();
    return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
  }

  bool get _changed =>
      !isEditing ||
      _content.trim() != original!.content.trim() ||
      _topic != original!.topic ||
      _newFile != null ||
      _existingMediaURL != original!.mediaURL;

  bool get _valid =>
      _content.trim().length <= maxLength && (_content.trim().isNotEmpty || hasAttachment);

  /// Post / Save button. A draft can be published even without changes.
  bool get canSave => !_isSaving && _valid && (_changed || isEditingDraft);

  /// Save draft button.
  bool get canSaveDraft => !_isSaving && canBeDraft && _valid && _changed;

  /// Something typed that leaving the screen would throw away.
  bool get hasUnsavedChanges => _valid && _changed;

  /// The post text as the user types it.
  void setContent(String value) {
    _content = value;
    notifyListeners();
  }

  /// The chosen topic.
  void setTopic(PostTopic topic) {
    if (topic == _topic) return;
    _topic = topic;
    notifyListeners();
  }

  /// Opens the file picker. [onError] gets a message if the file is too big.
  Future<void> pickAttachment({void Function(String message)? onError}) async {
    final file = await FilePickerHelper.pickFile(
      allowedExtensions: attachmentExtensions,
      maxSizeMB: maxAttachmentMB,
      onTooLarge: onError,
    );
    if (file == null) return;
    _newFile = file;
    notifyListeners();
  }

  /// Removes the attachment (the old file is deleted only when the post is saved).
  void removeAttachment() {
    _newFile = null;
    _existingMediaURL = null;
    notifyListeners();
  }

  /// Publishes (or, with [asDraft], saves a draft).
  /// Returns an error message, or null when saved.
  Future<String?> save({bool asDraft = false}) async {
    if (asDraft && !canBeDraft) return null;
    if (asDraft ? !canSaveDraft : !canSave) {
      if (_content.trim().isEmpty && !hasAttachment) return 'Please add some text or an attachment.';
      if (_content.trim().length > maxLength) return 'Posts can be up to $maxLength characters.';
      return null;
    }

    _isSaving = true;
    notifyListeners();
    String? uploadedURL;
    try {
      var mediaURL = _existingMediaURL;
      if (_newFile != null) mediaURL = uploadedURL = await _upload(_newFile!);

      if (isEditing) {
        final changed = await _supabase
            .from(TableConstants.communityPost)
            .update({
              'content': _content.trim(),
              'mediaURL': mediaURL,
              'category': _topic.value,
              if (isEditingDraft) 'isDraft': asDraft, // false = publish it now
            })
            .eq('postID', original!.postID)
            .eq('authorID', currentUserID)
            .select('postID');
        if (changed.isEmpty) {
          // Deleted or removed meanwhile: keep its old file, drop the new upload
          await StorageUrlHelper.removeOwnFile(uploadedURL, bucket: bucket, userId: currentUserID);
          return 'This post can no longer be edited. It may have been deleted or removed.';
        }
      } else {
        await _supabase.from(TableConstants.communityPost).insert({
          'authorID': currentUserID,
          'content': _content.trim(),
          'mediaURL': mediaURL,
          'category': _topic.value,
          'status': 'active',
          if (asDraft) 'isDraft': true, // left out otherwise (works before the drafts migration)
        });
      }
      // The attachment was replaced or removed: its old file is no longer used
      final oldURL = original?.mediaURL;
      if (isEditing && oldURL != null && oldURL.isNotEmpty && oldURL != mediaURL) {
        await StorageUrlHelper.removeOwnFile(oldURL, bucket: bucket, userId: currentUserID);
      }
      return null;
    } catch (e) {
      debugPrint('Save post failed: $e');
      // Not saved: don't leave the file that was just uploaded behind
      await StorageUrlHelper.removeOwnFile(uploadedURL, bucket: bucket, userId: currentUserID);
      if (asDraft && PostListController.isMissingDraftColumns(e)) {
        PostListController.draftsSupported = false; // hides Save draft
        return 'Drafts aren\'t available yet (database update needed). You can still post.';
      }
      if (asDraft) return 'Unable to save your draft. Please try again.';
      return isEditing && !isEditingDraft
          ? 'Unable to save your changes. Please try again.'
          : 'Unable to publish your post. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Uploads [file] to the user's folder in the post media bucket and returns its link.
  Future<String> _upload(File file) async {
    final name = file.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$currentUserID/${DateTime.now().millisecondsSinceEpoch}_$name';
    await _supabase.storage.from(bucket).upload(path, file);
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }
}
