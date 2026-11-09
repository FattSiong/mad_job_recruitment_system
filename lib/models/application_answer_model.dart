class ApplicationAnswerModel {
  final String? answerID; // Nullable because Supabase generates this
  final String questionID;
  final String applicantID;
  final String? answerText;
  final String? answerFileURL;
  final int? score; // Nullable: null = ungraded (?/5), 0..5 = employer marks

  ApplicationAnswerModel({
    this.answerID,
    required this.questionID,
    required this.applicantID,
    this.answerText,
    this.answerFileURL,
    this.score,
  });

  factory ApplicationAnswerModel.fromJson(Map<String, dynamic> json) {
    return ApplicationAnswerModel(
      answerID: json['answerID'] as String?,
      questionID: json['questionID'] as String,
      applicantID: json['applicantID'] as String,
      answerText: json['answerText'] as String?,
      answerFileURL: json['answerFileURL'] as String?,
      score: (json['score'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (answerID != null) 'answerID': answerID,
      'questionID': questionID,
      'applicantID': applicantID,
      if (answerText != null) 'answerText': answerText,
      if (answerFileURL != null) 'answerFileURL': answerFileURL,
      if (score != null) 'score': score,
    };
  }
}
