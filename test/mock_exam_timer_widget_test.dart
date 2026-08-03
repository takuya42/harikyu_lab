import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/mock_exam/data/mock_exam_attempt_service.dart';
import 'package:harikyu_lab/features/mock_exam/presentation/mock_exam_screen.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
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

class _AllowedAttemptService implements MockExamAttemptService {
  @override
  Future<bool> tryStart({required bool isPro}) async => true;
}

class _DeniedAttemptService implements MockExamAttemptService {
  @override
  Future<bool> tryStart({required bool isPro}) async => false;
}

final _commonOverrides = [
  isProProvider.overrideWith((ref) => Stream.value(false)),
  mockExamAttemptServiceProvider.overrideWithValue(_AllowedAttemptService()),
  mockExamQuestionsProvider.overrideWith((ref) => Stream.value(_questions)),
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
        overrides: _commonOverrides,
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
    expect(find.text('模擬試験終了'), findsOneWidget);
    expect(find.text('よく頑張りました！'), findsOneWidget);
    expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
    expect(find.text('正解'), findsOneWidget);
    expect(find.text('不正解'), findsOneWidget);
    expect(find.text('正答率'), findsOneWidget);
    expect(find.text('回答時間'), findsOneWidget);
    expect(find.text('未回答'), findsOneWidget);
    expect(find.text('もう一度挑戦'), findsOneWidget);
    expect(find.text('ホームへ戻る'), findsOneWidget);
    expect(find.text('1問'), findsNWidgets(2));
    expect(find.text('テスト問題'), findsNothing);
    expect(find.text('回答した問題は全問正解です！'), findsOneWidget);
  });

  testWidgets('開発用10秒タイマーを表示せず、Freeは20分に補正する',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'mock_exam_question_count': 20,
      'mock_exam_time_limit_minutes': 10,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commonOverrides,
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10秒（開発用）'), findsNothing);
    expect(find.text('20分'), findsOneWidget);
    await tester.tap(find.text('試験を始める'));
    await tester.pump();
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('Freeのロック項目に鍵を表示し、選択時にPro案内を表示する',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commonOverrides,
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('20問').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3));
    await tester.tap(find.text('50問'));
    await tester.pumpAndSettle();

    expect(find.text('Pro版で利用できます'), findsOneWidget);
    expect(find.textContaining('・1日何度でも受験可能'), findsOneWidget);
    expect(find.text('Pro版を見る'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
  });

  testWidgets('Freeの2回目の受験を開始せずPro案内を表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isProProvider.overrideWith((ref) => Stream.value(false)),
          mockExamAttemptServiceProvider
              .overrideWithValue(_DeniedAttemptService()),
          mockExamQuestionsProvider
              .overrideWith((ref) => Stream.value(_questions)),
        ],
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('試験を始める'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('exam-question')), findsNothing);
    expect(find.text('Pro版で利用できます'), findsOneWidget);
  });

  testWidgets('回答して不正解だった問題は間違えた問題一覧に表示する',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commonOverrides,
        child: const MaterialApp(home: MockExamScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('試験を始める'));
    await tester.pump();
    await tester.tap(find.text('不正解1'));
    await tester.pump();
    await tester.tap(find.text('結果を見る'));
    await tester.pump();

    expect(find.byKey(const ValueKey('mock-exam-result')), findsOneWidget);
    expect(find.text('テスト問題'), findsOneWidget);
    expect(find.text('回答した問題は全問正解です！'), findsNothing);
    expect(find.text('0問'), findsNWidgets(2));
    expect(find.text('1問'), findsOneWidget);
  });

  testWidgets('バックグラウンド移行で一時停止する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commonOverrides,
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
