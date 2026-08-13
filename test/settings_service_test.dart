import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/settings/data/settings_service.dart';

void main() {
  test('学習関連のSharedPreferencesキーだけを初期化対象にする', () {
    const learningKeys = [
      'favorite_question_ids_v1',
      'favorite_question_ids_v1_user_123',
      'study_statistics_v2_user_123_total_answered',
      'study_statistics_v2_guest_streak_days',
      'learning_history_v1_user_123',
      'study_calendar_cache_v1',
      'daily_goal_v1',
    ];
    for (final key in learningKeys) {
      expect(SettingsService.isLearningDataPreferenceKey(key), isTrue);
    }

    expect(SettingsService.isLearningDataPreferenceKey('theme_mode'), isFalse);
    expect(
      SettingsService.isLearningDataPreferenceKey('mistake_question_ids_v1'),
      isFalse,
    );
    expect(
      SettingsService.isLearningDataPreferenceKey('question_cache_v1'),
      isFalse,
    );
  });

  test('購入状態と本日の無料回答数は学習データの初期化対象にしない', () {
    expect(
      SettingsService.isLearningDataPreferenceKey('pro_entitlement_v1'),
      isFalse,
    );
    expect(
      SettingsService.isLearningDataPreferenceKey(
        'free_daily_question_count_v1',
      ),
      isFalse,
    );
    expect(
      SettingsService.isLearningDataPreferenceKey('free_daily_usage_date_v1'),
      isFalse,
    );
  });
}
