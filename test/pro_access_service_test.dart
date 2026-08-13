import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('未ログインのApp Store購入状態を端末に永続化する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalProEntitlementRepository(preferences);

    expect(repository.isPro, isFalse);
    await repository.grantPro();

    final restored = LocalProEntitlementRepository(
      await SharedPreferences.getInstance(),
    );
    expect(restored.isPro, isTrue);
  });

  test('端末の購入状態またはログイン済みアカウントのplanでProになる', () {
    expect(resolveProEntitlement(local: false, account: false), isFalse);
    expect(resolveProEntitlement(local: true, account: false), isTrue);
    expect(resolveProEntitlement(local: false, account: true), isTrue);
    expect(resolveProEntitlement(local: true, account: true), isTrue);
  });

  test('無料ユーザーの1日の回答上限は20問', () {
    expect(freeDailyQuestionLimit, 20);
  });
}
