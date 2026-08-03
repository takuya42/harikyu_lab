import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dailyUsageDateKey = 'free_daily_usage_date_v1';
const _dailyQuestionCountKey = 'free_daily_question_count_v1';

/// Applies free usage limits using [isProProvider] as the entitlement source.
///
/// The local store contains only the free user's daily answer count. Pro status
/// is always obtained from `users/{uid}.plan` in Firestore and is never cached.
final usageLimitProvider = AsyncNotifierProvider<UsageLimitService, int>(
  UsageLimitService.new,
);

class UsageLimitService extends AsyncNotifier<int> {
  late SharedPreferences _preferences;
  bool _isPro = false;

  @override
  Future<int> build() async {
    _isPro = await ref.watch(isProProvider.future);
    if (_isPro) return 0;
    _preferences = await ref.watch(sharedPreferencesProvider.future);
    return _readToday();
  }

  int _readToday() {
    final today = _dateKey(DateTime.now());
    if (_preferences.getString(_dailyUsageDateKey) != today) return 0;
    return _preferences.getInt(_dailyQuestionCountKey) ?? 0;
  }

  Future<void> recordAnswer() async {
    if (_isPro) return;
    final today = _dateKey(DateTime.now());
    final count = _readToday() + 1;
    await _preferences.setString(_dailyUsageDateKey, today);
    await _preferences.setInt(_dailyQuestionCountKey, count);
    state = AsyncData(count);
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
