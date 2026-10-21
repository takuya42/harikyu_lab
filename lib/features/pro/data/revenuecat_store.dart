import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Keep the existing App Store non-consumable product identifier unchanged.
const proProductId = 'harikyu_lab_pro';
const proEntitlementId = 'pro';

class RevenueCatConfiguration {
  const RevenueCatConfiguration({
    required this.platform,
    this.isWeb = false,
    this.iosKey = const String.fromEnvironment('REVENUECAT_IOS_PUBLIC_SDK_KEY'),
    this.androidKey = const String.fromEnvironment(
      'REVENUECAT_ANDROID_PUBLIC_SDK_KEY',
    ),
  });

  final TargetPlatform platform;
  final bool isWeb;
  final String iosKey;
  final String androidKey;

  String? get publicSdkKey {
    if (isWeb) return null;
    return switch (platform) {
      TargetPlatform.iOS when iosKey.startsWith('appl_') => iosKey,
      TargetPlatform.android when androidKey.startsWith('goog_') => androidKey,
      _ => null,
    };
  }
}

bool hasRevenueCatPro(CustomerInfo info) =>
    info.entitlements.active[proEntitlementId]?.isActive == true;

/// The store boundary keeps purchase tests independent of native SDK channels.
abstract interface class ProStore {
  Future<bool> initialize();
  Stream<CustomerInfo> get customerInfoUpdates;
  Future<CustomerInfo> getCustomerInfo();
  Future<StoreProduct?> getProProduct();
  Future<CustomerInfo> purchase(StoreProduct product);
  Future<CustomerInfo> restorePurchases();
}

class RevenueCatProStore implements ProStore {
  RevenueCatProStore({RevenueCatConfiguration? configuration})
    : _configuration =
          configuration ??
          RevenueCatConfiguration(
            platform: defaultTargetPlatform,
            isWeb: kIsWeb,
          );

  static final instance = RevenueCatProStore();
  final RevenueCatConfiguration _configuration;
  Future<bool>? _initialization;
  bool _configured = false;

  @override
  Future<bool> initialize() {
    if (_configured) return Future.value(true);
    return _initialization ??= _configure();
  }

  Future<bool> _configure() async {
    final key = _configuration.publicSdkKey;
    if (key == null) return false;
    try {
      // No appUserID: RevenueCat creates and persists an anonymous customer.
      // Firebase sign-in/out must not reset this customer's purchase history.
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
      return true;
    } on Exception {
      // Keep the app and legacy Pro access usable on configuration/network errors.
      debugPrint(
        '[RevenueCat] SDK initialization failed; legacy Pro is retained.',
      );
      return false;
    } finally {
      // Allow a later explicit purchase/restore to retry a failed initialization.
      if (!_configured) _initialization = null;
    }
  }

  @override
  Stream<CustomerInfo> get customerInfoUpdates => Stream.multi((controller) {
    void listener(CustomerInfo info) => controller.add(info);
    Purchases.addCustomerInfoUpdateListener(listener);
    controller.onCancel = () =>
        Purchases.removeCustomerInfoUpdateListener(listener);
  });

  @override
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  @override
  Future<StoreProduct?> getProProduct() async {
    final products = await Purchases.getProducts([
      proProductId,
    ], productCategory: ProductCategory.nonSubscription);
    // Never silently substitute another Dashboard product or a subscription.
    return products
        .where((product) => product.identifier == proProductId)
        .firstOrNull;
  }

  @override
  Future<CustomerInfo> purchase(StoreProduct product) async {
    if (product.identifier != proProductId) {
      throw ArgumentError('Proの商品IDが一致しません。');
    }
    final result = await Purchases.purchase(
      PurchaseParams.storeProduct(product),
    );
    return result.customerInfo;
  }

  @override
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();
}
