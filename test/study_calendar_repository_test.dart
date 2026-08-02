import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  LearningHistory session({
    required DateTime completedAt,
    required int answered,
    required int correct,
    LearningType type = LearningType.quickQuiz,
  }) => LearningHistory(
    id: completedAt.microsecondsSinceEpoch.toString(),
    type: type,
    completedAt: completedAt,
    questionCount: answered,
    correctCount: correct,
    unansweredCount: 0,
    duration: const Duration(seconds: 90),
    category: '',
    answers: const [],
  );

  test('同日の学習を加算し、設定した目標で達成を判定する', () async {
    SharedPreferences.setMockInitialValues({dailyGoalPreferenceKey: 20});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalStudyCalendarRepository(preferences);
    final date = DateTime(2026, 8, 2, 10);

    await repository.addSession(
      session(completedAt: date, answered: 8, correct: 6),
    );
    await repository.addSession(
      session(
        completedAt: date.add(const Duration(hours: 2)),
        answered: 12,
        correct: 10,
        type: LearningType.mockExam,
      ),
    );

    final day = (await repository.watch().first).single;
    expect(day.answeredCount, 20);
    expect(day.correctCount, 16);
    expect(day.studySeconds, 180);
    expect(day.examCount, 1);
    expect(day.dailyGoal, 20);
    expect(day.goalAchieved, isTrue);
    repository.dispose();
  });
}
