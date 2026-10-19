import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dailyUsageDateKey = 'free_daily_usage_date_v1';
const _dailyQuestionCountKey = 'free_daily_question_count_v1';
const _dailyUsageKey = 'free_daily_usage_v2';

/// Uses the device's local calendar date, independently of elapsed session time.
final usageClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Applies free usage limits using [isProProvider] as the entitlement source.
///
/// The local store keeps the free user's daily answer count independently from
/// learning data. Pro status may come from App Store purchase state or the
/// signed-in user's existing Firestore plan.
final usageLimitProvider = AsyncNotifierProvider<UsageLimitService, int>(
  UsageLimitService.new,
);

class UsageLimitService extends AsyncNotifier<int> {
  late SharedPreferences _preferences;
  Future<void> _pending = Future.value();

  @override
  Future<int> build() async {
    final isPro = await ref.watch(isProProvider.future);
    _preferences = await ref.watch(sharedPreferencesProvider.future);
    if (isPro) {
      debugPrint('[UsageLimitService] result=0 reason=pro');
      return 0;
    }
    final used = _readToday();
    debugPrint('[UsageLimitService] result=$used reason=free-daily-usage');
    return used;
  }

  int _readToday() {
    final today = _dateKey(ref.read(usageClockProvider)());
    final stored = _preferences.getString(_dailyUsageKey);
    if (stored != null) {
      final usage = jsonDecode(stored) as Map<String, dynamic>;
      return usage['date'] == today ? usage['count'] as int : 0;
    }
    // Preserve answers already recorded by older app versions on this date.
    if (_preferences.getString(_dailyUsageDateKey) != today) return 0;
    return _preferences.getInt(_dailyQuestionCountKey) ?? 0;
  }

  /// Atomically checks and consumes one answer across all answering screens.
  /// Serializing also prevents simultaneous taps from exceeding the allowance.
  Future<bool> tryRecordAnswer() {
    final operation = _pending.then((_) => _tryRecordAnswer());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<bool> _tryRecordAnswer() async {
    final isPro = await ref.read(isProProvider.future);
    if (isPro) {
      debugPrint('[UsageLimitService] recordAnswer skipped reason=pro');
      return true;
    }
    await future;
    final used = _readToday();
    if (used >= freeDailyQuestionLimit) {
      state = AsyncData(used);
      return false;
    }
    final today = _dateKey(ref.read(usageClockProvider)());
    final count = used + 1;
    // One persisted record avoids a partially updated date/count at midnight.
    final saved = await _preferences.setString(
      _dailyUsageKey,
      jsonEncode({'date': today, 'count': count}),
    );
    if (!saved) throw StateError('無料回答回数を保存できませんでした。');
    state = AsyncData(count);
    debugPrint('[UsageLimitService] result=$count reason=answer-recorded');
    return true;
  }

  /// Returns whether the free daily limit has been reached.
  ///
  /// Pro users always return before any free-limit state is inspected.
  Future<bool> hasReachedLimit() async {
    final isPro = await ref.read(isProProvider.future);
    if (isPro) {
      debugPrint('[UsageLimitService] limitReached=false reason=pro');
      return false;
    }
    await future;
    final used = _readToday();
    state = AsyncData(used);
    final reached = used >= freeDailyQuestionLimit;
    debugPrint(
      '[UsageLimitService] limitReached=$reached used=$used '
      'limit=$freeDailyQuestionLimit',
    );
    return reached;
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
