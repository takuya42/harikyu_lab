import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _items = <_StudyItem>[
    _StudyItem('過去問', '年度別の問題に挑戦', Icons.menu_book_rounded, '/questions'),
    _StudyItem('一問一答', 'すきま時間で知識を確認', Icons.bolt_rounded, '/questions'),
    _StudyItem('模擬試験', '本番形式で実力をチェック', Icons.timer_rounded, '/mock-exam'),
    _StudyItem('カテゴリ別学習', '分野を選んで集中学習', Icons.grid_view_rounded, '/categories'),
    _StudyItem('お気に入り', '保存した問題を復習', Icons.favorite_rounded, '/favorites'),
    _StudyItem('間違えた問題', '苦手な問題を克服', Icons.replay_rounded, '/mistakes'),
    _StudyItem('学習履歴', 'これまでの成果を確認', Icons.insights_rounded, '/history'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.spa_rounded, color: colors.primary)),
                    const SizedBox(width: 12),
                    Text(AppConstants.appName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 18),
                  Text('今日も国家試験合格に向けて\n学習しましょう', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.45)),
                  const SizedBox(height: 8),
                  Text('あなたのペースで、一歩ずつ。', style: TextStyle(color: colors.onSurfaceVariant)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverGrid.builder(
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .94),
                itemBuilder: (context, index) => _StudyCard(item: _items[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.item});
  final _StudyItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(item.location),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(item.icon, color: colors.primary)),
            const Spacer(),
            Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(item.description, maxLines: 2, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.35)),
          ]),
        ),
      ),
    );
  }
}

class _StudyItem {
  const _StudyItem(this.title, this.description, this.icon, this.location);
  final String title;
  final String description;
  final IconData icon;
  final String location;
}
