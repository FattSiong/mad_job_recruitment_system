import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_topic.dart';

/// Create a new post, or edit an existing one (topic, text and one PDF/image).
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
  static const String _bucket = 'post_media';

  String _content = '';
  PostTopic _topic = PostTopic.general;
  String? _existingMediaURL;
  File? _newFile;
  bool _isSaving = false;

  bool get isEditing => original != null;
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

  bool get canSave =>
      !_isSaving &&
      _content.trim().length <= maxLength &&
      (_content.trim().isNotEmpty || hasAttachment) &&
      _changed;

  void setContent(String value) {
    _content = value;
    notifyListeners();
  }

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

  void removeAttachment() {
    _newFile = null;
    _existingMediaURL = null;
    notifyListeners();
  }

  /// Returns an error message, or null when saved.
  Future<String?> save() async {
    if (!canSave) {
      if (_content.trim().isEmpty && !hasAttachment) return 'Please add some text or an attachment.';
      if (_content.trim().length > maxLength) return 'Posts can be up to $maxLength characters.';
      return null;
    }

    _isSaving = true;
    notifyListeners();
    try {
      var mediaURL = _existingMediaURL;
      if (_newFile != null) mediaURL = await _upload(_newFile!);

      if (isEditing) {
        await _supabase
            .from(TableConstants.communityPost)
            .update({
              'content': _content.trim(),
              'mediaURL': mediaURL,
              'category': _topic.value,
            })
            .eq('postID', original!.postID)
            .eq('authorID', currentUserID);
      } else {
        await _supabase.from(TableConstants.communityPost).insert({
          'authorID': currentUserID,
          'content': _content.trim(),
          'mediaURL': mediaURL,
          'category': _topic.value,
          'status': 'active',
        });
      }
      return null;
    } catch (e) {
      debugPrint('Save post failed: $e');
      return isEditing
          ? 'Unable to save your changes. Please try again.'
          : 'Unable to publish your post. Please try again.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String> _upload(File file) async {
    final name = file.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$currentUserID/${DateTime.now().millisecondsSinceEpoch}_$name';
    await _supabase.storage.from(_bucket).upload(path, file);
    return _supabase.storage.from(_bucket).getPublicUrl(path);
  }
}
