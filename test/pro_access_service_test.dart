import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/revenuecat_fakes.dart';

class _User implements User {
  @override
  String get uid => 'existing-user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlanRepository implements ProPlanRepository {
  StreamController<bool>? plans;
  String? grantedUid;
  bool syncFails = false;
  @override
  Stream<bool> watchIsPro(String uid) => plans?.stream ?? Stream.value(true);
  @override
  Future<void> grantPro(String uid, {required DateTime purchasedAt}) async {
    if (syncFails) throw Exception('Firestore unavailable');
    grantedUid = uid;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late FakeProStore store;

  ProviderContainer createContainer({User? user, _PlanRepository? plan}) {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        sharedPreferencesProvider.overrideWith((ref) async => preferences),
        proStoreProvider.overrideWithValue(store),
        if (plan != null) proPlanRepositoryProvider.overrideWithValue(plan),
      ],
    );
    container.listen(isProProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = FakeProStore();
    addTearDown(store.updates.close);
  });

  test('未ログインでもRevenueCat購入でProを解放して永続化する', () async {
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).purchase();
    expect(store.purchaseCalls, 1);
    expect(LocalProEntitlementRepository(preferences).isPro, isTrue);
    expect(await container.read(isProProvider.future), isTrue);
  });

  test('既存のApp Store購入を匿名のままRevenueCat経由で復元できる', () async {
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).restore();
    expect(store.restoreCalls, 1);
    expect(await container.read(isProProvider.future), isTrue);
  });

  test('ログイン中の復元は従来どおりFirestoreのPro情報を同期する', () async {
    final plan = _PlanRepository();
    final container = createContainer(user: _User(), plan: plan);
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).restore();
    expect(plan.grantedUid, 'existing-user');
  });

  test('API Key未設定でも既存の端末内Proフラグを維持する', () async {
    await LocalProEntitlementRepository(preferences).grantPro();
    store.available = false;
    final container = createContainer();
    expect(await container.read(isProProvider.future), isTrue);
    expect(
      (await container.read(proAccessProvider.future)).storeAvailable,
      isFalse,
    );
    expect(LocalProEntitlementRepository(preferences).isPro, isTrue);
  });

  test('RevenueCat障害時も既存のFirestore Proを無料として通知しない', () async {
    store.customerInfoError = Exception('offline');
    final plans = StreamController<bool>.broadcast();
    addTearDown(plans.close);
    final plan = _PlanRepository()..plans = plans;
    final container = createContainer(user: _User(), plan: plan);
    final values = <bool>[];
    container.listen(isProProvider, (_, next) {
      if (next.hasValue) values.add(next.requireValue);
    });
    await container.read(revenueCatProProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    plans.add(true);
    expect(await container.read(isProProvider.future), isTrue);
    expect(values, isNot(contains(false)));
  });

  test('端末フラグがなくてもRevenueCat EntitlementだけでProになる', () async {
    store.info = customerInfo(pro: true);
    final container = createContainer();
    await container.read(revenueCatProProvider.future);
    expect(await container.read(isProProvider.future), isTrue);
    expect(LocalProEntitlementRepository(preferences).isPro, isFalse);
  });

  test('CustomerInfo更新が既存のPro判定へ反映される', () async {
    final container = createContainer();
    await container.read(revenueCatProProvider.future);
    expect(await container.read(isProProvider.future), isFalse);
    store.updates.add(customerInfo(pro: true));
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(isProProvider.future), isTrue);
    store.updates.add(customerInfo());
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(isProProvider.future), isFalse);
  });

  test('有効な対象Entitlementのない購入ではProを付与しない', () async {
    store.purchaseInfo = customerInfo(pro: true, entitlement: 'another-plan');
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).purchase();
    expect(LocalProEntitlementRepository(preferences).isPro, isFalse);
    expect(await container.read(isProProvider.future), isFalse);
  });

  test('復元結果にEntitlementがなくても既存Proを削除しない', () async {
    await LocalProEntitlementRepository(preferences).grantPro();
    store.restoreInfo = customerInfo();
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).restore();
    expect(await container.read(isProProvider.future), isTrue);
  });

  test('復元エラーでも既存Proを維持して操作中状態を解除する', () async {
    await LocalProEntitlementRepository(preferences).grantPro();
    store.restoreError = Exception('offline');
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).restore();
    expect(await container.read(isProProvider.future), isTrue);
    expect(
      container.read(proAccessProvider).requireValue.isPurchasing,
      isFalse,
    );
  });

  test('商品取得エラーでも復元できる', () async {
    store.lookupError = Exception('product unavailable');
    final container = createContainer();
    expect((await container.read(proAccessProvider.future)).product, isNull);
    await container.read(proAccessProvider.notifier).restore();
    expect(store.restoreCalls, 1);
    expect(await container.read(isProProvider.future), isTrue);
  });

  test('購入キャンセルでProを付与しない', () async {
    store.purchaseError = PlatformException(code: '1');
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).purchase();
    expect(LocalProEntitlementRepository(preferences).isPro, isFalse);
    expect(
      container.read(proAccessProvider).requireValue.message,
      '購入をキャンセルしました。',
    );
  });

  test('購入中のCustomerInfo更新で二重購入できる状態に戻さない', () async {
    store.pendingPurchase = Completer();
    final container = createContainer();
    await container.read(proAccessProvider.future);
    final first = container.read(proAccessProvider.notifier).purchase();
    store.updates.add(customerInfo(pro: true));
    await Future<void>.delayed(Duration.zero);
    await container.read(proAccessProvider.notifier).purchase();
    expect(store.purchaseCalls, 1);
    store.pendingPurchase!.complete(customerInfo(pro: true));
    await first;
  });

  test('Firestore同期の失敗で購入と端末のProを失わない', () async {
    final plan = _PlanRepository()..syncFails = true;
    final container = createContainer(user: _User(), plan: plan);
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).purchase();
    expect(await container.read(isProProvider.future), isTrue);
    expect(LocalProEntitlementRepository(preferences).isPro, isTrue);
    expect(
      container.read(proAccessProvider).requireValue.isPurchasing,
      isFalse,
    );
  });

  test('数値ではないSDKエラーでも操作中状態を解除する', () async {
    store.purchaseError = PlatformException(code: 'channel-error');
    final container = createContainer();
    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).purchase();
    expect(
      container.read(proAccessProvider).requireValue.isPurchasing,
      isFalse,
    );
    expect(LocalProEntitlementRepository(preferences).isPro, isFalse);
  });

  test('初回取得の古いCustomerInfoで最新のEntitlement更新を上書きしない', () async {
    store.pendingCustomerInfo = Completer();
    final container = createContainer();
    await container.read(proAccessProvider.future);
    store.updates.add(customerInfo(pro: true));
    await Future<void>.delayed(Duration.zero);
    store.pendingCustomerInfo!.complete(customerInfo());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(revenueCatProProvider).requireValue, isTrue);
    expect(await container.read(isProProvider.future), isTrue);
  });

  test('初期化失敗後の再接続で届いたEntitlementも反映される', () async {
    store.available = false;
    final container = createContainer();
    expect(await container.read(revenueCatProProvider.future), isFalse);
    store.available = true;
    store.updates.add(customerInfo(pro: true));
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(isProProvider.future), isTrue);
  });

  test('3種類のPro情報のいずれかがあればPro、全てなければ無料', () {
    for (final local in [false, true]) {
      for (final account in [false, true]) {
        for (final revenueCat in [false, true]) {
          expect(
            resolveProEntitlement(
              local: local,
              account: account,
              revenueCat: revenueCat,
            ),
            local || account || revenueCat,
          );
        }
      }
    }
    expect(freeDailyQuestionLimit, 5);
  });
}
