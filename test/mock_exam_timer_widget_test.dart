import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/mock_exam/presentation/mock_exam_screen.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _questions = [
  Question(
    id: 'timer-test',
    text: 'テスト問題',
    choices: ['正解', '不正解1', '不正解2', '不正解3'],
    correctAnswerIndex: 0,
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'mock_exam_question_count': 20,
      'mock_exam_time_limit_minutes': 20,
    });
  });

  testWidgets('カウントダウンを一時停止・再開し、タイムアップで採点する',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockExamQuestionsProvider
              .overrideWith((ref) => Stream.value(_questions)),
        ],
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('試験を始める'));
    await tester.pump();

    expect(find.text('20:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('19:58'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pause-exam')));
    await tester.pump();
    expect(find.text('試験を一時停止中'), findsOneWidget);
    expect(find.text('再開'), findsOneWidget);
    final pausedTime = tester.widget<Text>(find.text('19:58')).data;
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(pausedTime!), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('resume-exam')));
    await tester.pump();
    expect(find.text('試験を一時停止中'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('19:57'), findsOneWidget);

    await tester.pump(const Duration(minutes: 20));
    await tester.pump();
    expect(find.text('模擬試験結果'), findsOneWidget);
    expect(find.text('正解数'), findsOneWidget);
    expect(find.text('不正解数'), findsOneWidget);
    expect(find.text('正答率'), findsOneWidget);
    expect(find.text('回答時間'), findsOneWidget);
    expect(find.text('未回答数'), findsOneWidget);
    expect(find.text('1問'), findsNWidgets(2));
    expect(find.text('テスト問題'), findsOneWidget);
  });

  testWidgets('バックグラウンド移行で一時停止する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockExamQuestionsProvider
              .overrideWith((ref) => Stream.value(_questions)),
        ],
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('試験を始める'));
    await tester.pump();

    await tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('試験を一時停止中'), findsOneWidget);
    await tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('試験を一時停止中'), findsOneWidget);
  });
}
