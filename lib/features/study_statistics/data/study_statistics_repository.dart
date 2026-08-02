import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/study_statistics/domain/study_statistics.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class StudyStatisticsRepository {
  Stream<StudyStatistics> watch();
  void startSession();
  Future<void> recordAnswer({required bool isCorrect});
  Future<void> endSession();
  void dispose();
}

/// Stores the learning history used by both the home and history screens.
class LearningHistoryStudyStatisticsRepository
    implements StudyStatisticsRepository {
  LearningHistoryStudyStatisticsRepository(
    this._preferences, {
    String? userId,
    DateTime Function()? now,
  }) : _storagePrefix = userId == null ? 'guest' : 'user_$userId',
       _now = now ?? DateTime.now {
    _load();
  }

  static const _streakKey = 'streak_days';
  static const _lastStudyDateKey = 'last_study_date';
  static const _totalAnsweredKey = 'total_answered';
  static const _correctAnsweredKey = 'correct_answered';
  static const _legacyStreakKey = 'study_streak_days_v1';
  static const _legacyLastStudyDateKey = 'study_last_date_v1';
  static const _legacyTotalAnsweredKey = 'study_total_answered_v1';
  static const _legacyCorrectAnsweredKey = 'study_correct_answered_v1';

  final SharedPreferences _preferences;
  final String _storagePrefix;
  final DateTime Function() _now;
  final _controller = StreamController<StudyStatistics>.broadcast();
  late StudyStatistics _statistics;
  DateTime? _lastStudyDate;

  String _key(String name) => 'study_statistics_v2_${_storagePrefix}_$name';

  void _load() {
    final isGuest = _storagePrefix == 'guest';
    _lastStudyDate = _parseDate(
      _preferences.getString(_key(_lastStudyDateKey)) ??
          (isGuest
              ? _preferences.getString(_legacyLastStudyDateKey)
              : null),
    );
    final savedStreak =
        _preferences.getInt(_key(_streakKey)) ??
        (isGuest ? _preferences.getInt(_legacyStreakKey) : null) ??
        0;
    _statistics = StudyStatistics(
      streakDays: _currentStreak(savedStreak, _now()),
      totalAnswered:
          _preferences.getInt(_key(_totalAnsweredKey)) ??
          (isGuest ? _preferences.getInt(_legacyTotalAnsweredKey) : null) ??
          0,
      correctAnswered:
          _preferences.getInt(_key(_correctAnsweredKey)) ??
          (isGuest ? _preferences.getInt(_legacyCorrectAnsweredKey) : null) ??
          0,
    );
  }

  @override
  Stream<StudyStatistics> watch() async* {
    yield _statistics;
    yield* _controller.stream;
  }

  @override
  void startSession() {
    // Statistics are answer based, so opening a session is not a learning day.
  }

  @override
  Future<void> recordAnswer({required bool isCorrect}) async {
    final now = _now();
    _updateStreak(now);
    _statistics = _statistics.copyWith(
      totalAnswered: _statistics.totalAnswered + 1,
      correctAnswered: _statistics.correctAnswered + (isCorrect ? 1 : 0),
    );
    await _persist();
    _controller.add(_statistics);
  }

  @override
  Future<void> endSession() async {
    // Kept for the question flow API; there is no time-based state to flush.
  }

  void _updateStreak(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = _lastStudyDate;
    if (last == today) return;
    final yesterday = today.subtract(const Duration(days: 1));
    _statistics = _statistics.copyWith(
      streakDays: last == yesterday ? _statistics.streakDays + 1 : 1,
    );
    _lastStudyDate = today;
  }

  Future<void> _persist() async {
    await Future.wait([
      _preferences.setInt(_key(_streakKey), _statistics.streakDays),
      _preferences.setInt(_key(_totalAnsweredKey), _statistics.totalAnswered),
      _preferences.setInt(
        _key(_correctAnsweredKey),
        _statistics.correctAnswered,
      ),
      if (_lastStudyDate case final date?)
        _preferences.setString(_key(_lastStudyDateKey), _dateKey(date)),
    ]);
  }

  int _currentStreak(int savedStreak, DateTime now) {
    final last = _lastStudyDate;
    if (last == null) return 0;
    final today = DateTime(now.year, now.month, now.day);
    return last == today || last == today.subtract(const Duration(days: 1))
        ? savedStreak
        : 0;
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  @override
  void dispose() {
    _controller.close();
  }
}

final studyStatisticsRepositoryProvider =
    FutureProvider<StudyStatisticsRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  final user = await ref.watch(authStateProvider.future);
  final repository = LearningHistoryStudyStatisticsRepository(
    preferences,
    userId: user?.uid,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final studyStatisticsProvider = StreamProvider<StudyStatistics>((ref) async* {
  final repository = await ref.watch(studyStatisticsRepositoryProvider.future);
  yield* repository.watch();
});
