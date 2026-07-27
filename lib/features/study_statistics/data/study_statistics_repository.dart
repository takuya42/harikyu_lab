import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
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
  LearningHistoryStudyStatisticsRepository(this._preferences) {
    _load();
  }

  static const _todayMinutesKey = 'study_today_minutes_v1';
  static const _todayDateKey = 'study_today_date_v1';
  static const _streakKey = 'study_streak_days_v1';
  static const _lastStudyDateKey = 'study_last_date_v1';
  static const _totalAnsweredKey = 'study_total_answered_v1';
  static const _correctAnsweredKey = 'study_correct_answered_v1';

  final SharedPreferences _preferences;
  final _controller = StreamController<StudyStatistics>.broadcast();
  late StudyStatistics _statistics;
  DateTime? _sessionStartedAt;
  DateTime? _lastStudyDate;
  Duration _todayDuration = Duration.zero;
  Timer? _timer;

  void _load() {
    final now = DateTime.now();
    final today = _dateKey(now);
    final isCurrentDay = _preferences.getString(_todayDateKey) == today;
    _todayDuration = Duration(
      minutes: isCurrentDay ? _preferences.getInt(_todayMinutesKey) ?? 0 : 0,
    );
    _lastStudyDate = _parseDate(_preferences.getString(_lastStudyDateKey));
    _statistics = StudyStatistics(
      todayStudyMinutes: _todayDuration.inMinutes,
      streakDays: _preferences.getInt(_streakKey) ?? 0,
      totalAnswered: _preferences.getInt(_totalAnsweredKey) ?? 0,
      correctAnswered: _preferences.getInt(_correctAnsweredKey) ?? 0,
    );
  }

  @override
  Stream<StudyStatistics> watch() async* {
    yield _statistics;
    yield* _controller.stream;
  }

  @override
  void startSession() {
    if (_sessionStartedAt != null) return;
    _rollOverTodayIfNeeded(DateTime.now());
    _sessionStartedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _publishTime());
  }

  @override
  Future<void> recordAnswer({required bool isCorrect}) async {
    final now = DateTime.now();
    _rollOverTodayIfNeeded(now);
    _updateStreak(now);
    await _publishTime();
    _statistics = _statistics.copyWith(
      totalAnswered: _statistics.totalAnswered + 1,
      correctAnswered: _statistics.correctAnswered + (isCorrect ? 1 : 0),
    );
    await _persist();
    _controller.add(_statistics);
  }

  @override
  Future<void> endSession() async {
    await _publishTime();
    _sessionStartedAt = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _publishTime() async {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) return;
    final now = DateTime.now();
    _rollOverTodayIfNeeded(now);
    _todayDuration += now.difference(startedAt);
    _sessionStartedAt = now;
    _statistics = _statistics.copyWith(
      todayStudyMinutes: _todayDuration.inMinutes,
    );
    await _persist();
    _controller.add(_statistics);
  }

  void _rollOverTodayIfNeeded(DateTime now) {
    if (_preferences.getString(_todayDateKey) == _dateKey(now)) return;
    _todayDuration = Duration.zero;
    _statistics = _statistics.copyWith(todayStudyMinutes: 0);
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
    final now = DateTime.now();
    await Future.wait([
      _preferences.setString(_todayDateKey, _dateKey(now)),
      _preferences.setInt(_todayMinutesKey, _todayDuration.inMinutes),
      _preferences.setInt(_streakKey, _statistics.streakDays),
      _preferences.setInt(_totalAnsweredKey, _statistics.totalAnswered),
      _preferences.setInt(_correctAnsweredKey, _statistics.correctAnswered),
      if (_lastStudyDate case final date?)
        _preferences.setString(_lastStudyDateKey, _dateKey(date)),
    ]);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

final studyStatisticsRepositoryProvider =
    FutureProvider<StudyStatisticsRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  final repository = LearningHistoryStudyStatisticsRepository(preferences);
  ref.onDispose(repository.dispose);
  return repository;
});

final studyStatisticsProvider = StreamProvider<StudyStatistics>((ref) async* {
  final repository = await ref.watch(studyStatisticsRepositoryProvider.future);
  yield* repository.watch();
});
