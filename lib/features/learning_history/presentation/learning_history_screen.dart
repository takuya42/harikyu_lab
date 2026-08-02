import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/learning_history/presentation/learning_history_detail_screen.dart';

enum _Period { today, week, all }

class LearningHistoryScreen extends ConsumerStatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  ConsumerState<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends ConsumerState<LearningHistoryScreen> {
  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(learningHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('学習履歴')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: history.when(
              loading: () => const _HistorySkeleton(),
              error: (_, _) => _ErrorState(onRetry: () => ref.invalidate(learningHistoryProvider)),
              data: (items) => RefreshIndicator(
                onRefresh: () async {
                  final repository = await ref.read(learningHistoryRepositoryProvider.future);
                  await repository.refresh();
                },
                child: _body(items),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(List<LearningHistory> allItems) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startWeek = startToday.subtract(Duration(days: now.weekday - 1));
    final items = allItems.where((item) => switch (_period) {
      _Period.today => !item.completedAt.isBefore(startToday),
      _Period.week => !item.completedAt.isBefore(startWeek),
      _Period.all => true,
    }).toList();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList.list(children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Period>(
                segments: const [
                  ButtonSegment(value: _Period.today, label: Text('今日')),
                  ButtonSegment(value: _Period.week, label: Text('今週')),
                  ButtonSegment(value: _Period.all, label: Text('全期間')),
                ],
                selected: {_period},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _period = value.first),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 360),
              child: KeyedSubtree(
                key: ValueKey(_period),
                child: items.isEmpty
                    ? _EmptyState(onPressed: () => context.go('/home'))
                    : _HistoryContent(items: items, allItems: allItems),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.items, required this.allItems});
  final List<LearningHistory> items;
  final List<LearningHistory> allItems;

  @override
  Widget build(BuildContext context) {
    final answers = items.fold(0, (sum, item) => sum + item.answeredCount);
    final correct = items.fold(0, (sum, item) => sum + item.correctCount);
    final seconds = items.fold(0, (sum, item) => sum + item.duration.inSeconds);
    final accuracy = answers == 0 ? 0 : (correct * 100 / answers).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final ratio = constraints.maxWidth < 430 ? 1.42 : 2.1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ratio,
          children: [
            _SummaryCard(icon: Icons.local_fire_department_rounded, label: '連続学習日数', value: _streak(allItems), suffix: '日', color: const Color(0xFFF0783C)),
            _SummaryCard(icon: Icons.menu_book_rounded, label: '総回答数', value: answers, suffix: '問', color: const Color(0xFF3978E8)),
            _SummaryCard(icon: Icons.gps_fixed_rounded, label: '正答率', value: accuracy, suffix: '%', color: const Color(0xFF16A277)),
            _SummaryCard(icon: Icons.schedule_rounded, label: '学習時間', value: (seconds / 60).ceil(), suffix: '分', color: const Color(0xFF8B62C7)),
          ],
        );
      }),
      const SizedBox(height: 28),
      Text('過去7日間', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('回答数', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 14),
      _WeeklyChart(items: allItems),
      const SizedBox(height: 30),
      Text('学習記録', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      for (var index = 0; index < items.length; index++) ...[
        _Entrance(index: index, child: _HistoryCard(item: items[index])),
        const SizedBox(height: 16),
      ],
    ]);
  }

  static int _streak(List<LearningHistory> items) {
    final days = items.map((e) => DateTime(e.completedAt.year, e.completedAt.month, e.completedAt.day)).toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.suffix, required this.color});
  final IconData icon;
  final String label;
  final int value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: .12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [Icon(icon, color: color, size: 22), const Spacer(), Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (_, number, __) => Text('${number.round()}$suffix', maxLines: 1, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        ),
      ]),
    ),
  );
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.items});
  final List<LearningHistory> items;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (index) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - index)));
    final values = days.map((day) => items.where((item) => _sameDay(item.completedAt, day)).fold(0, (sum, item) => sum + item.answeredCount)).toList();
    final maximum = math.max(1, values.reduce(math.max));
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 210,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var index = 0; index < 7; index++) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${values[index]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: values[index] / maximum),
                duration: Duration(milliseconds: 550 + index * 70),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 20,
                  height: 108 * value + 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: values[index] == 0 ? .18 : .85), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              Text(weekdays[days[index].weekday - 1], style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
          ]),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.item});
  final LearningHistory item;
  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = Theme.of(context).colorScheme.primary;
    return Hero(
      tag: 'history-${item.id}',
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: const Duration(milliseconds: 120),
        child: Card(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: .1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(_detailRoute(item)),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: Icon(_typeIcon(item.type), color: color)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.type.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_date(item.completedAt), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 4, children: [Text('${item.answeredCount}問'), Text('正答率 ${item.accuracy}%'), Text(_duration(item.duration))].map((text) => DefaultTextStyle(style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant), child: text)).toList()),
                ])),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 350 + math.min(index, 5) * 80), curve: Curves.easeOutCubic,
    builder: (_, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 18 * (1 - value)), child: child)), child: child,
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: 1, duration: const Duration(milliseconds: 500),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 18), child: Column(children: [
      Container(width: 132, height: 132, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer), child: Icon(Icons.school_rounded, size: 68, color: Theme.of(context).colorScheme.primary)),
      const SizedBox(height: 28),
      Text('まだ学習履歴がありません', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Text('問題を解くとここへ履歴が保存されます。', textAlign: TextAlign.center, style: TextStyle(height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 28),
      FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.play_arrow_rounded), label: const Text('問題を解く')),
    ])),
  );
}

class _HistorySkeleton extends StatefulWidget { const _HistorySkeleton(); @override State<_HistorySkeleton> createState() => _HistorySkeletonState(); }
class _HistorySkeletonState extends State<_HistorySkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _controller, builder: (_, __) {
    final color = Color.lerp(Theme.of(context).colorScheme.surfaceContainer, Theme.of(context).colorScheme.surfaceContainerHighest, _controller.value)!;
    Widget box(double height) => Container(height: height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)));
    return ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16), children: [box(48), const SizedBox(height: 24), Row(children: [Expanded(child: box(126)), const SizedBox(width: 12), Expanded(child: box(126))]), const SizedBox(height: 12), Row(children: [Expanded(child: box(126)), const SizedBox(width: 12), Expanded(child: box(126))]), const SizedBox(height: 28), box(210), const SizedBox(height: 28), box(108), const SizedBox(height: 16), box(108)]);
  });
}

class _ErrorState extends StatelessWidget { const _ErrorState({required this.onRetry}); final VoidCallback onRetry; @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 52), const SizedBox(height: 16), const Text('履歴を読み込めませんでした'), const SizedBox(height: 16), OutlinedButton(onPressed: onRetry, child: const Text('再試行'))])); }

Route<void> _detailRoute(LearningHistory item) => PageRouteBuilder<void>(
  transitionDuration: const Duration(milliseconds: 420), reverseTransitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (_, animation, __) => FadeTransition(opacity: animation, child: LearningHistoryDetailScreen(history: item)),
  transitionsBuilder: (_, animation, __, child) => SlideTransition(position: Tween(begin: const Offset(.08, .03), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child),
);

IconData _typeIcon(LearningType type) => switch (type) { LearningType.quickQuiz => Icons.flash_on_rounded, LearningType.category => Icons.category_rounded, LearningType.mockExam => Icons.assignment_rounded, LearningType.weaknessReview => Icons.psychology_rounded };
String _duration(Duration value) { final m = value.inMinutes; final s = value.inSeconds.remainder(60); return m > 0 ? '$m分$s秒' : '$s秒'; }
String _date(DateTime date) => '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
