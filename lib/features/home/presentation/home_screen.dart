import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';

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
    _StudyItem('間違えた模擬問題', '間違えた問題だけ復習', Icons.replay_outlined, '/wrong-questions'),
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
    final hasProPlan = ref.watch(isProProvider).value ?? false;
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
                      _MembershipBadge(isPro: hasProPlan),
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
                          mainAxisExtent: columns == 1 ? 96 : 108,
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

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isPro ? colors.primary : colors.primaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showMembershipDialog(context, isPro: isPro),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            isPro ? 'PRO' : 'FREE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isPro ? colors.onPrimary : colors.onPrimaryContainer,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showMembershipDialog(
  BuildContext context, {
  required bool isPro,
}) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isPro ? 'Pro会員' : '無料プラン',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isPro) ...[
                      const Text(
                        'ありがとうございます！\n\n'
                        '現在、すべての学習機能をご利用いただけます。',
                      ),
                      const SizedBox(height: 16),
                      const Text('・一問一答：無制限'),
                      const Text('・学習カレンダー：全期間表示'),
                      const Text('・模擬試験：すべて利用可能'),
                      const Text('・今後追加されるPro限定機能も無料で利用できます。'),
                    ] else ...[
                      const Text('・一問一答：1日10問まで'),
                      const Text('・カテゴリ学習が利用できます'),
                      const Text('・学習カレンダーは過去7日間まで表示'),
                      const Text('・模擬試験は20問・20分を1日1回まで'),
                      const SizedBox(height: 24),
                      Text(
                        'Pro版',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('・一問一答が無制限'),
                      const Text('・学習カレンダーを全期間表示'),
                      const Text('・模擬試験をすべて利用可能'),
                      const Text('・今後追加されるPro限定機能を利用可能'),
                    ],
                    const SizedBox(height: 24),
                    if (!isPro) ...[
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          context.push('/pro');
                        },
                        child: const Text('Pro版を見る'),
                      ),
                      const SizedBox(height: 4),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => item.location == '/categories' || item.location == '/favorites'
          ? context.push(item.location)
          : context.go(item.location),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(item.icon, color: colors.primary, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
            size: 28,
          ),
        ],
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
