import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
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
  int _questionIndex = 0;

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

  void _answer(int index, Question question) {
    if (_selectedAnswer != null) return;
    _statisticsRepository.recordAnswer(
      isCorrect: index == question.correctAnswerIndex,
    );
    setState(() => _selectedAnswer = index);
  }

  void _next(int questionCount) => setState(() {
        _questionIndex = (_questionIndex + 1) % questionCount;
        _selectedAnswer = null;
      });

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

  Widget _question(BuildContext context) {
    final questions = ref.watch(questionsProvider);
    return questions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _loadError(context, error),
      data: (items) {
        if (items.isEmpty) return _loadError(context, '問題データが空です。');
        final index = _questionIndex % items.length;
        return _questionList(context, items[index], index, items.length);
      },
    );
  }

  Widget _loadError(BuildContext context, Object error) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          const Text('問題データを取得できませんでした。'),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.invalidate(questionsProvider),
            child: const Text('再試行'),
          ),
        ]),
      );

  Widget _questionList(
    BuildContext context,
    Question question,
    int index,
    int questionCount,
  ) => ListView(
    key: const ValueKey('question'),
    children: [
      Text(
        '問題 ${index + 1} / $questionCount',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        question.text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 24),
      for (var answerIndex = 0;
          answerIndex < question.choices.length;
          answerIndex++) ...[
        AppCard(
          onTap: () => _answer(answerIndex, question),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text('${answerIndex + 1}'),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(question.choices[answerIndex])),
              if (_selectedAnswer == answerIndex)
                Icon(
                  answerIndex == question.correctAnswerIndex
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: answerIndex == question.correctAnswerIndex
                      ? Colors.green
                      : Colors.red,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_selectedAnswer != null) ...[
        const SizedBox(height: 12),
        Text(
          _selectedAnswer == question.correctAnswerIndex
              ? '正解です！'
              : '正解は「${question.choices[question.correctAnswerIndex]}」です。',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (question.explanation.isNotEmpty) ...[
          Text(question.explanation),
          const SizedBox(height: 16),
        ],
        OutlinedButton(
          onPressed: () => _next(questionCount),
          child: const Text('次の問題へ'),
        ),
      ],
    ],
  );
}
