/// A job the seeker bookmarked ("BookmarkedJob", one row per seeker and job).
class BookmarkedJobModel {
  final String seekerID;
  final String jobID; // the database fills in "savedAt"

  BookmarkedJobModel({
    required this.seekerID,
    required this.jobID,
  });

  factory BookmarkedJobModel.fromJson(Map<String, dynamic> json) {
    return BookmarkedJobModel(
      seekerID: json['seekerID'] as String,
      jobID: json['jobID'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seekerID': seekerID,
      'jobID': jobID,
    };
  }
}