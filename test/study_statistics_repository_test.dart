import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('回答結果をSharedPreferencesへ永続化する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LearningHistoryStudyStatisticsRepository(preferences);

    await repository.recordAnswer(isCorrect: true);
    await repository.recordAnswer(isCorrect: false);

    final restored = LearningHistoryStudyStatisticsRepository(preferences);
    final statistics = await restored.watch().first;
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
      'study_total_answered_v1': 10,
      'study_correct_answered_v1': 7,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = LearningHistoryStudyStatisticsRepository(
      preferences,
    );

    final statistics = await repository.watch().first;
    expect(statistics.totalAnswered, 10);
    expect(statistics.correctAnswered, 7);
    expect(statistics.accuracy, 70);

    repository.dispose();
  });
}
