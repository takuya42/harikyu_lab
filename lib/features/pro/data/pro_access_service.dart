import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:harikyu_lab/core/providers/firebase_firestore_provider.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/pro/data/revenuecat_store.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

export 'revenuecat_store.dart' show proProductId, proEntitlementId, ProStore;

const proDisplayPrice = '¥980（税込・買い切り）';
const freeDailyQuestionLimit = 5;
const freeMockExamQuestionLimit = 20;
const _localProEntitlementKey = 'pro_entitlement_v1';

/// Stores the App Store entitlement on this device so a purchase also remains
/// available when the user chooses not to create an account.
class LocalProEntitlementRepository {
  LocalProEntitlementRepository(this._preferences);

  final SharedPreferences _preferences;

  bool get isPro => _preferences.getBool(_localProEntitlementKey) ?? false;

  Future<void> grantPro() =>
      _preferences.setBool(_localProEntitlementKey, true);
}

final localProEntitlementRepositoryProvider =
    FutureProvider<LocalProEntitlementRepository>((ref) async {
      return LocalProEntitlementRepository(
        await ref.watch(sharedPreferencesProvider.future),
      );
    });

bool resolveProEntitlement({
  required bool local,
  required bool account,
  bool revenueCat = false,
}) => local || account || revenueCat;

/// The persisted entitlement is scoped to a Firebase Authentication user.
class ProPlanRepository {
  ProPlanRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<bool> watchIsPro(String uid) =>
      _firestore.collection('users').doc(uid).snapshots().map((document) {
        final plan = document.data()?['plan'];
        debugPrint('[ProPlanRepository] Firestore plan=$plan uid=$uid');
        return plan == 'pro';
      });

