import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/core/theme/app_theme.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/mock_exam/data/mock_exam_attempt_service.dart';
import 'package:harikyu_lab/features/mock_exam/presentation/mock_exam_screen.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:harikyu_lab/features/pro/data/usage_limit_service.dart';
import 'package:harikyu_lab/features/questions/data/favorite_question_repository.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/data/wrong_question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/presentation/questions_screen.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'test-user';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Analytics extends Fake implements AnalyticsService {
  var answers = 0;
  @override
  Future<void> startQuiz({required String quizType}) async {}
  @override
  Future<void> questionAnswered({
    required String questionId,
    required bool isCorrect,
  }) async {
    answers++;
  }
}

class _Calendar extends Fake implements StudyCalendarRepository {
  @override
  Future<void> recordStudy(LearningHistory history) async {}
}

class _Attempts extends Fake implements MockExamAttemptService {
  @override
  Future<bool> tryStart({required bool isPro}) async => true;
}

class _WrongQuestions extends Fake implements WrongQuestionRepository {
  @override
  Future<void> markCorrect(String questionId) async {}
  @override
  Future<void> markWrong({
    required String questionId,
    required String categoryId,
  }) async {}
}

void main() {
  final questions = List.generate(
    3,
    (i) => Question(
      id: '$i',
      text: 'テスト問題$i',
      choices: const ['答えA', '答えB', '答えC', '答えD'],
      correctAnswerIndex: 0,
    ),
  );
  for (final mode in ['一問一答', 'お気に入り', '間違えた問題', '模試']) {
    testWidgets('$modeでも共通枠の5問目は採点し、6問目は採点せずProへ案内する', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'free_daily_usage_date_v1': '2026-10-19',
        'free_daily_question_count_v1': 4,
      });
      final preferences = await SharedPreferences.getInstance();
      final analytics = _Analytics();
      final statistics = LearningHistoryStudyStatisticsRepository(preferences);
      final screen = mode == '模試'
          ? const MockExamScreen()
          : QuestionsScreen(
              autoStart: true,
              favoritesOnly: mode == 'お気に入り',
              wrongQuestionsOnly: mode == '間違えた問題',
              wrongQuestionIds: questions.map((q) => q.id).toList(),
            );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(
            path: '/pro',
            builder: (_, _) => const Scaffold(body: Text('Pro案内')),
          ),
        ],
      );
      addTearDown(() {
        router.dispose();
        statistics.dispose();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(_Auth()),
            authStateProvider.overrideWith((ref) => Stream.value(_User())),
            isProProvider.overrideWith((ref) => Stream.value(false)),
            sharedPreferencesProvider.overrideWith((ref) async => preferences),
            usageClockProvider.overrideWithValue(() => DateTime(2026, 10, 19)),
            analyticsServiceProvider.overrideWithValue(analytics),
            studyStatisticsRepositoryProvider.overrideWith(
              (ref) async => statistics,
            ),
            studyCalendarRepositoryProvider.overrideWithValue(_Calendar()),
            favoriteQuestionIdsProvider.overrideWith(
              (ref) => Stream.value(questions.map((q) => q.id).toSet()),
            ),
            questionsProvider.overrideWith((ref) => Stream.value(questions)),
            allQuestionsProvider.overrideWith((ref) async => questions),
            mockExamQuestionsProvider.overrideWith(
              (ref) => Stream.value(questions),
            ),
            mockExamAttemptServiceProvider.overrideWithValue(_Attempts()),
            wrongQuestionRepositoryProvider.overrideWithValue(
              _WrongQuestions(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (mode == '模試') {
        await tester.ensureVisible(find.text('試験を始める'));
        await tester.tap(find.text('試験を始める'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('答えA'));
      await tester.tap(find.text('答えA'));
      await tester.pumpAndSettle();
      expect(analytics.answers, 1);
      expect(find.text('正解です！'), findsOneWidget);
      await tester.ensureVisible(find.text('次の問題へ'));
      await tester.tap(find.text('次の問題へ'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('答えA'));
      await tester.tap(find.text('答えA'));
      await tester.pumpAndSettle();
      expect(find.text('Pro案内'), findsOneWidget);
      expect(analytics.answers, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
