class PreScreeningQuestionModel {
  final String? questionID;
  final String jobID;
  final String questionText;
  final bool isAIGenerated;
  final String questionType;

  PreScreeningQuestionModel({
    this.questionID,
    required this.jobID,
    required this.questionText,
    this.isAIGenerated = false,
    required this.questionType,
  });

  factory PreScreeningQuestionModel.fromJson(Map<String, dynamic> json) {
    return PreScreeningQuestionModel(
      questionID: json['questionID'] as String?,
      jobID: json['jobID'] as String,
      questionText: json['questionText'] as String,
      isAIGenerated: json['isAIGenerated'] as bool? ?? false,
      questionType: json['questionType'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (questionID != null) 'questionID': questionID,
      'jobID': jobID,
      'questionText': questionText,
      'isAIGenerated': isAIGenerated,
      'questionType': questionType,
    };
  }
}