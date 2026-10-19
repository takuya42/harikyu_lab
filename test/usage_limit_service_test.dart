import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:harikyu_lab/features/pro/data/usage_limit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late DateTime now;

  ProviderContainer createContainer({bool isPro = false}) {
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWith((ref) => Stream.value(isPro)),
        sharedPreferencesProvider.overrideWith((ref) async => preferences),
        usageClockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(usageLimitProvider, (_, _) {});
    return container;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 19, 23, 59);
  });

  test('無料回答を5回受け付け、6回目は記録せず拒否する', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    final service = container.read(usageLimitProvider.notifier);
    for (var i = 0; i < 5; i++) {
      expect(await service.tryRecordAnswer(), isTrue);
    }
    expect(await service.tryRecordAnswer(), isFalse);
    expect(await service.hasReachedLimit(), isTrue);
    expect(container.read(usageLimitProvider).requireValue, 5);
  });

  test('同時の回答要求でも合計5回だけ受け付ける', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    final service = container.read(usageLimitProvider.notifier);
    final results = await Future.wait([
      for (var i = 0; i < 10; i++) service.tryRecordAnswer(),
    ]);
    expect(results.where((allowed) => allowed), hasLength(5));
    expect(container.read(usageLimitProvider).requireValue, 5);
  });

  test('再起動後も当日の回数を復元する', () async {
    final first = createContainer();
    await first.read(usageLimitProvider.notifier).tryRecordAnswer();
    await first.read(usageLimitProvider.notifier).tryRecordAnswer();
    first.dispose();
    final restarted = createContainer();
    addTearDown(restarted.dispose);
    expect(await restarted.read(usageLimitProvider.future), 2);
  });

  test('起動したまま日付が変わっても翌日は0回から再開する', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    final service = container.read(usageLimitProvider.notifier);
    for (var i = 0; i < 5; i++) {
      await service.tryRecordAnswer();
    }
    now = DateTime(2026, 10, 20);
    expect(await service.hasReachedLimit(), isFalse);
    expect(container.read(usageLimitProvider).requireValue, 0);
    expect(await service.tryRecordAnswer(), isTrue);
    expect(container.read(usageLimitProvider).requireValue, 1);
  });

  test('Proは無料枠を消費せず5回を超えて回答できる', () async {
    final free = createContainer();
    await free.read(usageLimitProvider.notifier).tryRecordAnswer();
    free.dispose();
    final pro = createContainer(isPro: true);
    final service = pro.read(usageLimitProvider.notifier);
    for (var i = 0; i < 25; i++) {
      expect(await service.tryRecordAnswer(), isTrue);
    }
    expect(await service.hasReachedLimit(), isFalse);
    pro.dispose();
    final restoredFree = createContainer();
    addTearDown(restoredFree.dispose);
    expect(await restoredFree.read(usageLimitProvider.future), 1);
  });

  test('旧バージョンの当日回答回数も引き継ぐ', () async {
    await preferences.setString('free_daily_usage_date_v1', '2026-10-19');
    await preferences.setInt('free_daily_question_count_v1', 4);
    final container = createContainer();
    addTearDown(container.dispose);
    final service = container.read(usageLimitProvider.notifier);
    expect(await service.tryRecordAnswer(), isTrue);
    expect(await service.tryRecordAnswer(), isFalse);
    expect(container.read(usageLimitProvider).requireValue, 5);
  });
}
