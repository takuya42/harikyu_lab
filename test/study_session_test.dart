import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/domain/study_session.dart';

void main() {
  test('CSVの正解番号1〜4を正しい選択肢に対応させ、並べ替え後も維持する', () {
    for (var answer = 1; answer <= 4; answer++) {
      final question = Question.fromSheetRow({
        'id': '$answer',
        'question': '正解番号の確認',
        'choice1': '選択肢1',
        'choice2': '選択肢2',
        'choice3': '選択肢3',
        'choice4': '選択肢4',
        'answer': '$answer',
      });
      expect(question.correctAnswerIndex, answer - 1);
      for (var seed = 0; seed < 20; seed++) {
        final displayed = createStudySession(
          [question],
          isPro: false,
          random: Random(seed),
        ).single;
        expect(displayed.choices[displayed.correctAnswerIndex], '選択肢$answer');
      }
    }
  });

  test('元の正解がすべて1番でも表示位置は1〜4に分散する', () {
    final questions = List.generate(
      4000,
      (index) => Question(
        id: '$index',
        text: '問題$index',
        choices: const ['正解', '誤答1', '誤答2', '誤答3'],
        correctAnswerIndex: 0,
      ),
    );
    final session = createStudySession(
      questions,
      isPro: false,
      random: Random(42),
    );
    final positions = List.filled(4, 0);
    for (final item in session) {
      positions[item.correctAnswerIndex]++;
      expect(item.choices[item.correctAnswerIndex], '正解');
      expect(item.question.correctAnswerIndex, 0);
    }
    for (final count in positions) {
      expect(count, inInclusiveRange(800, 1200));
    }
  });

  test('復習の問題順を維持しても選択肢はシャッフルする', () {
    final questions = List.generate(
      40,
      (index) => Question(
        id: '$index',
        text: '問題$index',
        choices: const ['正解', '同じ誤答', '同じ誤答', '誤答'],
        correctAnswerIndex: 0,
      ),
    );
    final session = createStudySession(
      questions,
      isPro: false,
      preserveQuestionOrder: true,
      random: Random(42),
    );
    expect(
      session.map((item) => item.question.id),
      questions.map((item) => item.id),
    );
    expect(session.map((item) => item.correctAnswerIndex).toSet(), {
      0,
      1,
      2,
      3,
    });
    for (final item in session) {
      expect(item.choices[item.correctAnswerIndex], '正解');
    }
  });

  test('問題と選択肢をシャッフルしても正解の選択肢を維持する', () {
    const questions = [
      Question(
        id: '1',
        text: '問題1',
        choices: ['正解1', '誤り1', '誤り2', '誤り3'],
        correctAnswerIndex: 0,
      ),
      Question(
        id: '2',
        text: '問題2',
        choices: ['誤り1', '誤り2', '正解2', '誤り3'],
        correctAnswerIndex: 2,
      ),
    ];

    final session = createStudySession(
      questions,
      isPro: false,
      random: Random(7),
    );

    expect(session, hasLength(2));
    expect(questions.map((item) => item.id), ['1', '2']);
    for (final item in session) {
      final originalCorrect =
          item.question.choices[item.question.correctAnswerIndex];
      expect(item.choices[item.correctAnswerIndex], originalCorrect);
    }
  });

  test('指定した問題数を重複なく抽出する', () {
    final questions = List.generate(
      200,
      (index) => Question(
        id: '$index',
        text: '問題$index',
        choices: const ['1', '2', '3', '4'],
        correctAnswerIndex: 0,
      ),
    );

    final session = createStudySession(
      questions,
      isPro: true,
      random: Random(1),
      questionCount: 100,
    );

    expect(session, hasLength(100));
    expect(session.map((item) => item.question.id).toSet(), hasLength(100));
  });
}
