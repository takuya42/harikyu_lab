import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';
import 'package:harikyu_lab/features/learning_history/presentation/learning_history_screen.dart';

void main() {
  test('Firestore document ID uses yyyy-MM-dd', () {
    expect(studyDateKey(DateTime(2026, 8, 2, 23, 59)), '2026-08-02');
    expect(studyDateKey(DateTime(2026, 12, 31)), '2026-12-31');
  });

  test('Firestoreエラーは種別とpermission-deniedを表示できる', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );

    final message = calendarErrorMessage(error);

    expect(message, contains('FirebaseException'));
    expect(message, contains('permission-denied'));
  });

  test('連続学習日数は今日からansweredCountがある日だけを数える', () {
    StudyCalendarDay day(int date, int answers) => StudyCalendarDay(
      date: DateTime(2026, 8, date),
      answeredCount: answers,
      correctCount: 0,
      studySeconds: 0,
      examCount: 0,
      goalAchieved: false,
      dailyGoal: 10,
    );

    final days = [day(2, 10), day(1, 3), day(0, 1), day(-1, 0)];
    expect(calculateStudyStreak(days, today: DateTime(2026, 8, 2)), 3);
    expect(calculateStudyStreak(days, today: DateTime(2026, 8, 3)), 0);
  });
}
