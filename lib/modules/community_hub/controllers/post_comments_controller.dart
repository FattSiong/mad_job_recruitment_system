import 'package:flutter/foundation.dart';
// Lengths are counted like the text box counts them (an emoji is one character)
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/post_comment_model.dart';
import '../../../services/user_directory.dart';
import '../../../core/utils/safe_notifier.dart';

/// Comments and replies of one post (the comments sheet).
class PostCommentsController extends ChangeNotifier with SafeNotifier {
  final String postID;
  final String currentUserID;

  PostCommentsController({required this.postID, required this.currentUserID});

  final _supabase = Supabase.instance.client;

  static const int maxLength = 1000;

  List<PostCommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  PostCommentModel? _replyingTo;
  final Set<String> _expanded = {};

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  PostCommentModel? get replyingTo => _replyingTo;
  int get count => _comments.length;
  bool get isEmpty => _comments.isEmpty;

  /// Top-level comments, oldest first.
  List<PostCommentModel> get threads => _comments.where((c) => !c.isReply).toList();

  /// Replies under a top-level comment, oldest first.
  List<PostCommentModel> repliesOf(String commentID) =>
      _comments.where((c) => c.parentCommentID == commentID).toList();

  /// True if the replies under [commentID] are shown.
  bool isExpanded(String commentID) => _expanded.contains(commentID);

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Loads the post's comments and replies.
  Future<void> load() async {
    _isLoading = _comments.isEmpty;
    _error = null;
    notifySafely();
    try {
      final rows = List<Map<String, dynamic>>.from(await _supabase
          .from(TableConstants.postComment)
          .select('commentID, postID, parentCommentID, userID, content, createdAt, updateAt, status')
          .eq('postID', postID)
          .order('createdAt', ascending: true));

      // Comments removed by an admin, or deleted by their author while
      // reported ('author_deleted', kept for the admin), are hidden.
      final visible = rows.where((r) => (r['status']?.toString() ?? 'active') == 'active').toList();
      final authors = await UserDirectory.fetch(visible.map((r) => r['userID']?.toString() ?? ''));

      final all = visible.map((r) {
        final id = r['userID']?.toString() ?? '';
        return PostCommentModel.fromJson(
          r,
          author: authors[id] ?? ChatParticipant(userID: id, displayName: 'Unknown user', role: 'member'),
        );
      }).toList();

      // A reply whose top-level comment is gone is shown as a normal comment.
      final ids = all.map((c) => c.commentID).toSet();
      _comments = all
          .map((c) => c.isReply && !ids.contains(c.parentCommentID) ? c.copyWith(asTopLevel: true) : c)
          .toList();
    } catch (e) {
      debugPrint('PostCommentsController load failed: $e');
      _error = 'Unable to load comments. Please try again.';
    } finally {
      _isLoading = false;
      notifySafely();
    }
  }

  // ---------------------------------------------------------------------
  // Replying
  // ---------------------------------------------------------------------

  /// The next comment sent is a reply to [comment].
  void startReply(PostCommentModel comment) {
    _replyingTo = comment;
    notifySafely();
  }

  /// Back to writing a normal comment.
  void cancelReply() {
    if (_replyingTo == null) return;
    _replyingTo = null;
    notifySafely();
  }

  /// Shows or hides the replies under [commentID].
  void toggleThread(String commentID) {
    if (!_expanded.remove(commentID)) _expanded.add(commentID);
    notifySafely();
  }

  // ---------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------

  /// Sends a comment, or a reply when [replyingTo] is set.
  /// Returns an error message, or null when it worked.
  Future<String?> send(String text) async {
    var content = text.trim();
    if (content.isEmpty || _isSending) return null;
    if (content.characters.length > maxLength) return 'Comments can be up to $maxLength characters.';

    final target = _replyingTo;
    String? parentID;
    if (target != null) {
      parentID = target.threadID;
      final name = target.author.displayName.replaceAll(' ', '');
      if (!target.isOwnedBy(currentUserID) && !content.startsWith('@$name')) {
        content = '@$name $content';
      }
    }

    _isSending = true;
    notifySafely();
    try {
      await _supabase.from(TableConstants.postComment).insert({
        'postID': postID,
        'userID': currentUserID,
        'content': content,
        'parentCommentID': parentID,
        'status': 'active',
      });
      _replyingTo = null;
      if (parentID != null) _expanded.add(parentID);
      await load();
      return null;
    } catch (e) {
      debugPrint('Send comment failed: $e');
      return 'Unable to send your comment. Please try again.';
    } finally {
      _isSending = false;
      notifySafely();
    }
  }

  /// Changes the text of one of the user's comments.
  /// Returns an error message, or null when it worked.
  Future<String?> edit(PostCommentModel comment, String text) async {
    final content = text.trim();
    if (!comment.isOwnedBy(currentUserID)) return 'You can only edit your own comments.';
    if (content.isEmpty) return 'Comment cannot be empty.';
    if (content.characters.length > maxLength) return 'Comments can be up to $maxLength characters.';
    if (content == comment.content) return null; // nothing changed: not "Edited"
    try {
      await _supabase
          .from(TableConstants.postComment)
          .update({'content': content})
          .eq('commentID', comment.commentID)
          .eq('userID', currentUserID);
      final i = _comments.indexWhere((c) => c.commentID == comment.commentID);
      // the database sets "updateAt" too; show "Edited" straight away
      if (i != -1) _comments[i] = _comments[i].copyWith(content: content, updateAt: DateTime.now());
      notifySafely();
      return null;
    } catch (e) {
      debugPrint('Edit comment failed: $e');
      return 'Unable to save your comment. Please try again.';
    }
  }

  /// Deletes the comment and all replies under it, using the database
  /// function `delete_my_comment` (checks the caller owns the comment).
  /// Returns an error message, or null when it worked.
  Future<String?> delete(PostCommentModel comment) async {
    if (!comment.isOwnedBy(currentUserID)) return 'You can only delete your own comments.';
    try {
      await _supabase.rpc('delete_my_comment', params: {'p_comment_id': comment.commentID});
      if (_replyingTo?.commentID == comment.commentID) _replyingTo = null;
      _expanded.remove(comment.commentID);
      await load();
      return null;
    } on PostgrestException catch (e) {
      debugPrint('Delete comment failed: ${e.code} ${e.message}');
      if (e.message.contains('not_owner')) return 'You can only delete your own comments.';
      return 'Unable to delete this comment. Please try again.';
    } catch (e) {
      debugPrint('Delete comment failed: $e');
      return 'Unable to delete this comment. Please try again.';
    }
  }
}
