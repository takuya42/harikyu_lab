import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProStore implements ProStore {
  final StreamController<List<PurchaseDetails>> purchases =
      StreamController.broadcast();
  var purchaseCalls = 0;
  var restoreCalls = 0;

  final product = ProductDetails(
    id: proProductId,
    title: 'Pro',
    description: 'Pro plan',
    price: '¥980',
    rawPrice: 980,
    currencyCode: 'JPY',
  );

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async =>
      ProductDetailsResponse(productDetails: [product], notFoundIDs: const []);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchaseCalls++;
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}

void main() {
  test('未ログインでも購入をApp Storeへ直接要求する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = _FakeProStore();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
      proStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(() async {
      container.dispose();
      await store.purchases.close();
    });

    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).purchase();

    expect(store.purchaseCalls, 1);
  });

  test('未ログインでも復元をApp Storeへ直接要求する', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = _FakeProStore();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      sharedPreferencesProvider.overrideWith((ref) async => preferences),
      proStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(() async {
      container.dispose();
      await store.purchases.close();
    });

    await container.read(proAccessProvider.future);
    await container.read(proAccessProvider.notifier).restore();

    expect(store.restoreCalls, 1);
  });

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
