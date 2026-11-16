import 'chat_room_model.dart';

/// A comment or reply on a community post ("PostComment").
///
/// Replies are kept one level deep: a reply to a reply is stored under the
/// same top-level comment, starting with "@name".
class PostCommentModel {
  final String commentID;
  final String postID;
  final String? parentCommentID;
  final String userID;
  final String content;
  final DateTime createdAt;

  /// When the text was last changed (null = never edited). Set by the database.
  final DateTime? updateAt;
  final ChatParticipant author;

  const PostCommentModel({
    required this.commentID,
    required this.postID,
    this.parentCommentID,
    required this.userID,
    required this.content,
    required this.createdAt,
    this.updateAt,
    required this.author,
  });

  /// The author changed the text after posting (shows "Edited").
  bool get isEdited => updateAt != null;

  bool get isReply => parentCommentID != null && parentCommentID!.isNotEmpty;

  /// The top-level comment a reply to this comment should be stored under.
  String get threadID => isReply ? parentCommentID! : commentID;

  /// True if [id] wrote this comment.
  bool isOwnedBy(String id) => userID == id;

  /// "@Aisyah" at the start of a reply, or null.
  String? get mention => RegExp(r'^@\S+').firstMatch(content.trimLeft())?.group(0);

  /// The text after the mention.
  String get body {
    final m = mention;
    if (m == null) return content;
    return content.trimLeft().substring(m.length).trimLeft();
  }

  /// A copy with new text and/or edit time. [asTopLevel] drops the parent
  /// (a reply whose top-level comment is gone).
  PostCommentModel copyWith({String? content, DateTime? updateAt, bool asTopLevel = false}) =>
      PostCommentModel(
        commentID: commentID,
        postID: postID,
        parentCommentID: asTopLevel ? null : parentCommentID,
        userID: userID,
        content: content ?? this.content,
        createdAt: createdAt,
        updateAt: updateAt ?? this.updateAt,
        author: author,
      );

  factory PostCommentModel.fromJson(Map<String, dynamic> json, {required ChatParticipant author}) {
    final parent = json['parentCommentID']?.toString();
    return PostCommentModel(
      commentID: json['commentID'].toString(),
      postID: json['postID']?.toString() ?? '',
      parentCommentID: (parent == null || parent.isEmpty) ? null : parent,
      userID: json['userID']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      updateAt: DateTime.tryParse(json['updateAt']?.toString() ?? '')?.toLocal(),
      author: author,
    );
  }
}
