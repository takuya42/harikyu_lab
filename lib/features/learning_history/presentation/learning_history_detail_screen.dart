import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/theme/app_theme_extension.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';

class LearningHistoryDetailScreen extends StatelessWidget {
  const LearningHistoryDetailScreen({required this.history, super.key});
  final LearningHistory history;

  @override
  Widget build(BuildContext context) {
    final wrong = history.answers.where((answer) => !answer.isCorrect).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('学習履歴の詳細')),
      body: Hero(
        tag: 'history-${history.id}',
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            if (history.type == LearningType.mockExam) ...[_ExamResult(history: history), const SizedBox(height: 16)],
            Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
              _row(context, '学習種類', history.type.label), _row(context, '日時', _date(history.completedAt)), _row(context, '問題数', '${history.questionCount}問'), _row(context, '正解数', '${history.correctCount}問'), _row(context, '不正解数', '${history.incorrectCount}問'), _row(context, '未回答数', '${history.unansweredCount}問'), _row(context, '正答率', '${history.accuracy}%'), _row(context, '回答時間', _duration(history.duration)), _row(context, 'カテゴリー', history.category.isEmpty ? 'すべて' : history.category, last: true),
            ]))),
            const SizedBox(height: 28),
            Text('間違えた問題', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            if (wrong.isEmpty) Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('回答した問題は全問正解です！'))))
            else for (final answer in wrong) ...[Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_line(context, '問題', answer.question), const Divider(height: 26), _line(context, 'あなたの回答', answer.selectedAnswer, color: Theme.of(context).colorScheme.error), const SizedBox(height: 14), _line(context, '正解', answer.correctAnswer, color: Theme.of(context).extension<AppSurfaceTheme>()!.success), if (answer.explanation.isNotEmpty) ...[const Divider(height: 26), _line(context, '解説', answer.explanation)]]))), const SizedBox(height: 16)],
          ])))),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool last = false}) => Column(children: [Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800)))])), if (!last) const Divider(height: 1)]);
  Widget _line(BuildContext context, String label, String value, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? Theme.of(context).colorScheme.primary)), const SizedBox(height: 6), Text(value, style: const TextStyle(height: 1.55, fontWeight: FontWeight.w600))]);
}

class _ExamResult extends StatelessWidget {
  const _ExamResult({required this.history}); final LearningHistory history;
  @override Widget build(BuildContext context) => Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    SizedBox(width: 150, height: 150, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: history.accuracy / 100), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic, builder: (_, value, __) => Stack(alignment: Alignment.center, children: [SizedBox.expand(child: CircularProgressIndicator(value: value, strokeWidth: 12, strokeCap: StrokeCap.round, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest)), Text('${(value * 100).round()}%', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900))]))),
    const SizedBox(height: 20),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [_stat(context, '正解', '${history.correctCount}問'), _stat(context, '不正解', '${history.incorrectCount}問'), _stat(context, '未回答', '${history.unansweredCount}問'), _stat(context, '回答時間', _duration(history.duration))]),
  ])));
  Widget _stat(BuildContext context, String label, String value) => DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .05), borderRadius: BorderRadius.circular(14)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))]));
}

String _duration(Duration value) { final m = value.inMinutes; final s = value.inSeconds.remainder(60); return m > 0 ? '$m分$s秒' : '$s秒'; }
String _date(DateTime date) => '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
