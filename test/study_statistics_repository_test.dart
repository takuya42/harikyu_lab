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
}
