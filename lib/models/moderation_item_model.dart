import 'chat_room_model.dart';
import 'content_report_model.dart';
import 'feed_post_model.dart';
import 'post_topic.dart';

// ContentReport and ModerationSort moved to content_report_model.dart;
// exported here so existing imports keep working.
export 'content_report_model.dart';

/// A community post or a comment, as the admin reviews it.
enum ModerationKind { post, comment }

/// A post or comment in Admin > Community, with its open reports.
class ModerationItem with ReportSummary {
  final ModerationKind kind;

  /// postID or commentID.
  final String id;

  /// The post itself, or the post a comment belongs to.
  final String postID;
  final String authorID;
  final ChatParticipant author;
  final String content;
  final String? mediaURL; // posts only
  final PostTopic topic; // posts only

  /// 'active', 'author_deleted' (the author deleted it while it was
  /// reported) or 'deleted' (already removed by an admin).
  final String status;
  final DateTime createdAt;

  // Comments only
  final String? parentCommentID;
  final String? postContent;

  /// Open ("pending") reports, newest first.
  @override
  final List<ContentReport> reports;

  const ModerationItem({
    required this.kind,
    required this.id,
    required this.postID,
    required this.authorID,
    required this.author,
    required this.content,
    this.mediaURL,
    this.topic = PostTopic.general,
    required this.status,
    required this.createdAt,
    this.parentCommentID,
    this.postContent,
    this.reports = const [],
  });

  bool get isPost => kind == ModerationKind.post;
  bool get isReply => parentCommentID != null && parentCommentID!.isNotEmpty;
  bool get deletedByAuthor => status == 'author_deleted';

  /// Already removed by an admin; only its leftover reports need closing.
  bool get isRemoved => status == 'deleted';
  bool get hasMedia => mediaURL != null && mediaURL!.trim().isNotEmpty;

  /// True if [query] (lower case) is in the text, the author's name, the
  /// post a comment is on, or a report's reason, details or reporter.
  bool matches(String query) {
    bool has(String? text) => text != null && text.toLowerCase().contains(query);
    return has(content) || has(author.displayName) || has(postContent) || reportsMatch(query);
  }

  /// The Reported list: items matching [search], in the [sort] order.
  static List<ModerationItem> searchAndSortReported(
    Iterable<ModerationItem> items,
    String search,
    ModerationSort sort,
  ) {
    final q = search.trim().toLowerCase();
    final list = q.isEmpty ? items.toList() : items.where((i) => i.matches(q)).toList();
    return sortByReports(list, sort);
  }

  /// Same item without its reports (after they were dismissed).
  ModerationItem withoutReports() => ModerationItem(
        kind: kind,
        id: id,
        postID: postID,
        authorID: authorID,
        author: author,
        content: content,
        mediaURL: mediaURL,
        topic: topic,
        status: status,
        createdAt: createdAt,
        parentCommentID: parentCommentID,
        postContent: postContent,
      );

  /// For showing the attachment with the Community Hub's PostMediaView.
  FeedPostModel toFeedPost() => FeedPostModel(
        postID: postID,
        authorID: authorID,
        content: content,
        mediaURL: mediaURL,
        status: status,
        topic: topic,
        createdAt: createdAt,
        author: author,
        likeCount: 0,
        commentCount: 0,
        savedCount: 0,
        isLiked: false,
        isSaved: false,
      );

  /// A post row ("CommunityPost").
  factory ModerationItem.fromPostJson(
    Map<String, dynamic> json, {
    required ChatParticipant author,
    List<ContentReport> reports = const [],
  }) {
    final id = json['postID'].toString();
    return ModerationItem(
      kind: ModerationKind.post,
      id: id,
      postID: id,
      authorID: json['authorID']?.toString() ?? '',
      author: author,
      content: json['content']?.toString() ?? '',
      mediaURL: json['mediaURL'] as String?,
      topic: PostTopic.fromValue(json['topic']?.toString()),
      status: json['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      reports: reports,
    );
  }

  /// A comment row ("PostComment", with its post as "CommunityPost").
  factory ModerationItem.fromCommentJson(
    Map<String, dynamic> json, {
    required ChatParticipant author,
    List<ContentReport> reports = const [],
  }) {
    final post = json['CommunityPost'];
    final parent = json['parentCommentID']?.toString();
    return ModerationItem(
      kind: ModerationKind.comment,
      id: json['commentID'].toString(),
      postID: json['postID']?.toString() ?? '',
      authorID: json['authorID']?.toString() ?? '',
      author: author,
      content: json['content']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      parentCommentID: (parent == null || parent.isEmpty) ? null : parent,
      postContent: post is Map ? post['content']?.toString() : null,
      reports: reports,
    );
  }
}