  /// Only called after RevenueCat confirms an active Pro entitlement for a
  /// purchase or restore. Preserve the existing account migration fallback.
  Future<void> grantPro(String uid, {required DateTime purchasedAt}) =>
      _firestore.collection('users').doc(uid).set({
        'plan': 'pro',
        'purchaseType': 'non_consumable',
        'purchasedAt': Timestamp.fromDate(purchasedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}

final proPlanRepositoryProvider = Provider<ProPlanRepository>(
  (ref) => ProPlanRepository(ref.watch(firebaseFirestoreProvider)),
);

final proStoreProvider = Provider<ProStore>(
  (ref) => RevenueCatProStore.instance,
);

final revenueCatProProvider =
    AsyncNotifierProvider<RevenueCatProController, bool>(
      RevenueCatProController.new,
    );

class RevenueCatProController extends AsyncNotifier<bool> {
  int _customerInfoRevision = 0;
  @override
  Future<bool> build() async {
    final store = ref.watch(proStoreProvider);
    // Register before initialization so a later successful retry (or pending
    // purchase approval) still updates access after an initial SDK failure.
    final subscription = store.customerInfoUpdates.listen(acceptCustomerInfo);
    ref.onDispose(subscription.cancel);
    if (!await store.initialize() || !ref.mounted) return false;
    final revision = _customerInfoRevision;
    try {
      final info = await store.getCustomerInfo();
      if (!ref.mounted) return false;
      return revision == _customerInfoRevision
          ? hasRevenueCatPro(info)
          : state.value ?? false;
    } on Exception {
      // An unavailable SDK must never clear a legacy local/Firestore flag.
      return ref.mounted ? state.value ?? false : false;
    }
  }

  void acceptCustomerInfo(CustomerInfo info) {
    if (ref.mounted) {
      _customerInfoRevision++;
      state = AsyncData(hasRevenueCatPro(info));
    }
  }
}

/// During migration, any of these independent sources unlocks Pro. Never clear
/// legacy flags when RevenueCat is unconfigured, unavailable or has no receipt.
final isProProvider = StreamProvider<bool>((ref) async* {
  final revenueCatIsPro = ref.watch(revenueCatProProvider).value ?? false;
  final auth = ref.watch(authStateProvider);
  final localFuture = ref.watch(localProEntitlementRepositoryProvider.future);
  final localRepository = await localFuture;
  if (!ref.mounted) return;
  final localIsPro = localRepository.isPro;
  final deviceIsPro = localIsPro || revenueCatIsPro;
  if (deviceIsPro) {
    yield true;
    return;
  }
  if (auth.hasError) {
    Error.throwWithStackTrace(auth.error!, auth.stackTrace!);
  }
  // Wait for the auth provider to rebuild us instead of creating an orphaned
  // auth Future when a RevenueCat update already grants access.
  if (!auth.hasValue) return;
  final user = auth.value;
  if (user == null) {
    yield deviceIsPro;
    return;
  }
  // Do not briefly emit free for a legacy account before its plan is loaded.
  await for (final accountIsPro
      in ref.watch(proPlanRepositoryProvider).watchIsPro(user.uid)) {
    yield resolveProEntitlement(
      local: localIsPro,
      account: accountIsPro,
      revenueCat: revenueCatIsPro,
    );
  }
});

class ProAccessState {
  const ProAccessState({
    this.isLoading = true,
    this.isPurchasing = false,
    this.storeAvailable = true,
    this.product,
    this.message,
  });

  final bool isLoading;
  final bool isPurchasing;
  final bool storeAvailable;
  final StoreProduct? product;
  final String? message;

  ProAccessState copyWith({
    bool? isLoading,
    bool? isPurchasing,
    bool? storeAvailable,
    StoreProduct? product,
    String? message,
  }) => ProAccessState(
    isLoading: isLoading ?? this.isLoading,
    isPurchasing: isPurchasing ?? this.isPurchasing,
    storeAvailable: storeAvailable ?? this.storeAvailable,
    product: product ?? this.product,
    message: message,
  );
}

final proAccessProvider =
    AsyncNotifierProvider<ProAccessController, ProAccessState>(
      ProAccessController.new,
    );

class ProAccessController extends AsyncNotifier<ProAccessState> {
  @override
  Future<ProAccessState> build() async {
    final store = ref.watch(proStoreProvider);
    ref.listen(authStateProvider, (_, _) {});
    // Keep RevenueCat customer updates active while the purchase UI is open.
    ref.read(revenueCatProProvider);
    if (!await store.initialize()) {
      return const ProAccessState(
        isLoading: false,
        storeAvailable: false,
        message: '現在購入サービスを利用できません。時間をおいて再度お試しください。',
      );
    }
    try {
      final product = await store.getProProduct();
      return ProAccessState(
        isLoading: false,
        product: product,
        message: product == null ? 'Pro商品を取得できませんでした。購入の復元は利用できます。' : null,
      );
    } on Exception {
      // A product lookup failure must not prevent legacy purchase restoration.
      return const ProAccessState(
        isLoading: false,
        message: '商品を取得できませんでした。購入の復元は利用できます。',
      );
    }
  }

  Future<void> purchase() async {
    final current = state.value;
    final product = current?.product;
    if (product == null || current?.isPurchasing == true) return;
    state = AsyncData(current!.copyWith(isPurchasing: true));
    try {
      final info = await ref.read(proStoreProvider).purchase(product);
      if (!ref.mounted) return;
      await _acceptPurchase(info, restored: false);
    } on PlatformException catch (error) {
      // Platform/channel failures may use non-numeric codes.
      final code = int.tryParse(error.code);
      _finish(
        code == PurchasesErrorCode.purchaseCancelledError.index
            ? '購入をキャンセルしました。'
            : code == PurchasesErrorCode.paymentPendingError.index
            ? '購入の承認を待っています。承認後に購入情報が更新されます。'
            : '購入を完了できませんでした。購入済みの場合は「購入を復元」をお試しください。',
      );
    } on Exception {
      _finish('購入情報を確認できませんでした。「購入を復元」をお試しください。');
    }
  }

  Future<void> restore() async {
    final current = state.value;
    if (current == null || current.isPurchasing) return;
    state = AsyncData(current.copyWith(isPurchasing: true));
    try {
      final store = ref.read(proStoreProvider);
      if (!await store.initialize()) {
        _finish('現在購入サービスを利用できません。時間をおいて再度お試しください。');
        return;
      }
      final info = await store.restorePurchases();
      await _acceptPurchase(info, restored: true);
    } on Exception {
      _finish('購入情報を復元できませんでした。既存のPro状態は維持されます。');
    }
  }

  Future<void> _acceptPurchase(
    CustomerInfo info, {
    required bool restored,
  }) async {
    if (!ref.mounted) return;
    ref.read(revenueCatProProvider.notifier).acceptCustomerInfo(info);
    if (!hasRevenueCatPro(info)) {
      _finish(
        restored
            ? '復元できるPro購入情報を確認できませんでした。既存のPro状態は維持されます。'
            : '購入後のPro情報を確認できませんでした。「購入を復元」をお試しください。',
      );
      return;
    }
    // Preserve the previous lifetime-purchase persistence and account sync.
    // Never grant Pro solely from a transaction or an unrelated entitlement.
    final localRepository = await ref.read(
      localProEntitlementRepositoryProvider.future,
    );
    await localRepository.grantPro();
    if (!ref.mounted) return;
    ref.invalidate(isProProvider);
    try {
      // Account sync is optional: never wait for authentication to purchase.
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final purchasedAt =
            DateTime.tryParse(
              info.entitlements.active[proEntitlementId]!.latestPurchaseDate,
            ) ??
            DateTime.now();
        await ref
            .read(proPlanRepositoryProvider)
            .grantPro(user.uid, purchasedAt: purchasedAt);
      }
    } on Exception {
      // Firebase is optional for purchase: entitlement and local access survive.
      debugPrint(
        '[ProAccessController] Account plan sync failed; Pro is retained.',
      );
    }
    _finish(restored ? 'Proの購入を復元しました。' : 'ご購入ありがとうございます。Pro機能を解放しました。');
  }

  void _finish(String message) {
    if (!ref.mounted) return;
    final current = state.value ?? const ProAccessState();
    state = AsyncData(current.copyWith(isPurchasing: false, message: message));
  }
}
