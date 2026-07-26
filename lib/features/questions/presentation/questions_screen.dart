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
  int _questionIndex = 0;
  int? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _statisticsRepository = ref.read(studyStatisticsRepositoryProvider);
  }

  void _start() {
    _statisticsRepository.startSession();
    setState(() {
      _isStudying = true;
      _questionIndex = 0;
      _selectedAnswer = null;
    });
  }

  void _answer(Question question, int index) {
    if (_selectedAnswer != null) return;
    _statisticsRepository.recordAnswer(
      isCorrect: index == question.correctChoiceIndex,
    );
    setState(() => _selectedAnswer = index);
  }

  void _next(int questionCount) {
    setState(() {
      _questionIndex = (_questionIndex + 1) % questionCount;
      _selectedAnswer = null;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(questionsProvider);
    await ref.read(questionsProvider.future);
    if (mounted) {
      setState(() {
        _questionIndex = 0;
        _selectedAnswer = null;
      });
    }
  }

  @override
  void dispose() {
    _statisticsRepository.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(questionsProvider);
    return AppPage(
      title: '一問一答',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: questions.when(
          loading: () => const ListView(
            physics: AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 180),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.cloud_off_rounded, size: 56),
              const SizedBox(height: 16),
              const Text('問題を取得できませんでした', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('下に引っ張って再読み込みしてください。', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('再読み込み'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return const ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 160),
                  Text('問題が登録されていません', textAlign: TextAlign.center),
                ],
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _isStudying
                  ? _question(context, items)
                  : _introduction(context, items.length),
            );
          },
        ),
      ),
    );
  }

  Widget _introduction(BuildContext context, int count) => ListView(
    key: const ValueKey('introduction'),
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 24),
      Icon(Icons.bolt_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 24),
      Text('すきま時間に知識を確認', textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text('$count問の問題を取得しました。\n開始すると学習時間を計測します。', textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 32),
      FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('学習を始める')),
    ],
  );

  Widget _question(BuildContext context, List<Question> questions) {
    final question = questions[_questionIndex % questions.length];
    final correctIndex = question.correctChoiceIndex;
    return ListView(
      key: ValueKey('question-${question.id}'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text('問題 ${_questionIndex + 1} / ${questions.length}　${question.subject}・${question.category}',
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Text(question.question, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (question.image != null) ...[
          const SizedBox(height: 16),
          Image.network(question.image!, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48)),
        ],
        const SizedBox(height: 24),
        for (var index = 0; index < question.choices.length; index++) ...[
          AppCard(
            onTap: () => _answer(question, index),
            child: Row(children: [
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('${index + 1}')),
              const SizedBox(width: 16),
              Expanded(child: Text(question.choices[index])),
              if (_selectedAnswer == index)
                Icon(index == correctIndex ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: index == correctIndex ? Colors.green : Colors.red),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (_selectedAnswer != null) ...[
          const SizedBox(height: 12),
          Text(_selectedAnswer == correctIndex ? '正解です！' : '正解は「${correctIndex >= 0 ? question.choices[correctIndex] : question.answer}」です。',
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(question.explanation),
          ],
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => _next(questions.length), child: const Text('次の問題')),
        ],
      ],
    );
  }
}
