class JobSeekerModel {
  final String seekerID;
  final String fullName;
  final String? resumeURL;
  final String? email;

  JobSeekerModel({
    required this.seekerID,
    required this.fullName,
    this.resumeURL,
    this.email,
  });

  factory JobSeekerModel.fromJson(Map<String, dynamic> json) {
    return JobSeekerModel(
      seekerID: json['seekerID'] as String,
      fullName: json['fullName'] as String,
      resumeURL: json['resumeURL'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seekerID': seekerID,
      'fullName': fullName,
      if (resumeURL != null) 'resumeURL': resumeURL,
      if (email != null) 'email': email,
    };
  }
}