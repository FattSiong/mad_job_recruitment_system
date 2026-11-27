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

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

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
///
/// The speech numbers are saved together in "speechMetrics" and the camera
/// numbers in "faceMetrics" (null when the camera was off).
class MockInterviewAnswerModel {
  final String answerID;
  final String sessionID;
  final int questionIndex;
  final String questionText;
  final String transcriptText;

  // Speech metrics (speechMetrics, from Deepgram word timestamps)
  final double? durationSeconds;
  final double? wordsPerMinute;
  final int? wordCount;
  final int? fillerWordCount;
  final double? fillerRate;
  final int? longPauseCount;
  final int? hesitationCount;
  final double? responseLatencySeconds;

  // Body language from the camera (faceMetrics, ML Kit on the phone).
  // Null = camera off. Feedback only: not part of contentScore / deliveryScore.
  final int? eyeContactPercent;
  final int? smilePercent;
  final int? facePresentPercent;
  final int? lookAwayCount;

  // Gemini feedback
  final int? contentScore;
  final int? deliveryScore;
  final Map<String, dynamic> aiFeedback;

  /// "slow" | "good" | "fast" (from speechMetrics)
  final String paceLabel;

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
    this.eyeContactPercent,
    this.smilePercent,
    this.facePresentPercent,
    this.lookAwayCount,
    this.contentScore,
    this.deliveryScore,
    this.aiFeedback = const {},
    this.paceLabel = '',
  });

  String get relevance => aiFeedback['relevance'] as String? ?? '';
  String get deliveryFeedback => aiFeedback['deliveryFeedback'] as String? ?? '';
  String get improvedAnswer => aiFeedback['improvedAnswer'] as String? ?? '';
  List<String> get strengths => _stringList(aiFeedback['strengths']);
  List<String> get improvements => _stringList(aiFeedback['improvements']);

  /// The camera was on while answering.
  bool get hasBodyLanguage => facePresentPercent != null;

  /// One or two sentences about eye contact and expression (camera on only).
  String get bodyLanguageFeedback => aiFeedback['bodyLanguageFeedback'] as String? ?? '';

  factory MockInterviewAnswerModel.fromJson(Map<String, dynamic> json) {
    final speech = _map(json['speechMetrics']);
    final face = _map(json['faceMetrics']);
    return MockInterviewAnswerModel(
      answerID: json['answerID'] as String,
      sessionID: json['sessionID'] as String,
      questionIndex: _toInt(json['questionIndex']) ?? 0,
      questionText: json['questionText'] as String? ?? '',
      transcriptText: json['transcriptText'] as String? ?? '',
      durationSeconds: _toDouble(speech['durationSeconds']),
      wordsPerMinute: _toDouble(speech['wordsPerMinute']),
      wordCount: _toInt(speech['wordCount']),
      fillerWordCount: _toInt(speech['fillerWordCount']),
      fillerRate: _toDouble(speech['fillerRate']),
      longPauseCount: _toInt(speech['longPauseCount']),
      hesitationCount: _toInt(speech['hesitationCount']),
      responseLatencySeconds: _toDouble(speech['responseLatencySeconds']),
      eyeContactPercent: _toInt(face['eyeContactPercent']),
      smilePercent: _toInt(face['smilePercent']),
      facePresentPercent: _toInt(face['facePresentPercent']),
      lookAwayCount: _toInt(face['lookAwayCount']),
      contentScore: _toInt(json['contentScore']),
      deliveryScore: _toInt(json['deliveryScore']),
      aiFeedback: _map(json['aiFeedback']),
      paceLabel: speech['paceLabel'] as String? ?? '',
    );
  }
}

/// A mock interview session (row of MockInterviewSession) plus its answers.
class MockInterviewSessionModel {
  final String sessionID;
  final String seekerID;
  final String targetJobRole;
  final String? experienceLevel;
  final String status; // in_progress | completed
  final int questionCount;
  final List<InterviewQuestion> questions;
  /// Set by the database: 60% content + 40% delivery.
  final int? overallScore;
  final int? contentScore;
  final int? deliveryScore;

  /// Averages of the answers recorded with the camera on (null = camera never on).
  /// Feedback only: not part of [overallScore].
  final int? eyeContactPercent;
  final int? smilePercent;

  final Map<String, dynamic> aiFeedback;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<MockInterviewAnswerModel> answers;

  MockInterviewSessionModel({
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
    this.eyeContactPercent,
    this.smilePercent,
    this.aiFeedback = const {},
    required this.createdAt,
    this.completedAt,
    this.answers = const [],
  });

  String get summary => aiFeedback['summary'] as String? ?? '';
  String get readiness => aiFeedback['readiness'] as String? ?? '';
  List<String> get strengths => _stringList(aiFeedback['strengths']);
  List<String> get improvements => _stringList(aiFeedback['improvements']);
  List<String> get tips => _stringList(aiFeedback['tips']);
  Map<String, dynamic> get speech => _map(aiFeedback['speech']);

  /// {answersWithCamera, eyeContactPercent, smilePercent, totalLookAways, feedback}
  /// Empty when the camera was never on.
  Map<String, dynamic> get bodyLanguage => _map(aiFeedback['bodyLanguage']);

  /// Answers recorded with the camera on.
  int get answersWithCamera => answers.where((a) => a.hasBodyLanguage).length;

  factory MockInterviewSessionModel.fromJson(Map<String, dynamic> json) {
    final answersJson = json['MockInterviewAnswer'] as List? ?? [];
    final answers = answersJson
        .map((e) => MockInterviewAnswerModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.questionIndex.compareTo(b.questionIndex));

    return MockInterviewSessionModel(
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
      eyeContactPercent: _toInt(json['eyeContactPercent']),
      smilePercent: _toInt(json['smilePercent']),
      aiFeedback: _map(json['aiFeedback']),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String).toLocal(),
      answers: answers,
    );
  }
}
