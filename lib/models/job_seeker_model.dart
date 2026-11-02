import 'education_model.dart';
import 'work_experience_model.dart';

class JobSeekerModel {
  final String seekerID;
  final String fullName;
  final String? resumeURL;
  final String? email;
  final String? profilePictureURL;

  // Profile Fields
  final String? phoneNumber;
  final String? location;
  final String? bio;
  final String? careerGoal; // also given to the AI Career Advisor and Skill Gap Analysis
  final String? linkedInURL;
  final String? gitHubURL;

  // Relational Data
  final List<EducationModel> education;
  final List<WorkExperienceModel> workExperience;

  JobSeekerModel({
    required this.seekerID,
    required this.fullName,
    this.resumeURL,
    this.email,
    this.profilePictureURL,
    this.phoneNumber,
    this.location,
    this.bio,
    this.careerGoal,
    this.linkedInURL,
    this.gitHubURL,
    this.education = const [],
    this.workExperience = const [],
  });

  factory JobSeekerModel.fromJson(Map<String, dynamic> json) {
    // Safely extract joined tables if they are fetched from Supabase
    var eduList = json['Education'] as List? ?? [];
    var expList = json['WorkExperience'] as List? ?? [];

    return JobSeekerModel(
      seekerID: json['seekerID'] as String,
      fullName: json['fullName'] as String,
      resumeURL: json['resumeURL'] as String?,
      email: json['email'] as String?,
      profilePictureURL: json['profilePictureURL'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      location: json['location'] as String?,
      bio: json['bio'] as String?,
      careerGoal: json['careerGoal'] as String?,
      linkedInURL: json['linkedInURL'] as String?,
      gitHubURL: json['gitHubURL'] as String?,

      // Parse lists
      education: eduList.map((e) => EducationModel.fromJson(e)).toList(),
      workExperience: expList.map((e) => WorkExperienceModel.fromJson(e)).toList(),
    );
  }

  /// Null fields are sent too, so clearing a field in the app clears it in the database.
  Map<String, dynamic> toJson() {
    return {
      'seekerID': seekerID,
      'fullName': fullName,
      'resumeURL': resumeURL,
      'email': email,
      'profilePictureURL': profilePictureURL,
      'phoneNumber': phoneNumber,
      'location': location,
      'bio': bio,
      'careerGoal': careerGoal,
      'linkedInURL': linkedInURL,
      'gitHubURL': gitHubURL,
    };
  }
}
