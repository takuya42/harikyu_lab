import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const proProductId = 'harikyu_lab_pro';
const proDisplayPrice = '¥980（税込・買い切り）';
const freeDailyQuestionLimit = 10;
const freeMockExamQuestionLimit = 20;

const _dailyUsageDateKey = 'free_daily_usage_date_v1';
const _dailyQuestionCountKey = 'free_daily_question_count_v1';

/// The persisted entitlement is scoped to a Firebase Authentication user.
class ProPlanRepository {
  ProPlanRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<bool> isPro(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();
    return document.data()?['plan'] == 'pro';
  }

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

class ProAccessState {
  const ProAccessState({
    this.isPro = false,
    this.isLoading = true,
    this.isPurchasing = false,
    this.storeAvailable = true,
    this.product,
    this.message,
  });

  final bool isPro;
  final bool isLoading;
  final bool isPurchasing;
  final bool storeAvailable;
  final ProductDetails? product;
  final String? message;

  ProAccessState copyWith({
    bool? isPro,
    bool? isLoading,
    bool? isPurchasing,
    bool? storeAvailable,
    ProductDetails? product,
    String? message,
  }) => ProAccessState(
    isPro: isPro ?? this.isPro,
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
    final user = await ref.watch(authStateProvider.future);
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchases,
      onError: _handlePurchaseStreamError,
    );
    ref.onDispose(() {
      _restoreTimer?.cancel();
      _purchaseSubscription?.cancel();
    });

    final isPro = user == null
        ? false
        : await ref.watch(proPlanRepositoryProvider).isPro(user.uid);
    final available = await _store.isAvailable();
    if (!available) {
      return ProAccessState(
        isPro: isPro,
        isLoading: false,
        storeAvailable: false,
      );
    }
    final response = await _store.queryProductDetails({proProductId});
    return ProAccessState(
      isPro: isPro,
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
      isPro: granted || current.isPro,
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

final dailyFreeUsageProvider =
    AsyncNotifierProvider<DailyFreeUsageController, int>(
      DailyFreeUsageController.new,
    );

class DailyFreeUsageController extends AsyncNotifier<int> {
  late SharedPreferences _preferences;

  @override
  Future<int> build() async {
    _preferences = await ref.watch(sharedPreferencesProvider.future);
    return _readToday();
  }

  int _readToday() {
    final today = _dateKey(DateTime.now());
    if (_preferences.getString(_dailyUsageDateKey) != today) return 0;
    return _preferences.getInt(_dailyQuestionCountKey) ?? 0;
  }

  Future<void> recordAnswer() async {
    final today = _dateKey(DateTime.now());
    final count = _readToday() + 1;
    await _preferences.setString(_dailyUsageDateKey, today);
    await _preferences.setInt(_dailyQuestionCountKey, count);
    state = AsyncData(count);
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
