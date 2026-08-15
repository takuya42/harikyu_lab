import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/firebase_firestore_provider.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const proProductId = 'harikyu_lab_pro';
const proDisplayPrice = '¥980（税込・買い切り）';
const freeDailyQuestionLimit = 20;
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

bool resolveProEntitlement({required bool local, required bool account}) =>
    local || account;

/// The persisted entitlement is scoped to a Firebase Authentication user.
class ProPlanRepository {
  ProPlanRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<bool> watchIsPro(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((document) {
        final plan = document.data()?['plan'];
        debugPrint('[ProPlanRepository] Firestore plan=$plan uid=$uid');
        return plan == 'pro';
      });

  /// This method is only called for a StoreKit purchase delivered by the
  /// in_app_purchase purchase stream.
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

/// The current plan combines the device's App Store entitlement with the
/// signed-in account's existing Firestore plan. Either source unlocks Pro.
final isProProvider = StreamProvider<bool>((ref) async* {
  final localRepository = await ref.watch(
    localProEntitlementRepositoryProvider.future,
  );
  final localIsPro = localRepository.isPro;
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    debugPrint('[isProProvider] value=$localIsPro (signed out)');
    yield localIsPro;
    return;
  }
  yield localIsPro;
  await for (final accountIsPro
      in ref.watch(proPlanRepositoryProvider).watchIsPro(user.uid)) {
    final isPro = resolveProEntitlement(
      local: localIsPro,
      account: accountIsPro,
    );
    debugPrint('[isProProvider] value=$isPro');
    yield isPro;
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
  final ProductDetails? product;
  final String? message;

  ProAccessState copyWith({
    bool? isLoading,
    bool? isPurchasing,
    bool? storeAvailable,
    ProductDetails? product,
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

/// StoreKit boundary kept independent from Firebase Authentication. This also
/// makes it possible to verify that guest purchase and restore actions call the
/// App Store directly without introducing an account prerequisite.
abstract interface class ProStore {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseProStore implements ProStore {
  InAppPurchaseProStore(this._store);

  final InAppPurchase _store;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) => _store.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _store.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _store.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}

final proStoreProvider = Provider<ProStore>(
  (_) => InAppPurchaseProStore(InAppPurchase.instance),
);

class ProAccessController extends AsyncNotifier<ProAccessState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _restoreTimer;
  late final ProStore _store;

  @override
  Future<ProAccessState> build() async {
    _store = ref.watch(proStoreProvider);
    ref.watch(authStateProvider);
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchases,
      onError: _handlePurchaseStreamError,
    );
    ref.onDispose(() {
      _restoreTimer?.cancel();
      _purchaseSubscription?.cancel();
    });

    final available = await _store.isAvailable();
    if (!available) {
      return const ProAccessState(isLoading: false, storeAvailable: false);
    }
    final response = await _store.queryProductDetails({proProductId});
    return ProAccessState(
      isLoading: false,
      product: response.productDetails.firstOrNull,
      message: response.error?.message,
    );
  }

  Future<void> purchase() async {
    final current = state.value;
    final product = current?.product;
    if (product == null || current?.isPurchasing == true) return;
    state = AsyncData(current!.copyWith(isPurchasing: true));
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        state = AsyncData(
          current.copyWith(message: '購入処理を開始できませんでした。'),
        );
      }
    } on Exception catch (error) {
      state = AsyncData(
        current.copyWith(message: '購入処理を開始できませんでした: $error'),
      );
    }
  }

  Future<void> restore() async {
    final current = state.value;
    if (current == null || current.isPurchasing) return;
    state = AsyncData(current.copyWith(isPurchasing: true));
    try {
      await _store.restorePurchases();
    } on Exception catch (error) {
      state = AsyncData(
        current.copyWith(message: '購入情報を復元できませんでした: $error'),
      );
      return;
    }
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 10), () {
      final latest = state.value;
      if (latest?.isPurchasing == true) {
        state = AsyncData(latest!.copyWith(
          isPurchasing: false,
          message: '復元できる購入情報はありませんでした。',
        ));
      }
    });
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    var granted = false;
    var pending = false;
    String? message;
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) continue;
      try {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await (await ref.read(
            localProEntitlementRepositoryProvider.future,
          )).grantPro();
          ref.invalidate(isProProvider);
          granted = true;

          final user = await ref.read(authStateProvider.future);
          if (user != null) {
            try {
              await ref.read(proPlanRepositoryProvider).grantPro(
                user.uid,
                purchasedAt: _purchaseDate(purchase),
              );
            } on FirebaseException catch (error) {
              debugPrint(
                '[ProAccessController] Failed to sync account plan: '
                '${error.message ?? error.code}',
              );
            }
          }
        } else if (purchase.status == PurchaseStatus.error) {
          message = purchase.error?.message ?? '購入に失敗しました。';
        } else if (purchase.status == PurchaseStatus.canceled) {
          message = '購入をキャンセルしました。';
        } else if (purchase.status == PurchaseStatus.pending) {
          pending = true;
        }
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      } on Exception catch (error) {
        message = '購入は確認できましたが、Pro状態を保存できませんでした: $error';
      }
    }
    if (!pending) _restoreTimer?.cancel();
    final current = state.value ?? const ProAccessState();
    state = AsyncData(current.copyWith(
      isLoading: false,
      isPurchasing: pending,
      message: granted ? 'ご購入ありがとうございます。Pro機能を解放しました。' : message,
    ));
  }

  DateTime _purchaseDate(PurchaseDetails purchase) {
    final milliseconds = int.tryParse(purchase.transactionDate ?? '');
    return milliseconds == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  void _handlePurchaseStreamError(Object error) {
    final current = state.value ?? const ProAccessState();
    state = AsyncData(current.copyWith(
      isLoading: false,
      isPurchasing: false,
      message: '購入情報を確認できませんでした。',
    ));
  }
}
