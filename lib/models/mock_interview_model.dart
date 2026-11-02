double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

List<String> _stringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// One question in a mock interview (index 0 is always the introduction).
class InterviewQuestion {
  final int index;
  final String question;
  final String type; // introduction | behavioural | technical | situational | motivation

  InterviewQuestion({
    required this.index,
    required this.question,
    required this.type,
  });

  bool get isIntroduction => index == 0;

  String get typeLabel {
    if (type.isEmpty) return '';
    return type[0].toUpperCase() + type.substring(1);
  }

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) {
    return InterviewQuestion(
      index: _toInt(json['index']) ?? 0,
      question: json['question'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  static List<InterviewQuestion> listFromJson(dynamic json) {
    if (json is! List) return [];
    final list = json
        .map((e) => InterviewQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.index.compareTo(b.index));
    return list;
  }
}

/// One evaluated answer (row of MockInterviewAnswer).
class MockInterviewAnswerModel {
  final String answerID;
  final String sessionID;
  final int questionIndex;
  final String questionText;
  final String transcriptText;

  // Speech metrics (from Deepgram word timestamps)
  final double? durationSeconds;
  final double? wordsPerMinute;
  final int? wordCount;
  final int? fillerWordCount;
  final double? fillerRate;
  final int? longPauseCount;
  final int? hesitationCount;
  final double? responseLatencySeconds;

  // Gemini feedback
  final int? contentScore;
  final int? deliveryScore;
  final Map<String, dynamic> feedback;

  MockInterviewAnswerModel({
    required this.answerID,
    required this.sessionID,
    required this.questionIndex,
    required this.questionText,
    required this.transcriptText,
    this.durationSeconds,
    this.wordsPerMinute,
    this.wordCount,
    this.fillerWordCount,
    this.fillerRate,
    this.longPauseCount,
    this.hesitationCount,
    this.responseLatencySeconds,
    this.contentScore,
    this.deliveryScore,
    this.feedback = const {},
  });

  String get relevance => feedback['relevance'] as String? ?? '';
  String get deliveryFeedback => feedback['deliveryFeedback'] as String? ?? '';
  String get improvedAnswer => feedback['improvedAnswer'] as String? ?? '';
  List<String> get strengths => _stringList(feedback['strengths']);
  List<String> get improvements => _stringList(feedback['improvements']);

  /// "slow" | "good" | "fast"
  String get paceLabel =>
      (feedback['metrics'] as Map?)?['paceLabel'] as String? ?? '';

  factory MockInterviewAnswerModel.fromJson(Map<String, dynamic> json) {
    return MockInterviewAnswerModel(
      answerID: json['answerID'] as String,
      sessionID: json['sessionID'] as String,
      questionIndex: _toInt(json['questionIndex']) ?? 0,
      questionText: json['questionText'] as String? ?? '',
      transcriptText: json['transcriptText'] as String? ?? '',
      durationSeconds: _toDouble(json['durationSeconds']),
      wordsPerMinute: _toDouble(json['wordsPerMinute']),
      wordCount: _toInt(json['wordCount']),
      fillerWordCount: _toInt(json['fillerWordCount']),
      fillerRate: _toDouble(json['fillerRate']),
      longPauseCount: _toInt(json['longPauseCount']),
      hesitationCount: _toInt(json['hesitationCount']),
      responseLatencySeconds: _toDouble(json['responseLatencySeconds']),
      contentScore: _toInt(json['contentScore']),
      deliveryScore: _toInt(json['deliveryScore']),
      feedback: (json['feedback'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// A mock interview session (row of MockInterviewRecord) plus its answers.
class MockInterviewRecordModel {
  final String sessionID;
  final String seekerID;
  final String targetJobRole;
  final String? experienceLevel;
  final String status; // in_progress | completed
  final int questionCount;
  final List<InterviewQuestion> questions;
  final int? overallScore;
  final int? contentScore;
  final int? deliveryScore;
  final Map<String, dynamic> aiEvaluationReport;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<MockInterviewAnswerModel> answers;

  MockInterviewRecordModel({
    required this.sessionID,
    required this.seekerID,
    required this.targetJobRole,
    this.experienceLevel,
    required this.status,
    required this.questionCount,
    required this.questions,
    this.overallScore,
    this.contentScore,
    this.deliveryScore,
    this.aiEvaluationReport = const {},
    required this.createdAt,
    this.completedAt,
    this.answers = const [],
  });

  String get summary => aiEvaluationReport['summary'] as String? ?? '';
  String get readiness => aiEvaluationReport['readiness'] as String? ?? '';
  List<String> get strengths => _stringList(aiEvaluationReport['strengths']);
  List<String> get improvements => _stringList(aiEvaluationReport['improvements']);
  List<String> get tips => _stringList(aiEvaluationReport['tips']);
  Map<String, dynamic> get speech =>
      (aiEvaluationReport['speech'] as Map?)?.cast<String, dynamic>() ?? const {};

  factory MockInterviewRecordModel.fromJson(Map<String, dynamic> json) {
    final answersJson = json['MockInterviewAnswer'] as List? ?? [];
    final answers = answersJson
        .map((e) => MockInterviewAnswerModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.questionIndex.compareTo(b.questionIndex));

    return MockInterviewRecordModel(
      sessionID: json['sessionID'] as String,
      seekerID: json['seekerID'] as String,
      targetJobRole: json['targetJobRole'] as String? ?? '',
      experienceLevel: json['experienceLevel'] as String?,
      status: json['status'] as String? ?? 'in_progress',
      questionCount: _toInt(json['questionCount']) ?? 5,
      questions: InterviewQuestion.listFromJson(json['questions']),
      overallScore: _toInt(json['overallScore']),
      contentScore: _toInt(json['contentScore']),
      deliveryScore: _toInt(json['deliveryScore']),
      aiEvaluationReport:
          (json['aiEvaluationReport'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String).toLocal(),
      answers: answers,
    );
  }
}
