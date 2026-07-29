class Question {
  const Question({
    required this.id,
    required this.text,
    required this.choices,
    required this.correctAnswerIndex,
    this.explanation = '',
    this.category = '',
    this.subject = '',
    this.imageUrl = '',
  });

  final String id;
  final String text;
  final List<String> choices;
  final int correctAnswerIndex;
  final String explanation;
  final String category;
  final String subject;
  final String imageUrl;

  /// Converts a spreadsheet row into a question.
  ///
  /// In addition to the original English headers, this accepts the header
  /// names used by the mock-exam sheet (Japanese names, `optionN`, and
  /// snake_case names). Answers may be 1-4, A-D, or their full-width forms.
  factory Question.fromSheetRow(
    Map<String, String> row, {
    String fallbackId = '',
  }) {
    String value(List<String> keys) {
      for (final key in keys) {
        final candidate = row[key]?.trim() ?? '';
        if (candidate.isNotEmpty) return candidate;
      }
      return '';
    }

    final id = value(const ['id', 'questionId', 'question_id', '問題ID', '番号']);
    final question = value(const ['question', 'text', '問題', '問題文']);
    final choices = [
      value(const ['choice1', 'choice_1', 'option1', 'option_1', '選択肢1']),
      value(const ['choice2', 'choice_2', 'option2', 'option_2', '選択肢2']),
      value(const ['choice3', 'choice_3', 'option3', 'option_3', '選択肢3']),
      value(const ['choice4', 'choice_4', 'option4', 'option_4', '選択肢4']),
    ];
    final answerValue = value(
      const ['answer', 'correctAnswer', 'correct_answer', '正解', '正解番号'],
    );
    final answer = _parseSheetAnswer(answerValue);
    final errors = <String>[
      if (id.isEmpty && fallbackId.isEmpty) 'id',
      if (question.isEmpty) 'question',
      for (var index = 0; index < choices.length; index++)
        if (choices[index].isEmpty) 'choice${index + 1}',
      if (answer == null) 'answer="$answerValue" (1-4 または A-D が必要)',
    ];
    if (errors.isNotEmpty) {
      throw FormatException(
        '問題データの不足・不正項目: ${errors.join(', ')}',
      );
    }
    return Question(
      id: id.isEmpty ? fallbackId : id,
      text: question,
      choices: List.unmodifiable(choices),
      correctAnswerIndex: answer! - 1,
      explanation: value(const ['explanation', '解説']),
      category: value(const ['category', 'カテゴリ', 'カテゴリー']),
      subject: value(const ['subject', '科目']),
      imageUrl: value(const ['image', 'imageUrl', 'image_url', '画像']),
    );
  }

  static int? _parseSheetAnswer(String source) {
    const fullWidthDigits = {'１': '1', '２': '2', '３': '3', '４': '4'};
    final normalized = (fullWidthDigits[source] ?? source).trim().toUpperCase();
    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric >= 1 && numeric <= 4) return numeric;
    const letters = {'A': 1, 'B': 2, 'C': 3, 'D': 4};
    return letters[normalized];
  }

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        text: json['text'] as String,
        choices: List<String>.from(json['choices'] as List),
        correctAnswerIndex: json['correctAnswerIndex'] as int,
        explanation: json['explanation'] as String? ?? '',
        category: json['category'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'choices': choices,
        'correctAnswerIndex': correctAnswerIndex,
        'explanation': explanation,
        'category': category,
        'subject': subject,
        'imageUrl': imageUrl,
      };
}
