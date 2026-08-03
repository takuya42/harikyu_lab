import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';

class LearningHistoryScreen extends ConsumerStatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  ConsumerState<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends ConsumerState<LearningHistoryScreen>
    with WidgetsBindingObserver {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(analyticsServiceProvider).calendarOpened();
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
    ref.watch(authStateProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final days = ref.watch(studyCalendarProvider);
    final dailyGoalValue = ref.watch(dailyGoalProvider);
    final dailyGoal = dailyGoalValue.asData?.value ?? defaultDailyGoal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習カレンダー'),
        actions: [
          IconButton(
            tooltip: '学習目標を設定',
            onPressed: () => _showGoalSettings(dailyGoal),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: user == null
                ? const _LoginRequiredState()
                : days.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _ErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(studyCalendarProvider),
                    ),
                    data: (items) => dailyGoalValue.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _ErrorState(
                        error: error,
                        onRetry: () => ref.invalidate(dailyGoalProvider),
                      ),
                      data: (goal) => _content(items, goal),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<StudyCalendarDay> items, int dailyGoal) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(studyCalendarRepositoryProvider).refresh();
        ref.invalidate(studyCalendarProvider);
        ref.invalidate(dailyGoalProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Entrance(child: _StreakCard(days: calculateStudyStreak(items))),
          const SizedBox(height: 16),
          _Entrance(
            delay: 80,
            child: _CalendarCard(
              month: _month,
              items: items,
              dailyGoal: dailyGoal,
              onPrevious: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              onNext: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              onDayTap: (day) => _showDay(day, items),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'サマリー',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          _Entrance(delay: 160, child: _SummaryGrid(items: items)),
        ],
      ),
    );
  }

  void _showDay(DateTime day, List<StudyCalendarDay> allItems) {
    final item = allItems.where((value) => _sameDay(value.date, day)).firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _DaySheet(day: day, item: item),
    );
  }

  Future<void> _showGoalSettings(int selectedGoal) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: _GoalSheet(selectedGoal: selectedGoal),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      final repository = ref.read(studyCalendarRepositoryProvider);
      await repository.updateDailyGoal(selected);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学習目標を保存できませんでした')),
      );
    }
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department_rounded),
              const SizedBox(width: 8),
              Text('連続学習日数', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: days.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFF0783C),
                    size: 36,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${value.round()}日連続',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF0783C),
                        ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.items,
    required this.dailyGoal,
    required this.onPrevious,
    required this.onNext,
    required this.onDayTap,
  });
  final DateTime month;
  final List<StudyCalendarDay> items;
  final int dailyGoal;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDayTap;
  static const _weekdays = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cells = ((leading + count + 6) ~/ 7) * 7;
    final days = <int, StudyCalendarDay>{
      for (final item in items.where(
        (item) => item.date.year == month.year && item.date.month == month.month,
      ))
        item.date.day: item,
    };
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: onPrevious, tooltip: '前の月', icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
              child: Text('${month.year}年 ${month.month}月', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(onPressed: onNext, tooltip: '次の月', icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          const SizedBox(height: 10),
          Row(children: [for (final day in _weekdays) Expanded(child: Text(day, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium))]),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(animation), child: child),
            ),
            child: GridView.builder(
              key: ValueKey('${month.year}-${month.month}'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
              itemCount: cells,
              itemBuilder: (context, index) {
                final number = index - leading + 1;
                if (number < 1 || number > count) return const SizedBox.shrink();
                final day = DateTime(month.year, month.month, number);
                final record = days[number];
                final answers = record?.answeredCount ?? 0;
                final today = _sameDay(day, DateTime.now());
                final color = record?.goalAchieved ?? false
                    ? const Color(0xFFFFD35A)
                    : answers > 0
                        ? const Color(0xFF69C780)
                        : Theme.of(context).colorScheme.surfaceContainerHighest;
                return Material(
                  color: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                    side: today ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.5) : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onDayTap(day),
                    child: Center(child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 14, runSpacing: 8, alignment: WrapAlignment.center, children: [
            const _Legend(color: Color(0xFFE7E8EB), label: '学習なし'),
            const _Legend(color: Color(0xFF69C780), label: '1問以上回答'),
            _Legend(color: const Color(0xFFFFD35A), label: '目標達成（$dailyGoal問）'),
          ]),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});
  final List<StudyCalendarDay> items;
  @override
  Widget build(BuildContext context) {
    final answers = items.fold(0, (sum, item) => sum + item.answeredCount);
    final correct = items.fold(0, (sum, item) => sum + item.correctCount);
    final minutes = (items.fold(0, (sum, item) => sum + item.studySeconds) / 60).ceil();
    final exams = items.fold(0, (sum, item) => sum + item.examCount);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _SummaryCard(icon: Icon(Icons.menu_book_rounded), label: '総回答数', value: answers, suffix: '問'),
        _SummaryCard(icon: Icon(Icons.track_changes_rounded), label: '正答率', value: answers == 0 ? 0 : (correct * 100 / answers).round(), suffix: '%'),
        _SummaryCard(icon: Icon(Icons.schedule_rounded), label: '学習時間', value: minutes, suffix: '分'),
        _SummaryCard(icon: Icon(Icons.local_fire_department_rounded), label: '模擬試験受験回数', value: exams, suffix: '回'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.suffix});
  final Widget icon;
  final String label;
  final int value;
  final String suffix;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              IconTheme(data: const IconThemeData(size: 20), child: icon),
              const SizedBox(width: 6),
              Expanded(child: Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelLarge)),
            ]),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (_, number, __) => Text('${number.round()}$suffix', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.item});
  final DateTime day;
  final StudyCalendarDay? item;

  @override
  Widget build(BuildContext context) {
    final record = item;
    final answers = record?.answeredCount ?? 0;
    final correct = record?.correctCount ?? 0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.year}年${day.month}月${day.day}日',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(icon: Icons.edit_note_rounded, label: '回答数', value: '$answers問'),
          _DetailRow(
            icon: Icons.gps_fixed_rounded,
            label: '正答率',
            value: '${answers == 0 ? 0 : (correct * 100 / answers).round()}%',
          ),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: '学習時間',
            value: _duration(Duration(seconds: record?.studySeconds ?? 0)),
          ),
          _DetailRow(
            icon: Icons.assignment_rounded,
            label: '模擬試験',
            value: '${record?.examCount ?? 0}回',
          ),
          if (record == null) ...[
            const SizedBox(height: 18),
            const Text('この日の学習記録はありません'),
          ],
        ],
      ),
    );
  }
}

class _GoalSheet extends StatelessWidget {
  const _GoalSheet({required this.selectedGoal});
  final int selectedGoal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学習目標',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        for (final goal in dailyGoalOptions)
          ListTile(
            leading: Icon(
              goal == selectedGoal
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
            ),
            title: Text('$goal問'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onTap: () => Navigator.pop(context, goal),
          ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Icon(icon, size: 22), const SizedBox(width: 12), Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 420 + delay),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 18 * (1 - value)), child: child)),
        child: child,
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 52),
        const SizedBox(height: 16),
        const Text('学習データを読み込めませんでした'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SelectableText(
            calendarErrorMessage(error),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
      ]));
}

class _LoginRequiredState extends StatelessWidget {
  const _LoginRequiredState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('ログインしてください'),
      );
}

String calendarErrorMessage(Object error) => '${error.runtimeType}\n$error';

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) return '$hours時間$minutes分';
  if (minutes > 0) return '$minutes分';
  return '${math.max(0, value.inSeconds)}秒';
}
