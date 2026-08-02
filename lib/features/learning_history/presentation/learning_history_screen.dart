import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';

class LearningHistoryScreen extends ConsumerStatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  ConsumerState<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends ConsumerState<LearningHistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(learningHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('学習カレンダー')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _ErrorState(
                onRetry: () => ref.invalidate(learningHistoryProvider),
              ),
              data: _content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<LearningHistory> items) {
    return RefreshIndicator(
      onRefresh: () async =>
          (await ref.read(learningHistoryRepositoryProvider.future)).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Entrance(child: _StreakCard(days: _streak(items))),
          const SizedBox(height: 16),
          _Entrance(
            delay: 80,
            child: _CalendarCard(
              month: _month,
              items: items,
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

  void _showDay(DateTime day, List<LearningHistory> allItems) {
    final items = allItems.where((item) => _sameDay(item.completedAt, day)).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _DaySheet(day: day, items: items),
    );
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
            Text('🔥 連続学習日数', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: days.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Text(
                '🔥 ${value.round()}日連続',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF0783C),
                    ),
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
    required this.onPrevious,
    required this.onNext,
    required this.onDayTap,
  });
  final DateTime month;
  final List<LearningHistory> items;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDayTap;
  static const _weekdays = ['日', '月', '火', '水', '木', '金', '土'];
  static const _dailyGoal = 10;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cells = ((leading + count + 6) ~/ 7) * 7;
    final totals = <int, int>{};
    for (final item in items.where(
      (item) => item.completedAt.year == month.year && item.completedAt.month == month.month,
    )) {
      totals.update(item.completedAt.day, (value) => value + item.answeredCount,
          ifAbsent: () => item.answeredCount);
    }
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
                final answers = totals[number] ?? 0;
                final today = _sameDay(day, DateTime.now());
                final color = answers >= _dailyGoal
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
          const Wrap(spacing: 14, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _Legend(color: Color(0xFFE7E8EB), label: '学習なし'),
            _Legend(color: Color(0xFF69C780), label: '1問以上回答'),
            _Legend(color: Color(0xFFFFD35A), label: '目標達成（10問）'),
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
  final List<LearningHistory> items;
  @override
  Widget build(BuildContext context) {
    final answers = items.fold(0, (sum, item) => sum + item.answeredCount);
    final correct = items.fold(0, (sum, item) => sum + item.correctCount);
    final minutes = (items.fold(0, (sum, item) => sum + item.duration.inSeconds) / 60).ceil();
    final exams = items.where((item) => item.type == LearningType.mockExam).length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _SummaryCard(label: '📚 総回答数', value: answers, suffix: '問'),
        _SummaryCard(label: '🎯 正答率', value: answers == 0 ? 0 : (correct * 100 / answers).round(), suffix: '%'),
        _SummaryCard(label: '⏱ 学習時間', value: minutes, suffix: '分'),
        _SummaryCard(label: '🏆 模擬試験受験回数', value: exams, suffix: '回'),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.suffix});
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
            Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelLarge),
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
  const _DaySheet({required this.day, required this.items});
  final DateTime day;
  final List<LearningHistory> items;
  @override
  Widget build(BuildContext context) {
    final answers = items.fold(0, (sum, item) => sum + item.answeredCount);
    final correct = items.fold(0, (sum, item) => sum + item.correctCount);
    final duration = Duration(seconds: items.fold(0, (sum, item) => sum + item.duration.inSeconds));
    final exams = items.where((item) => item.type == LearningType.mockExam).toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('${day.year}年${day.month}月${day.day}日', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        _DetailRow(icon: Icons.edit_note_rounded, label: '回答数', value: '$answers問'),
        _DetailRow(icon: Icons.gps_fixed_rounded, label: '正答率', value: '${answers == 0 ? 0 : (correct * 100 / answers).round()}%'),
        _DetailRow(icon: Icons.schedule_rounded, label: '学習時間', value: _duration(duration)),
        const SizedBox(height: 18),
        Text('学習内容', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (items.isEmpty) const Text('この日の学習記録はありません') else
          for (final item in items) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(_typeIcon(item.type), size: 20)),
            title: Text(item.type.label),
            subtitle: Text(item.category.isEmpty ? '${item.answeredCount}問' : '${item.category} ・ ${item.answeredCount}問'),
          ),
        if (exams.isNotEmpty) ...[
          const Divider(height: 28),
          Text('模擬試験結果', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final exam in exams) Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(title: Text('${exam.correctCount} / ${exam.questionCount}問 正解'), trailing: Text('${exam.accuracy}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          ),
        ],
      ]),
    );
  }
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
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 52),
        const SizedBox(height: 16),
        const Text('学習データを読み込めませんでした'),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
      ]));
}

int _streak(List<LearningHistory> items) {
  final days = items.map((item) => DateTime(item.completedAt.year, item.completedAt.month, item.completedAt.day)).toSet();
  var cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day);
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var result = 0;
  while (days.contains(cursor)) {
    result++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return result;
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) return '$hours時間$minutes分';
  if (minutes > 0) return '$minutes分';
  return '${math.max(0, value.inSeconds)}秒';
}

IconData _typeIcon(LearningType type) => switch (type) {
      LearningType.quickQuiz => Icons.flash_on_rounded,
      LearningType.category => Icons.category_rounded,
      LearningType.mockExam => Icons.assignment_rounded,
      LearningType.weaknessReview => Icons.psychology_rounded,
    };
