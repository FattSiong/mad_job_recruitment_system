class BookmarkedJobModel {
  final String? bookmarkedID;
  final String seekerID;
  final String jobID;
  final DateTime? savedAt;

  BookmarkedJobModel({
    this.bookmarkedID,
    required this.seekerID,
    required this.jobID,
    this.savedAt,
  });

  factory BookmarkedJobModel.fromJson(Map<String, dynamic> json) {
    return BookmarkedJobModel(
      bookmarkedID: json['bookmarkedID'] as String?,
      seekerID: json['seekerID'] as String,
      jobID: json['jobID'] as String,
      savedAt: json['savedAt'] != null ? DateTime.parse(json['savedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (bookmarkedID != null) 'bookmarkedID': bookmarkedID,
      'seekerID': seekerID,
      'jobID': jobID,
      if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
    };
  }
}