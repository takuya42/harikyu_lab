class Question {
  const Question({
    required this.id,
    required this.subject,
    required this.category,
    required this.question,
    required this.choices,
    required this.answer,
    required this.explanation,
    this.image,
  });

  final String id;
  final String subject;
  final String category;
  final String question;
  final List<String> choices;
  final String answer;
  final String explanation;
  final String? image;

  factory Question.fromCsvRow(Map<String, String> row) {
    String value(String key) => row[key]?.trim() ?? '';
    final image = value('image');
    return Question(
      id: value('id'),
      subject: value('subject'),
      category: value('category'),
      question: value('question'),
      choices: [
        value('choice1'),
        value('choice2'),
        value('choice3'),
        value('choice4'),
      ],
      answer: value('answer'),
      explanation: value('explanation'),
      image: image.isEmpty ? null : image,
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    subject: json['subject'] as String,
    category: json['category'] as String,
    question: json['question'] as String,
    choices: (json['choices'] as List).cast<String>(),
    answer: json['answer'] as String,
    explanation: json['explanation'] as String,
    image: json['image'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'category': category,
    'question': question,
    'choices': choices,
    'answer': answer,
    'explanation': explanation,
    'image': image,
  };

  int get correctChoiceIndex {
    final numericAnswer = int.tryParse(answer);
    if (numericAnswer != null && numericAnswer >= 1 && numericAnswer <= 4) {
      return numericAnswer - 1;
    }
    return choices.indexOf(answer);
  }
}
