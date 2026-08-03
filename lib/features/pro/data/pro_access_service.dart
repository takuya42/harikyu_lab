import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const proProductId = 'harikyu_lab_pro';
const proDisplayPrice = '¥980（税込・買い切り）';
const freeDailyQuestionLimit = 10;
const freeMockExamQuestionLimit = 20;

/// The persisted entitlement is scoped to a Firebase Authentication user.
class ProPlanRepository {
  ProPlanRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<bool> watchIsPro(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((document) => document.data()?['plan'] == 'pro');

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
  (ref) => ProPlanRepository(FirebaseFirestore.instance),
);

/// The current plan, read directly from `users/{uid}.plan` in Firestore.
///
/// Missing users, missing/unknown values, and signed-out sessions are treated as
/// free. No entitlement value is cached in local storage or purchase state.
final isProProvider = StreamProvider<bool>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield false;
    return;
  }
  yield* ref.watch(proPlanRepositoryProvider).watchIsPro(user.uid);
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

class ProAccessController extends AsyncNotifier<ProAccessState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _restoreTimer;
  final InAppPurchase _store = InAppPurchase.instance;

  @override
  Future<ProAccessState> build() async {
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
    final user = await ref.read(authStateProvider.future);
    final product = current?.product;
    if (user == null) {
      _updateMessage('購入にはログインが必要です。');
      return;
    }
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
    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      _updateMessage('復元にはログインが必要です。');
      return;
    }
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
          final user = await ref.read(authStateProvider.future);
          if (user == null) {
            message = '購入を反映するにはログインしてください。';
            continue;
          }
          await ref.read(proPlanRepositoryProvider).grantPro(
            user.uid,
            purchasedAt: _purchaseDate(purchase),
          );
          granted = true;
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
      } on FirebaseException catch (error) {
        message = '購入は確認できましたが、Pro状態を保存できませんでした: ${error.message ?? error.code}';
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

  void _updateMessage(String message) {
    final current = state.value ?? const ProAccessState(isLoading: false);
    state = AsyncData(current.copyWith(message: message));
  }
}
