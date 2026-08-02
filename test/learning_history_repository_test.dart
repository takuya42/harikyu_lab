import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  LearningHistory history(String id, DateTime completedAt) => LearningHistory(
    id: id,
    type: LearningType.quickQuiz,
    completedAt: completedAt,
    questionCount: 1,
    correctCount: 0,
    unansweredCount: 0,
    duration: const Duration(seconds: 12),
    category: '東洋医学',
    answers: const [
      HistoryAnswer(
        question: '問題文',
        selectedAnswer: '回答',
        correctAnswer: '正解',
        explanation: '解説',
        isCorrect: false,
      ),
    ],
  );

  test('学習履歴を新しい順で永続化する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalLearningHistoryRepository(
      preferences,
      userId: 'user-1',
    );

    await repository.save(history('old', DateTime(2026, 8, 1)));
    await repository.save(history('new', DateTime(2026, 8, 2)));

    final restored = LocalLearningHistoryRepository(
      preferences,
      userId: 'user-1',
    );
    final items = await restored.watch().first;
    expect(items.map((item) => item.id), ['new', 'old']);
    expect(items.first.answers.single.explanation, '解説');

    repository.dispose();
    restored.dispose();
  });

  test('ログインユーザーごとに履歴を分離する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = LocalLearningHistoryRepository(preferences, userId: 'one');
    final second = LocalLearningHistoryRepository(preferences, userId: 'two');

    await first.save(history('first', DateTime(2026, 8, 2)));

    expect(await first.watch().first, hasLength(1));
    expect(await second.watch().first, isEmpty);
    first.dispose();
    second.dispose();
  });
}
