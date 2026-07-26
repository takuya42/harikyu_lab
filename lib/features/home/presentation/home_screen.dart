import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/core/theme/app_theme_extension.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _items = <_StudyItem>[
    _StudyItem('過去問', '年度別に挑戦', Icons.menu_book_outlined, '/questions'),
    _StudyItem('一問一答', 'すきま時間に', Icons.bolt_outlined, '/questions'),
    _StudyItem('模擬試験', '本番形式で確認', Icons.timer_outlined, '/mock-exam'),
    _StudyItem('カテゴリ', '分野を集中学習', Icons.grid_view_outlined, '/categories'),
    _StudyItem('お気に入り', '保存問題を復習', Icons.favorite_border, '/favorites'),
    _StudyItem('弱点復習', '間違いを克服', Icons.refresh_outlined, '/mistakes'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
                sliver: SliverToBoxAdapter(child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppConstants.pageMaxWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Hero(tag: 'app-mark', child: Material(color: Colors.transparent, child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(16)),
                        child: Icon(Icons.spa_outlined, color: colors.primary),
                      ))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(AppConstants.appName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text('おはようございます', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                      ])),
                      IconButton.filledTonal(onPressed: () => context.go('/settings'), icon: const Icon(Icons.notifications_none_outlined), tooltip: 'お知らせ'),
                    ]),
                    const SizedBox(height: 30),
                    Text('今日も、一歩ずつ。', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('合格までの学びを、心地よく続けましょう。', style: TextStyle(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    const _Stats(),
                    const SizedBox(height: 18),
                    _NextLesson(onTap: () => context.go('/questions')),
                    const SizedBox(height: 30),
                    Text('学習メニュー', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 3 : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns, mainAxisSpacing: 14, crossAxisSpacing: 14,
                          childAspectRatio: constraints.maxWidth < 380 ? 1.15 : 1.35,
                        ),
                        itemBuilder: (_, index) => _StudyCard(item: _items[index]),
                      );
                    }),
                  ]),
                ))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();
  @override
  Widget build(BuildContext context) {
    final stats = const [('今日', '24分', Icons.schedule_outlined), ('連続', '12日', Icons.local_fire_department_outlined), ('正答率', '82%', Icons.check_circle_outline)];
    return AppCard(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8), child: Row(
      children: [for (var i = 0; i < stats.length; i++) ...[
        Expanded(child: Column(children: [
          Icon(stats[i].$3, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(stats[i].$2, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(stats[i].$1, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        if (i < stats.length - 1) const SizedBox(height: 52, child: VerticalDivider()),
      ]],
    ));
  }
}

class _NextLesson extends StatelessWidget {
  const _NextLesson({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final surface = Theme.of(context).extension<AppSurfaceTheme>()!;
    return AppCard(onTap: onTap, padding: EdgeInsets.zero, child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: surface.subtle, borderRadius: BorderRadius.circular(AppConstants.cardRadius)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('次におすすめ', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('第32回 過去問のつづき', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: TweenAnimationBuilder<double>(tween: Tween(end: .68), duration: AppConstants.standardAnimation, builder: (_, value, __) => LinearProgressIndicator(value: value, minHeight: 7, borderRadius: BorderRadius.circular(8)))), const SizedBox(width: 12), const Text('68%')]),
        ])),
        const SizedBox(width: 18),
        CircleAvatar(radius: 25, backgroundColor: colors.primary, foregroundColor: colors.onPrimary, child: const Icon(Icons.arrow_forward_rounded)),
      ]),
    ));
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.item});
  final _StudyItem item;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => context.go(item.location),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(item.icon, color: Theme.of(context).colorScheme.primary, size: 28),
      const Spacer(),
      Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(item.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );
}

class _StudyItem {
  const _StudyItem(this.title, this.description, this.icon, this.location);
  final String title;
  final String description;
  final IconData icon;
  final String location;
}
