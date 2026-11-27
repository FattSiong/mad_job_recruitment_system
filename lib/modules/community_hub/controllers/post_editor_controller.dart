import 'dart:io';

import 'package:flutter/foundation.dart';
// Lengths are counted like the text box counts them (an emoji is one character)
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_topic.dart';
import 'post_list_controller.dart';

/// Create a new post, or edit an existing one (topic, text and one PDF/image).
/// A new post can be saved as a draft (only its author sees it) and published
/// later; a published post can't go back to being a draft.
class PostEditorController extends ChangeNotifier with SafeNotifier {
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
      _content.trim().characters.length <= maxLength && (_content.trim().isNotEmpty || hasAttachment);

  /// Post / Save button. A draft can be published even without changes.
  bool get canSave => !_isSaving && _valid && (_changed || isEditingDraft);

  /// Save draft button.
  bool get canSaveDraft => !_isSaving && canBeDraft && _valid && _changed;

  /// Something typed that leaving the screen would throw away.
  bool get hasUnsavedChanges => _changed && (_content.trim().isNotEmpty || hasAttachment);

  /// The post text as the user types it.
  void setContent(String value) {
    _content = value;
    notifySafely();
  }

  /// The chosen topic.
  void setTopic(PostTopic topic) {
    if (topic == _topic) return;
    _topic = topic;
    notifySafely();
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
    notifySafely();
  }

  /// Removes the attachment (the old file is deleted only when the post is saved).
  void removeAttachment() {
    _newFile = null;
    _existingMediaURL = null;
    notifySafely();
  }

  /// Publishes (or, with [asDraft], saves a draft).
  /// Returns an error message, or null when saved.
  Future<String?> save({bool asDraft = false}) async {
    if (asDraft && !canBeDraft) return null;
    if (asDraft ? !canSaveDraft : !canSave) {
      if (_content.trim().isEmpty && !hasAttachment) return 'Please add some text or an attachment.';
      if (_content.trim().characters.length > maxLength) return 'Posts can be up to $maxLength characters.';
      return null;
    }

    _isSaving = true;
    notifySafely();
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
      await _removeReplacedFile(mediaURL);
      return null;
    } catch (e) {
      debugPrint('Save post failed: $e');
      if (uploadedURL != null) {
        // The save may have gone through with only its reply lost: a post
        // with the new file's link tells. If there's none, the file isn't
        // used and is deleted. If it can't be told, it's kept (a spare file
        // is harmless, a post whose attachment was deleted is not).
        final saved = await _savedWithMedia(uploadedURL);
        if (saved == true) {
          await _removeReplacedFile(uploadedURL);
          return null;
        }
        if (saved == false) {
          await StorageUrlHelper.removeOwnFile(uploadedURL, bucket: bucket, userId: currentUserID);
        }
      }
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
      notifySafely();
    }
  }

  /// The attachment was replaced or removed: its old file is no longer used.
  Future<void> _removeReplacedFile(String? mediaURL) async {
    final oldURL = original?.mediaURL;
    if (isEditing && oldURL != null && oldURL.isNotEmpty && oldURL != mediaURL) {
      await StorageUrlHelper.removeOwnFile(oldURL, bucket: bucket, userId: currentUserID);
    }
  }

  /// Whether one of the user's posts links to [url] now: true / false, or
  /// null when it can't be checked (e.g. still offline).
  Future<bool?> _savedWithMedia(String url) async {
    try {
      final rows = await _supabase
          .from(TableConstants.communityPost)
          .select('postID')
          .eq('authorID', currentUserID)
          .eq('mediaURL', url)
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('Could not check whether the post was saved: $e');
      return null;
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
