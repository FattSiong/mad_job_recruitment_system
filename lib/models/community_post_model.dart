class CommunityPostModel {
  final String postID;
  final String authorID;
  final String content;
  final String? mediaURL;
  final String status; // 'active', or 'deleted' by an admin
  final DateTime createdAt;

  // Joined User Data
  final String username;
  final String role;
  final String? profilePictureURL;

  // Interaction Data
  final int likeCount;
  final int commentCount;
  final int savedCount;

  // Lists to check if the current user has interacted
  final List<dynamic> likesList;
  final List<dynamic> savesList;

  CommunityPostModel({
    required this.postID,
    required this.authorID,
    required this.content,
    this.mediaURL,
    this.status = 'active',
    required this.createdAt,
    required this.username,
    required this.role,
    this.profilePictureURL,
    required this.likeCount,
    required this.commentCount,
    required this.savedCount,
    required this.likesList,
    required this.savesList,
  });

  // Factory constructor to easily convert Supabase JSON into this object
  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final user = json['User'] ?? {};
    final likes = json['PostLike'] as List<dynamic>? ?? [];
    final comments = json['PostComment'] as List<dynamic>? ?? [];
    final saves = json['PostSaved'] as List<dynamic>? ?? [];

    return CommunityPostModel(
      postID: json['postID'] ?? '',
      authorID: json['authorID'] ?? user['userID'] ?? '',
      content: json['content'] ?? '',
      mediaURL: json['mediaURL'],
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']).toLocal() : DateTime.now(),
      username: user['username'] ?? 'Unknown User',
      role: user['role'] ?? 'Member',
      profilePictureURL: user['profilePictureURL'] as String?,
      likeCount: likes.length,
      commentCount: comments.length,
      savedCount: saves.length,
      likesList: likes,
      savesList: saves,
    );
  }

  // Helper methods to keep UI clean
  bool isLikedBy(String userID) {
    return likesList.any((like) => like['userID'].toString() == userID);
  }

  bool isSavedBy(String userID) {
    return savesList.any((save) => save['userID'].toString() == userID);
  }
}
