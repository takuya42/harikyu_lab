import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';

class ProPurchaseScreen extends ConsumerWidget {
  const ProPurchaseScreen({super.key});

  static const _features = [
    '一問一答 無制限',
    '全カテゴリ解放',
    '模擬試験 無制限',
    '詳細な学習分析',
    '今後追加されるPro機能',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proAccessProvider).value;
    final hasProPlan = ref.watch(userPlanProvider).value == 'pro';
    ref.listen(proAccessProvider, (_, next) {
      final message = next.value?.message;
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });
    final busy = state?.isLoading == true || state?.isPurchasing == true;
    return AppPage(
      title: 'Pro',
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            hasProPlan ? 'Pro版をご利用中です' : '学びを、もっと自由に。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                for (final feature in _features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(child: Text(feature)),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            proDisplayPrice,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            '一度の購入で、すべてのPro機能をご利用いただけます。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text('追加料金は発生しません。', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (!hasProPlan)
            FilledButton.icon(
              onPressed: busy || state?.product == null
                  ? null
                  : () => ref.read(proAccessProvider.notifier).purchase(),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: const Text('Pro版を購入'),
            ),
          if (!hasProPlan && state?.storeAvailable == false) ...[
            const SizedBox(height: 10),
            const Text('現在ストアに接続できません。', textAlign: TextAlign.center),
          ],
          if (!hasProPlan)
            TextButton(
              onPressed: busy
                  ? null
                  : () => ref.read(proAccessProvider.notifier).restore(),
              child: const Text('購入を復元'),
            ),
          const SizedBox(height: 12),
          Text(
            '商品ID: $proProductId',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
