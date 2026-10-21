import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/providers/shared_preferences_provider.dart';
import 'package:harikyu_lab/core/theme/app_theme.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:harikyu_lab/features/pro/presentation/pro_purchase_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/revenuecat_fakes.dart';

void main() {
  testWidgets('既存Pro利用者にも復元ボタンを表示してRevenueCatへ移行できる', (tester) async {
    SharedPreferences.setMockInitialValues({'pro_entitlement_v1': true});
    final preferences = await SharedPreferences.getInstance();
    final store = FakeProStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          sharedPreferencesProvider.overrideWith((ref) async => preferences),
          proStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProPurchaseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pro版をご利用中です'), findsOneWidget);
    expect(find.text('Pro版を購入'), findsNothing);
    await tester.scrollUntilVisible(find.text('購入を復元'), 250);
    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();
    expect(store.restoreCalls, 1);
    expect(preferences.getBool('pro_entitlement_v1'), isTrue);
    await tester.pumpWidget(const SizedBox());
    await store.updates.close();
  });
}
