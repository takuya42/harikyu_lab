enum LearningType { quickQuiz, category, mockExam }

extension LearningTypeLabel on LearningType {
  String get label => switch (this) {
    LearningType.quickQuiz => '一問一答',
    LearningType.category => 'カテゴリ学習',
    LearningType.mockExam => '模擬試験',
  };
}

class HistoryAnswer {
  const HistoryAnswer({
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.explanation,
    required this.isCorrect,
  });

  final String question;
  final String selectedAnswer;
  final String correctAnswer;
  final String explanation;
  final bool isCorrect;

  factory HistoryAnswer.fromJson(Map<String, dynamic> json) => HistoryAnswer(
    question: json['question'] as String? ?? '',
    selectedAnswer: json['selectedAnswer'] as String? ?? '',
    correctAnswer: json['correctAnswer'] as String? ?? '',
    explanation: json['explanation'] as String? ?? '',
    isCorrect: json['isCorrect'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'question': question,
    'selectedAnswer': selectedAnswer,
    'correctAnswer': correctAnswer,
    'explanation': explanation,
    'isCorrect': isCorrect,
  };
}

class LearningHistory {
  const LearningHistory({
    required this.id,
    required this.type,
    required this.completedAt,
    required this.questionCount,
    required this.correctCount,
    required this.unansweredCount,
    required this.duration,
    required this.category,
    required this.answers,
  });

  final String id;
  final LearningType type;
  final DateTime completedAt;
  final int questionCount;
  final int correctCount;
  final int unansweredCount;
  final Duration duration;
  final String category;
  final List<HistoryAnswer> answers;

  int get answeredCount => questionCount - unansweredCount;
  int get incorrectCount => answeredCount - correctCount;
  int get accuracy => questionCount == 0 ? 0 : (correctCount * 100 / questionCount).round();

  factory LearningHistory.fromJson(Map<String, dynamic> json) => LearningHistory(
    id: json['id'] as String,
    type: LearningType.values.byName(json['type'] as String),
    completedAt: DateTime.parse(json['completedAt'] as String),
    questionCount: json['questionCount'] as int,
    correctCount: json['correctCount'] as int,
    unansweredCount: json['unansweredCount'] as int? ?? 0,
    duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
    category: json['category'] as String? ?? '',
    answers: List.unmodifiable(
      (json['answers'] as List<dynamic>? ?? const []).map(
        (item) => HistoryAnswer.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'completedAt': completedAt.toIso8601String(),
    'questionCount': questionCount,
    'correctCount': correctCount,
    'unansweredCount': unansweredCount,
    'durationSeconds': duration.inSeconds,
    'category': category,
    'answers': answers.map((item) => item.toJson()).toList(),
  };
}
