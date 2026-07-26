class Question {
  const Question({
    required this.id,
    required this.text,
    required this.choices,
    required this.correctAnswerIndex,
    this.explanation = '',
    this.category = '',
  });

  final String id;
  final String text;
  final List<String> choices;
  final int correctAnswerIndex;
  final String explanation;
  final String category;

  factory Question.fromSheetRow(Map<String, String> row) {
    final choices = [
      row['choice1'] ?? '',
      row['choice2'] ?? '',
      row['choice3'] ?? '',
      row['choice4'] ?? '',
    ];
    final answer = int.tryParse(row['correctAnswer'] ?? '');
    if ((row['id'] ?? '').isEmpty ||
        (row['question'] ?? '').isEmpty ||
        choices.any((choice) => choice.isEmpty) ||
        answer == null ||
        answer < 1 ||
        answer > choices.length) {
      throw const FormatException('問題データの必須項目または正解番号が不正です。');
    }
    return Question(
      id: row['id']!,
      text: row['question']!,
      choices: List.unmodifiable(choices),
      correctAnswerIndex: answer - 1,
      explanation: row['explanation'] ?? '',
      category: row['category'] ?? '',
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        text: json['text'] as String,
        choices: List<String>.from(json['choices'] as List),
        correctAnswerIndex: json['correctAnswerIndex'] as int,
        explanation: json['explanation'] as String? ?? '',
        category: json['category'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'choices': choices,
        'correctAnswerIndex': correctAnswerIndex,
        'explanation': explanation,
        'category': category,
      };
}
