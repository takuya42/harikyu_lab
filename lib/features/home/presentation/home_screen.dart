import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _items = <_StudyItem>[
    _StudyItem('一問一答', 'すきま時間に', Icons.bolt_outlined, '/questions'),
    _StudyItem('模擬試験', '本番形式で確認', Icons.timer_outlined, '/mock-exam'),
    _StudyItem('カテゴリ', '分野を集中学習', Icons.grid_view_outlined, '/categories'),
    _StudyItem('お気に入り', '保存問題を復習', Icons.favorite_border, '/favorites'),
    _StudyItem('弱点復習', '間違いを克服', Icons.refresh_outlined, '/mistakes'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(studyCalendarProvider);
      ref.invalidate(dailyGoalProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = ref.watch(homeSummaryProvider);
    final streakDays = ref.watch(studyStreakProvider);
    final goal = ref.watch(dailyGoalProvider).asData?.value ?? defaultDailyGoal;
    final calendar =
        ref.watch(studyCalendarProvider).asData?.value ??
        const <StudyCalendarDay>[];
    final now = DateTime.now();
    final today = calendar
        .where(
          (day) =>
              day.date.year == now.year &&
              day.date.month == now.month &&
              day.date.day == now.day,
        )
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(studyCalendarRepositoryProvider).refresh();
            ref.invalidate(studyCalendarProvider);
            ref.invalidate(dailyGoalProvider);
          },
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
                    ]),
                    const SizedBox(height: 30),
                    Text('今日も、一歩ずつ。', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('合格までの学びを、心地よく続けましょう。', style: TextStyle(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    _Stats(
                      summary: summary,
                      streakDays: streakDays,
                    ),
                    const SizedBox(height: 16),
                    _DailyGoalCard(answered: today?.answeredCount ?? 0, goal: goal),
                    const SizedBox(height: 36),
                    Text('学習メニュー', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth < 420
                          ? 1
                          : constraints.maxWidth < 840
                              ? 2
                              : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 148,
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

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.answered, required this.goal});
  final int answered;
  final int goal;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日の目標',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: answered.toDouble()),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) => Text(
            '${value.round()} / $goal問',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: goal == 0 ? 0 : (answered / goal).clamp(0.0, 1.0).toDouble(),
          borderRadius: BorderRadius.circular(20),
          minHeight: 8,
        ),
      ],
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.summary, required this.streakDays});
  final StudyCalendarSummary summary;
  final int streakDays;
  @override
  Widget build(BuildContext context) {
    final stats = [
      ('総回答数', '${summary.totalAnswered}問', Icons.edit_note_outlined),
      ('正答率', '${summary.accuracy}%', Icons.check_circle_outline),
      (
        '学習時間',
        '${(summary.studySeconds / 60).ceil()}分',
        Icons.schedule_outlined,
      ),
      ('連続', '$streakDays日', Icons.local_fire_department_outlined),
    ];
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

class _StudyCard extends StatelessWidget {
  const _StudyCard({required this.item});
  final _StudyItem item;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => item.location == '/categories'
        ? context.push(item.location)
        : context.go(item.location),
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
