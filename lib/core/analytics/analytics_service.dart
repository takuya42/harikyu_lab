import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>(
  (ref) => FirebaseAnalytics.instance,
);

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.watch(firebaseAnalyticsProvider)),
);

/// The single entry point for product analytics used by the application.
class AnalyticsService {
  const AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> login() => _analytics.logLogin(loginMethod: 'email');

  Future<void> signUp() => _analytics.logSignUp(signUpMethod: 'email');

  Future<void> startQuiz({required String quizType}) => _analytics.logEvent(
    name: 'start_quiz',
    parameters: {'quiz_type': quizType},
  );

  Future<void> finishQuiz({
    required String quizType,
    required int questionCount,
    required int correctCount,
  }) => _analytics.logEvent(
    name: 'finish_quiz',
    parameters: {
      'quiz_type': quizType,
      'question_count': questionCount,
      'correct_count': correctCount,
    },
  );

  Future<void> categorySelected(String category) => _analytics.logEvent(
    name: 'category_selected',
    parameters: {'category': category},
  );

  Future<void> questionAnswered({
    required String questionId,
    required bool isCorrect,
  }) => _analytics.logEvent(
    name: 'question_answered',
    parameters: {'question_id': questionId, 'is_correct': isCorrect ? 1 : 0},
  );

  Future<void> favoriteChanged({required bool added}) =>
      _analytics.logEvent(name: added ? 'favorite_added' : 'favorite_removed');

  Future<void> calendarOpened() =>
      _analytics.logEvent(name: 'calendar_opened');

  Future<void> settingsOpened() =>
      _analytics.logEvent(name: 'settings_opened');
}
