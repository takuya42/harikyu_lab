import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/features/pro/data/revenuecat_store.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  final calls = <MethodCall>[];
  var initializationFails = false;
  var returnedProductId = proProductId;

  // Deliberately fake fixture key: all SDK platform calls are intercepted.
  RevenueCatProStore createStore() => RevenueCatProStore(
    configuration: const RevenueCatConfiguration(
      platform: TargetPlatform.iOS,
      iosKey: 'appl_unit_test_fixture',
    ),
  );

  Map<String, Object?> infoJson() => {
    'entitlements': {'all': {}, 'active': {}},
    'allPurchaseDates': {},
    'activeSubscriptions': [],
    'allPurchasedProductIdentifiers': [],
    'nonSubscriptionTransactions': [],
    'firstSeen': '2026-10-21T00:00:00Z',
    'originalAppUserId': r'$RCAnonymousID:fixture',
    'allExpirationDates': {},
    'requestDate': '2026-10-21T00:00:00Z',
  };

  setUp(() {
    calls.clear();
    initializationFails = false;
    returnedProductId = proProductId;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'setupPurchases':
              if (initializationFails) throw PlatformException(code: '10');
              return null;
            case 'getProductInfo':
              return [
                {
                  'identifier': returnedProductId,
                  'description': 'Pro',
                  'title': 'Pro',
                  'price': 980,
                  'priceString': '¥980',
                  'currencyCode': 'JPY',
                  'productCategory': 'NON_SUBSCRIPTION',
                },
              ];
            case 'purchaseProduct':
              return {
                'customerInfo': infoJson(),
                'transaction': {
                  'transactionIdentifier': 'sandbox-fixture',
                  'productIdentifier': proProductId,
                  'purchaseDate': '2026-10-21T00:00:00Z',
                },
              };
            case 'restorePurchases':
            case 'getCustomerInfo':
              return infoJson();
            default:
              fail('Unexpected native SDK call: ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('初期化は匿名ユーザーで一度だけ、決済完了処理もRevenueCatに任せる', () async {
    final store = createStore();
    expect(await Future.wait([store.initialize(), store.initialize()]), [
      true,
      true,
    ]);
    expect(await store.initialize(), isTrue);
    expect(
      calls.where((call) => call.method == 'setupPurchases'),
      hasLength(1),
    );
    final arguments = calls.single.arguments as Map;
    expect(arguments['appUserId'], isNull);
    expect(arguments['purchasesAreCompletedBy'], 'REVENUECAT');
  });

  test('初期化失敗後は再試行できる', () async {
    final store = createStore();
    initializationFails = true;
    expect(await store.initialize(), isFalse);
    initializationFails = false;
    expect(await store.initialize(), isTrue);
  });

  test('API Keyなし、秘密鍵、別プラットフォームのキーではSDKを呼ばない', () async {
    for (final key in ['', 'sk_not_a_public_key', 'goog_wrong_platform']) {
      final store = RevenueCatProStore(
        configuration: RevenueCatConfiguration(
          platform: TargetPlatform.iOS,
          iosKey: key,
        ),
      );
      expect(await store.initialize(), isFalse);
    }
    expect(calls, isEmpty);
    expect(
      const RevenueCatConfiguration(
        platform: TargetPlatform.android,
        androidKey: 'goog_unit_test_fixture',
      ).publicSdkKey,
      'goog_unit_test_fixture',
    );
    expect(
      const RevenueCatConfiguration(
        platform: TargetPlatform.iOS,
        isWeb: true,
        iosKey: 'appl_unit_test_fixture',
      ).publicSdkKey,
      isNull,
    );
  });

  test('既存の商品IDを非サブスクリプションとして取得しSDKで購入・復元する', () async {
    final store = createStore();
    await store.initialize();
    final product = await store.getProProduct();
    expect(product!.identifier, 'harikyu_lab_pro');
    final query = calls.singleWhere((call) => call.method == 'getProductInfo');
    expect(query.arguments, {
      'productIdentifiers': ['harikyu_lab_pro'],
      'type': 'nonSubscription',
    });
    await store.purchase(product);
    final purchase = calls.singleWhere(
      (call) => call.method == 'purchaseProduct',
    );
    expect((purchase.arguments as Map)['productIdentifier'], 'harikyu_lab_pro');
    await store.restorePurchases();
    expect(
      calls.where((call) => call.method == 'restorePurchases'),
      hasLength(1),
    );
  });

  test('別の商品IDが返っても代替購入しない', () async {
    final store = createStore();
    await store.initialize();
    returnedProductId = 'different-product';
    expect(await store.getProProduct(), isNull);
    const other = StoreProduct('other', 'Other', 'Other', 1, '¥1', 'JPY');
    await expectLater(store.purchase(other), throwsArgumentError);
    expect(calls.where((call) => call.method == 'purchaseProduct'), isEmpty);
  });
}
