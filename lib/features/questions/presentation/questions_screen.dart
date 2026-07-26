import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key});

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  late final StudyStatisticsRepository _statisticsRepository;
  bool _isStudying = false;
  int? _selectedAnswer;

  static const _answers = ['心包経', '肺経', '腎経', '胃経'];
  static const _correctAnswer = 1;

  @override
  void initState() {
    super.initState();
    _statisticsRepository = ref.read(studyStatisticsRepositoryProvider);
  }

  void _start() {
    _statisticsRepository.startSession();
    setState(() {
      _isStudying = true;
      _selectedAnswer = null;
    });
  }

  void _answer(int index) {
    if (_selectedAnswer != null) return;
    _statisticsRepository.recordAnswer(isCorrect: index == _correctAnswer);
    setState(() => _selectedAnswer = index);
  }

  @override
  void dispose() {
    _statisticsRepository.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '一問一答',
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _isStudying ? _question(context) : _introduction(context),
    ),
  );

  Widget _introduction(BuildContext context) => ListView(
    key: const ValueKey('introduction'),
    children: [
      const SizedBox(height: 24),
      Icon(
        Icons.bolt_rounded,
        size: 64,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        'すきま時間に知識を確認',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '開始すると学習時間を計測します。回答結果は学習データへ自動で反映されます。',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 32),
      FilledButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('学習を始める'),
      ),
    ],
  );

  Widget _question(BuildContext context) => ListView(
    key: const ValueKey('question'),
    children: [
      Text(
        '問題 1',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        '十二経脈のうち、手の太陰経はどれか。',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 24),
      for (var index = 0; index < _answers.length; index++) ...[
        AppCard(
          onTap: () => _answer(index),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(_answers[index])),
              if (_selectedAnswer == index)
                Icon(
                  index == _correctAnswer
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: index == _correctAnswer ? Colors.green : Colors.red,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_selectedAnswer != null) ...[
        const SizedBox(height: 12),
        Text(
          _selectedAnswer == _correctAnswer ? '正解です！' : '正解は「肺経」です。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _start, child: const Text('もう一度解く')),
      ],
    ],
  );
}
