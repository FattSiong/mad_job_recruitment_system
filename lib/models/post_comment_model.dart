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
  final ChatParticipant author;

  const PostCommentModel({
    required this.commentID,
    required this.postID,
    this.parentCommentID,
    required this.userID,
    required this.content,
    required this.createdAt,
    required this.author,
  });

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

  PostCommentModel copyWith({String? content}) => PostCommentModel(
        commentID: commentID,
        postID: postID,
        parentCommentID: parentCommentID,
        userID: userID,
        content: content ?? this.content,
        createdAt: createdAt,
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
      author: author,
    );
  }
}
