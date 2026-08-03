import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const proProductId = 'harikyu_lab_pro';
const proDisplayPrice = '¥980（税込・買い切り）';
const freeDailyQuestionLimit = 10;
const freeMockExamQuestionLimit = 20;

const _proEntitlementKey = 'pro_entitlement_v1';
const _dailyUsageDateKey = 'free_daily_usage_date_v1';
const _dailyQuestionCountKey = 'free_daily_question_count_v1';

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
  late SharedPreferences _preferences;
  final InAppPurchase _store = InAppPurchase.instance;

  @override
  Future<ProAccessState> build() async {
    _preferences = await ref.watch(sharedPreferencesProvider.future);
    _purchaseSubscription ??= _store.purchaseStream.listen(_handlePurchases);
    ref.onDispose(() => _purchaseSubscription?.cancel());

    final entitled = _preferences.getBool(_proEntitlementKey) ?? false;
    final available = await _store.isAvailable();
    if (!available) {
      return ProAccessState(
        isPro: entitled,
        isLoading: false,
        storeAvailable: false,
      );
    }
    final response = await _store.queryProductDetails({proProductId});
    return ProAccessState(
      isPro: entitled,
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
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      state = AsyncData(current.copyWith(message: '購入処理を開始できませんでした。'));
    }
  }

  Future<void> restore() async {
    final current = state.value;
    if (current == null || current.isPurchasing) return;
    state = AsyncData(current.copyWith(isPurchasing: true));
    await _store.restorePurchases();
    final latest = state.value;
    if (latest != null && latest.isPurchasing) {
      state = AsyncData(latest.copyWith(
        isPurchasing: false,
        message: '復元できる購入情報はありませんでした。',
      ));
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    var purchased = false;
    String? message;
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // StoreKit/Play Billing owns the transaction. Server-side receipt
        // validation can be added without changing this entitlement boundary.
        await _preferences.setBool(_proEntitlementKey, true);
        purchased = true;
      } else if (purchase.status == PurchaseStatus.error) {
        message = purchase.error?.message ?? '購入に失敗しました。';
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    final current = state.value ?? const ProAccessState();
    state = AsyncData(current.copyWith(
      isPro: purchased || current.isPro,
      isLoading: false,
      isPurchasing: false,
      message: purchased ? 'ご購入ありがとうございます。Pro機能を解放しました。' : message,
    ));
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
