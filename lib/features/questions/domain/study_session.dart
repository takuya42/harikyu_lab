import 'dart:math';

import 'package:harikyu_lab/features/questions/domain/question.dart';

/// A question prepared for display without changing the persisted [Question].
class StudyQuestion {
  const StudyQuestion({
    required this.question,
    required this.choices,
    required this.correctAnswerIndex,
  });

  final Question question;
  final List<String> choices;
  final int correctAnswerIndex;
}

List<StudyQuestion> createStudySession(
  List<Question> questions, {
  required bool isPro,
  Random? random,
  int? questionCount,
}) {
  final generator = random ?? Random();
  final shuffledQuestions = List<Question>.of(questions)..shuffle(generator);

  final selectedQuestions = questionCount == null
      ? shuffledQuestions
      : shuffledQuestions.take(questionCount).toList();

  return List.unmodifiable(selectedQuestions.map((question) {
    final indexedChoices = [
      for (var index = 0; index < question.choices.length; index++)
        (index: index, text: question.choices[index]),
    ]..shuffle(generator);
    return StudyQuestion(
      question: question,
      choices: List.unmodifiable(indexedChoices.map((choice) => choice.text)),
      correctAnswerIndex: indexedChoices.indexWhere(
        (choice) => choice.index == question.correctAnswerIndex,
      ),
    );
  }));
}
