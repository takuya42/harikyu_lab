import 'dart:async';

import 'package:harikyu_lab/features/pro/data/revenuecat_store.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

CustomerInfo customerInfo({
  bool pro = false,
  String entitlement = proEntitlementId,
}) {
  final access = EntitlementInfo(
    entitlement,
    true,
    false,
    '2026-10-21T00:00:00Z',
    '2026-10-21T00:00:00Z',
    proProductId,
    true,
  );
  final active = pro ? {entitlement: access} : <String, EntitlementInfo>{};
  return CustomerInfo(
    EntitlementInfos(active, active),
    {},
    [],
    pro ? [proProductId] : [],
    [],
    '2026-10-21T00:00:00Z',
    r'$RCAnonymousID:fixture',
    {},
    '2026-10-21T00:00:00Z',
  );
}

class FakeProStore implements ProStore {
  final updates = StreamController<CustomerInfo>.broadcast();
  bool available = true;
  bool productAvailable = true;
  Exception? lookupError;
  Exception? customerInfoError;
  Exception? purchaseError;
  Exception? restoreError;
  int purchaseCalls = 0;
  int restoreCalls = 0;
  CustomerInfo info = customerInfo();
  CustomerInfo purchaseInfo = customerInfo(pro: true);
  CustomerInfo restoreInfo = customerInfo(pro: true);
  Completer<CustomerInfo>? pendingPurchase;
  Completer<CustomerInfo>? pendingCustomerInfo;

  final product = const StoreProduct(
    proProductId,
    'Pro plan',
    'Pro',
    980,
    '¥980',
    'JPY',
    productCategory: ProductCategory.nonSubscription,
  );

  @override
  Future<bool> initialize() async => available;

  @override
  Stream<CustomerInfo> get customerInfoUpdates => updates.stream;

  @override
  Future<CustomerInfo> getCustomerInfo() async {
    if (customerInfoError != null) throw customerInfoError!;
    return pendingCustomerInfo == null ? info : pendingCustomerInfo!.future;
  }

  @override
  Future<StoreProduct?> getProProduct() async {
    if (lookupError != null) throw lookupError!;
    return productAvailable ? product : null;
  }

  @override
  Future<CustomerInfo> purchase(StoreProduct product) async {
    purchaseCalls++;
    if (purchaseError != null) throw purchaseError!;
    return pendingPurchase == null ? purchaseInfo : pendingPurchase!.future;
  }

  @override
  Future<CustomerInfo> restorePurchases() async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
    return restoreInfo;
  }
}
