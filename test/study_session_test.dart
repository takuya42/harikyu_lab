import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/domain/study_session.dart';

void main() {
  test('問題と選択肢をシャッフルしても正解の選択肢を維持する', () {
    const questions = [
      Question(id: '1', text: '問題1', choices: ['正解1', '誤り1', '誤り2', '誤り3'], correctAnswerIndex: 0),
      Question(id: '2', text: '問題2', choices: ['誤り1', '誤り2', '正解2', '誤り3'], correctAnswerIndex: 2),
    ];

    final session = createStudySession(questions, random: Random(7));

    expect(session, hasLength(2));
    expect(questions.map((item) => item.id), ['1', '2']);
    for (final item in session) {
      final originalCorrect = item.question.choices[item.question.correctAnswerIndex];
      expect(item.choices[item.correctAnswerIndex], originalCorrect);
    }
  });
}
