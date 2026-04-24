class ApplicationAnswerModel {
  final String? answerID; // Nullable because Supabase generates this
  final String questionID;
  final String applicantID;
  final String? answerText;
  final String? answerFileURL;

  ApplicationAnswerModel({
    this.answerID,
    required this.questionID,
    required this.applicantID,
    this.answerText,
    this.answerFileURL,
  });

  factory ApplicationAnswerModel.fromJson(Map<String, dynamic> json) {
    return ApplicationAnswerModel(
      answerID: json['answerID'] as String?,
      questionID: json['questionID'] as String,
      applicantID: json['applicantID'] as String,
      answerText: json['answerText'] as String?,
      answerFileURL: json['answerFileURL'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (answerID != null) 'answerID': answerID,
      'questionID': questionID,
      'applicantID': applicantID,
      if (answerText != null) 'answerText': answerText,
      if (answerFileURL != null) 'answerFileURL': answerFileURL,
    };
  }
}