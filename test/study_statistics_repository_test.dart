import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('回答結果と連続学習日数をSharedPreferencesへ永続化する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LearningHistoryStudyStatisticsRepository(preferences);

    await repository.recordAnswer(isCorrect: true);
    await repository.recordAnswer(isCorrect: false);

    final restored = LearningHistoryStudyStatisticsRepository(preferences);
    final statistics = await restored.watch().first;
    expect(statistics.streakDays, 1);
    expect(statistics.totalAnswered, 2);
    expect(statistics.correctAnswered, 1);
    expect(statistics.accuracy, 50);

    repository.dispose();
    restored.dispose();
  });

  test('ログインユーザーとゲストの統計を別々に保持する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final guest = LearningHistoryStudyStatisticsRepository(preferences);
    final user = LearningHistoryStudyStatisticsRepository(
      preferences,
      userId: 'user-1',
    );

    await guest.recordAnswer(isCorrect: false);
    await user.recordAnswer(isCorrect: true);
    await user.recordAnswer(isCorrect: true);

    expect((await guest.watch().first).totalAnswered, 1);
    expect((await user.watch().first).totalAnswered, 2);
    expect((await user.watch().first).accuracy, 100);

    guest.dispose();
    user.dispose();
  });

  test('既存の未ログイン統計を引き継ぐ', () async {
    SharedPreferences.setMockInitialValues({
      'study_streak_days_v1': 3,
      'study_last_date_v1': '2026-07-29',
      'study_total_answered_v1': 10,
      'study_correct_answered_v1': 7,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = LearningHistoryStudyStatisticsRepository(
      preferences,
      now: () => DateTime(2026, 7, 29),
    );

    final statistics = await repository.watch().first;
    expect(statistics.streakDays, 3);
    expect(statistics.totalAnswered, 10);
    expect(statistics.correctAnswered, 7);
    expect(statistics.accuracy, 70);

    repository.dispose();
  });

  test('1問以上回答した日だけを連続学習日数として数える', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var now = DateTime(2026, 7, 27, 12);
    final repository = LearningHistoryStudyStatisticsRepository(
      preferences,
      now: () => now,
    );

    repository.startSession();
    expect((await repository.watch().first).streakDays, 0);
    await repository.recordAnswer(isCorrect: true);
    await repository.recordAnswer(isCorrect: true);
    expect((await repository.watch().first).streakDays, 1);

    now = DateTime(2026, 7, 28, 12);
    await repository.recordAnswer(isCorrect: false);
    expect((await repository.watch().first).streakDays, 2);

    now = DateTime(2026, 7, 30, 12);
    await repository.recordAnswer(isCorrect: true);
    expect((await repository.watch().first).streakDays, 1);

    repository.dispose();
  });
}
