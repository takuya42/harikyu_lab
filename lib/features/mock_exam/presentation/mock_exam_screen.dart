import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/domain/study_session.dart';

/// Change this value (for example to 50 or 200) to alter the exam length.
const mockExamQuestionCount = 100;

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key});

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  List<StudyQuestion>? _session;
  List<Question>? _availableQuestions;
  final List<StudyQuestion> _incorrectQuestions = [];
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _index = 0;
  int? _selectedAnswer;
  int _correctCount = 0;
  bool _finished = false;

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _start(List<StudyQuestion> questions) {
    _timer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _session = questions;
      _incorrectQuestions.clear();
      _index = 0;
      _selectedAnswer = null;
      _correctCount = 0;
      _finished = false;
    });
  }

  void _answer(int answer, StudyQuestion question) {
    if (_selectedAnswer != null) return;
    setState(() {
      _selectedAnswer = answer;
      if (answer == question.correctAnswerIndex) {
        _correctCount++;
      } else {
        _incorrectQuestions.add(question);
      }
    });
  }

  void _next() {
    if (_index + 1 == _session!.length) {
      _stopwatch.stop();
      _timer?.cancel();
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selectedAnswer = null;
    });
  }

  String get _elapsed {
    final duration = _stopwatch.elapsed;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: '模擬試験',
        child: _finished
            ? _result()
            : _session == null
                ? _introduction()
                : _question(),
      );

  Widget _introduction() => ref.watch(mockExamQuestionsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _loadError(error),
        data: (questions) {
          if (questions.isEmpty) return _loadError('問題がありません。');
          _availableQuestions = questions;
          final count = questions.length < mockExamQuestionCount
              ? questions.length
              : mockExamQuestionCount;
          return ListView(children: [
            const SizedBox(height: 32),
            Icon(Icons.timer_rounded,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text('本番形式で実力を確認',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('全問題から重複なく$count問を出題します。\n問題と選択肢の順番は毎回変わります。',
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _start(createStudySession(
                questions,
                questionCount: mockExamQuestionCount,
              )),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('試験を始める'),
            ),
          ]);
        },
      );

  Widget _loadError(Object error) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          const Text('模擬試験データを取得できませんでした。'),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.invalidate(mockExamQuestionsProvider),
            child: const Text('再試行'),
          ),
        ]),
      );

  Widget _question() {
    final item = _session![_index];
    return ListView(key: ValueKey(item.question.id), children: [
      Row(children: [
        Expanded(
          child: Text('問題 ${_index + 1} / ${_session!.length}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700)),
        ),
        const Icon(Icons.schedule_rounded, size: 18),
        const SizedBox(width: 4),
        Text(_elapsed),
      ]),
      const SizedBox(height: 20),
      Text(item.question.text,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      for (var answer = 0; answer < item.choices.length; answer++) ...[
        AppCard(
          onTap: () => _answer(answer, item),
          child: Row(children: [
            CircleAvatar(child: Text('${answer + 1}')),
            const SizedBox(width: 16),
            Expanded(child: Text(item.choices[answer])),
            if (_selectedAnswer == answer)
              Icon(
                answer == item.correctAnswerIndex
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: answer == item.correctAnswerIndex
                    ? Colors.green
                    : Colors.red,
              ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (_selectedAnswer != null) ...[
        const SizedBox(height: 8),
        Text(
          _selectedAnswer == item.correctAnswerIndex
              ? '正解です！'
              : '正解は「${item.choices[item.correctAnswerIndex]}」です。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (item.question.explanation.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(item.question.explanation),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _next,
          child: Text(_index + 1 == _session!.length ? '結果を見る' : '次の問題へ'),
        ),
      ],
    ]);
  }

  Widget _result() {
    final total = _session!.length;
    final accuracy = total == 0 ? 0 : (_correctCount * 100 / total).round();
    return ListView(key: const ValueKey('mock-exam-result'), children: [
      const SizedBox(height: 24),
      Icon(Icons.emoji_events_rounded,
          size: 68, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text('模擬試験結果',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      AppCard(
        child: Column(children: [
          _ResultRow(label: '正解数', value: '$_correctCount問'),
          const Divider(),
          _ResultRow(label: '不正解数', value: '${total - _correctCount}問'),
          const Divider(),
          _ResultRow(label: '正答率', value: '$accuracy%'),
          const Divider(),
          _ResultRow(label: '回答時間', value: _elapsed),
        ]),
      ),
      const SizedBox(height: 24),
      Text('間違えた問題',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (_incorrectQuestions.isEmpty)
        const AppCard(child: Center(child: Text('全問正解です！')))
      else
        for (final item in _incorrectQuestions) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.question.text,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('正解：${item.choices[item.correctAnswerIndex]}'),
                if (item.question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.question.explanation),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _start(createStudySession(
          _availableQuestions!,
          questionCount: mockExamQuestionCount,
        )),
        icon: const Icon(Icons.replay_rounded),
        label: const Text('もう一度挑戦'),
      ),
    ]);
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      );
}
