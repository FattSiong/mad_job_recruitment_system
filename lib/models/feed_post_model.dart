import 'chat_room_model.dart';
import 'post_topic.dart';

/// A post in the Community Hub, as seen by the current user.
///
/// Comes from "CommunityPost" plus its PostLike / PostSaved / PostComment rows.
/// The author's name and photo come from UserDirectory (Employer / JobSeeker).
class FeedPostModel {
  final String postID;
  final String authorID;
  final String content;
  final String? mediaURL;
  final String status; // 'active' or 'deleted' (removed by admin)
  final PostTopic topic;
  final DateTime createdAt;

  /// When a published post's text, attachment or topic last changed
  /// (null = never edited). Set by the database.
  final DateTime? editedAt;

  /// Only the author sees a draft (in My Posts) until it is published.
  final bool isDraft;
  final ChatParticipant author;

  final int likeCount;
  final int commentCount;
  final int savedCount;
  final bool isLiked;
  final bool isSaved;

  const FeedPostModel({
    required this.postID,
    required this.authorID,
    required this.content,
    this.mediaURL,
    required this.status,
    this.topic = PostTopic.general,
    required this.createdAt,
    this.editedAt,
    this.isDraft = false,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.savedCount,
    required this.isLiked,
    required this.isSaved,
  });

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

  /// Removed by an admin: read-only, but the author can still delete it.
  bool get isRemoved => status.trim().toLowerCase() == 'deleted';

  bool get isEdited => editedAt != null && !isDraft;

  /// Can be liked, commented on and saved (published and not removed).
  bool get isInteractive => !isRemoved && !isDraft;

  bool get hasMedia => mediaURL != null && mediaURL!.trim().isNotEmpty;

  String get mediaExtension {
    if (!hasMedia) return '';
    final path = Uri.tryParse(mediaURL!)?.path ?? mediaURL!;
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  }

  bool get isImage => _imageExtensions.contains(mediaExtension);

  bool get isPdf => mediaExtension == 'pdf';

  /// "report.pdf" from ".../1730000000000_report.pdf"
  String get mediaFileName {
    if (!hasMedia) return '';
    final path = Uri.tryParse(mediaURL!)?.path ?? mediaURL!;
    final name = Uri.decodeComponent(path.split('/').last);
    return name.replaceFirst(RegExp(r'^\d{10,}_'), '');
  }

  /// True if [userID] wrote this post.
  bool isOwnedBy(String userID) => authorID == userID;

  FeedPostModel copyWith({
    String? content,
    String? mediaURL,
    bool clearMedia = false,
    int? likeCount,
    int? commentCount,
    int? savedCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return FeedPostModel(
      postID: postID,
      authorID: authorID,
      content: content ?? this.content,
      mediaURL: clearMedia ? null : (mediaURL ?? this.mediaURL),
      status: status,
      topic: topic,
      createdAt: createdAt,
      editedAt: editedAt,
      isDraft: isDraft,
      author: author,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      savedCount: savedCount ?? this.savedCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  factory FeedPostModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUserID,
    required ChatParticipant author,
  }) {
    List<Map<String, dynamic>> rows(String key) => ((json[key] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    final likes = rows('PostLike');
    final saves = rows('PostSaved');
    // Comments removed by an admin are not counted.
    final comments = rows('PostComment')
        .where((c) => (c['status']?.toString() ?? 'active') != 'deleted')
        .toList();

    bool byMe(Map<String, dynamic> row) => row['userID']?.toString() == currentUserID;

    return FeedPostModel(
      postID: json['postID'].toString(),
      authorID: json['authorID']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mediaURL: json['mediaURL'] as String?,
      status: json['status']?.toString() ?? 'active',
      topic: PostTopic.fromValue(json['category']?.toString()),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      editedAt: DateTime.tryParse(json['editedAt']?.toString() ?? '')?.toLocal(),
      isDraft: json['isDraft'] == true,
      author: author,
      likeCount: likes.length,
      commentCount: comments.length,
      savedCount: saves.length,
      isLiked: likes.any(byMe),
      isSaved: saves.any(byMe),
    );
  }
}
