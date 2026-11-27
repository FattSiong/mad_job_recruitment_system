/// A job the seeker bookmarked ("BookmarkedJob", one row per seeker and job).
class BookmarkedJobModel {
  final String seekerID;
  final String jobID;
  final DateTime? savedAt;

  BookmarkedJobModel({
    required this.seekerID,
    required this.jobID,
    this.savedAt,
  });

  factory BookmarkedJobModel.fromJson(Map<String, dynamic> json) {
    return BookmarkedJobModel(
      seekerID: json['seekerID'] as String,
      jobID: json['jobID'] as String,
      savedAt: json['savedAt'] != null ? DateTime.parse(json['savedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seekerID': seekerID,
      'jobID': jobID,
      if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
    };
  }
}