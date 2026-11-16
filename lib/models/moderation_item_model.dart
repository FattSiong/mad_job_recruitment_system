import 'chat_room_model.dart';
import 'feed_post_model.dart';
import 'post_topic.dart';

/// A community post or a comment, as the admin reviews it.
enum ModerationKind { post, comment }

/// One user's report on a post or comment ("ReportedPost" / "ReportedComment").
class ContentReport {
  final String reportID;
  final String reporterID;
  final String category;
  final String? details;
  final DateTime reportedAt;

  /// Filled in from UserDirectory.
  final ChatParticipant? reporter;

  const ContentReport({
    required this.reportID,
    required this.reporterID,
    required this.category,
    this.details,
    required this.reportedAt,
    this.reporter,
  });

  factory ContentReport.fromJson(
    Map<String, dynamic> json, {
    required String idColumn,
    ChatParticipant? reporter,
  }) {
    final details = json['additionalDetails']?.toString().trim();
    return ContentReport(
      reportID: json[idColumn]?.toString() ?? '',
      reporterID: json['reporterID']?.toString() ?? '',
      category: json['reportCategory']?.toString().trim().isNotEmpty == true
          ? json['reportCategory'].toString().trim()
          : 'Other',
      details: (details == null || details.isEmpty) ? null : details,
      reportedAt: DateTime.tryParse(json['reportedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      reporter: reporter,
    );
  }
}

/// A post or comment in Admin > Community, with its open reports.
class ModerationItem {
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

  /// 'active', or 'author_deleted' (the author deleted it while it was reported).
  final String status;
  final DateTime createdAt;

  // Comments only
  final String? parentCommentID;
  final String? postContent;

  /// Open ("pending") reports, newest first.
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
  bool get isReported => reports.isNotEmpty;
  bool get deletedByAuthor => status == 'author_deleted';
  bool get hasMedia => mediaURL != null && mediaURL!.trim().isNotEmpty;

  /// How many different people reported it.
  int get reporterCount => reports.map((r) => r.reporterID).toSet().length;

  /// Report reasons with how often each was given, most common first.
  List<MapEntry<String, int>> get categoryCounts {
    final counts = <String, int>{};
    for (final r in reports) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  DateTime? get latestReportAt => reports.isEmpty ? null : reports.first.reportedAt;

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
      topic: PostTopic.fromValue(json['category']?.toString()),
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
      authorID: json['userID']?.toString() ?? '',
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
