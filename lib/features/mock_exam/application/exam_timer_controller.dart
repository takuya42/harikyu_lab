import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExamTimerState {
  const ExamTimerState({
    this.remaining = Duration.zero,
    this.elapsed = Duration.zero,
    this.isRunning = false,
    this.isPaused = false,
    this.hasTimeLimit = false,
    this.isTimeUp = false,
  });

  final Duration remaining;
  final Duration elapsed;
  final bool isRunning;
  final bool isPaused;
  final bool hasTimeLimit;
  final bool isTimeUp;

  ExamTimerState copyWith({
    Duration? remaining,
    Duration? elapsed,
    bool? isRunning,
    bool? isPaused,
    bool? hasTimeLimit,
    bool? isTimeUp,
  }) =>
      ExamTimerState(
        remaining: remaining ?? this.remaining,
        elapsed: elapsed ?? this.elapsed,
        isRunning: isRunning ?? this.isRunning,
        isPaused: isPaused ?? this.isPaused,
        hasTimeLimit: hasTimeLimit ?? this.hasTimeLimit,
        isTimeUp: isTimeUp ?? this.isTimeUp,
      );
}

final examTimerProvider = NotifierProvider<ExamTimerController, ExamTimerState>(
  ExamTimerController.new,
);

class ExamTimerController extends Notifier<ExamTimerState> {
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsedBeforeRun = Duration.zero;
  Duration _limit = Duration.zero;

  @override
  ExamTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    return const ExamTimerState();
  }

  void start(Duration limit) {
    _timer?.cancel();
    _limit = limit;
    _elapsedBeforeRun = Duration.zero;
    _startedAt = DateTime.now();
    state = ExamTimerState(
      remaining: limit,
      hasTimeLimit: limit > Duration.zero,
      isRunning: true,
    );
    _scheduleTick();
  }

  void pause() {
    if (!state.isRunning || state.isPaused) return;
    _updateTime();
    _elapsedBeforeRun = state.elapsed;
    _startedAt = null;
    _timer?.cancel();
    state = state.copyWith(isRunning: false, isPaused: true);
  }

  void resume() {
    if (!state.isPaused || state.isTimeUp) return;
    _startedAt = DateTime.now();
    state = state.copyWith(isRunning: true, isPaused: false);
    _scheduleTick();
  }

  void stop() {
    _updateTime();
    _elapsedBeforeRun = state.elapsed;
    _startedAt = null;
    _timer?.cancel();
    state = state.copyWith(isRunning: false, isPaused: false);
  }

  void _scheduleTick() {
    _timer?.cancel();
    // A one-shot timer only triggers a repaint. The displayed value is always
    // recalculated from wall-clock elapsed time, so delayed callbacks do not
    // accumulate timer drift.
    _timer = Timer(const Duration(milliseconds: 200), () {
      _updateTime();
      if (state.isRunning) _scheduleTick();
    });
  }

  void _updateTime() {
    if (_startedAt == null) return;
    final elapsed = _elapsedBeforeRun + DateTime.now().difference(_startedAt!);
    if (_limit > Duration.zero && elapsed >= _limit) {
      _timer?.cancel();
      _elapsedBeforeRun = _limit;
      _startedAt = null;
      state = state.copyWith(
        remaining: Duration.zero,
        elapsed: _limit,
        isRunning: false,
        isTimeUp: true,
      );
      return;
    }
    state = state.copyWith(
      elapsed: elapsed,
      remaining: _limit > Duration.zero ? _limit - elapsed : Duration.zero,
    );
  }
}
