import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/study_statistics/domain/study_statistics.dart';

abstract interface class StudyStatisticsRepository {
  Stream<StudyStatistics> watch();
  void startSession();
  void recordAnswer({required bool isCorrect});
  void endSession();
}

/// Keeps the current learning history as the single source of truth.
///
/// The repository boundary makes it possible to replace this implementation
/// with Firestore without coupling either the question or home UI to storage.
class LearningHistoryStudyStatisticsRepository
    implements StudyStatisticsRepository {
  final _controller = StreamController<StudyStatistics>.broadcast();
  StudyStatistics _statistics = const StudyStatistics();
  DateTime? _sessionStartedAt;
  DateTime? _lastStudyDate;
  Duration _todayDuration = Duration.zero;
  Timer? _timer;

  @override
  Stream<StudyStatistics> watch() async* {
    yield _statistics;
    yield* _controller.stream;
  }

  @override
  void startSession() {
    if (_sessionStartedAt != null) return;
    _sessionStartedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _publishTime());
  }

  @override
  void recordAnswer({required bool isCorrect}) {
    _updateStreak(DateTime.now());
    _publishTime();
    _statistics = _statistics.copyWith(
      totalAnswered: _statistics.totalAnswered + 1,
      correctAnswered: _statistics.correctAnswered + (isCorrect ? 1 : 0),
    );
    _controller.add(_statistics);
  }

  @override
  void endSession() {
    _publishTime();
    _sessionStartedAt = null;
    _timer?.cancel();
    _timer = null;
  }

  void _publishTime() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) return;
    final now = DateTime.now();
    _todayDuration += now.difference(startedAt);
    _sessionStartedAt = now;
    _statistics = _statistics.copyWith(
      todayStudyMinutes: _todayDuration.inMinutes,
    );
    _controller.add(_statistics);
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
}

final studyStatisticsRepositoryProvider = Provider<StudyStatisticsRepository>(
  (ref) => LearningHistoryStudyStatisticsRepository(),
);

final studyStatisticsProvider = StreamProvider<StudyStatistics>(
  (ref) => ref.watch(studyStatisticsRepositoryProvider).watch(),
);
