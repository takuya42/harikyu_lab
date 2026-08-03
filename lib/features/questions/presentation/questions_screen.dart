import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/data/favorite_question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/study_session.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:harikyu_lab/features/pro/data/usage_limit_service.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key, this.subject, this.favoritesOnly = false});

  final String? subject;
  final bool favoritesOnly;

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  late final Future<StudyStatisticsRepository> _statisticsRepository;
  bool _isStudying = false;
  bool _isFinished = false;
  int? _selectedAnswer;
  int _questionIndex = 0;
  int _correctCount = 0;
  bool _isAnswering = false;
  List<StudyQuestion>? _sessionQuestions;
  bool _freeLimitReached = false;
  final Map<String, int> _answers = {};
  DateTime? _startedAt;
  DateTime? _lastAnswerRecordedAt;

  @override
  void initState() {
    super.initState();
    _statisticsRepository = ref.read(
      studyStatisticsRepositoryProvider.future,
    );
  }

  Future<void> _start() async {
    final hasProPlan = await ref.read(isProProvider.future);
    debugPrint('[QuestionsScreen] isProProvider=$hasProPlan');
    if (hasProPlan) {
      await _beginStudy();
      return;
    }
    if (widget.subject != null && !hasProPlan) {
      debugPrint(
        '[QuestionsScreen] show free-limit UI reason=category-requires-pro',
      );
      if (mounted) await context.push('/pro');
      return;
    }
    final limitReached = await ref
        .read(usageLimitProvider.notifier)
        .hasReachedLimit();
    debugPrint('[QuestionsScreen] UsageLimitService result=$limitReached');
    if (limitReached) {
      debugPrint(
        '[QuestionsScreen] show free-limit UI reason=daily-limit-reached',
      );
      if (mounted) await context.push('/pro');
      return;
    }
    await _beginStudy();
  }

  Future<void> _beginStudy() async {
    final repository = await _statisticsRepository;
    repository.startSession();
    await ref.read(analyticsServiceProvider).startQuiz(
      quizType: widget.subject == null ? 'quick_quiz' : 'category',
    );
    if (!mounted) return;
    setState(() {
      _isStudying = true;
      _isFinished = false;
      _sessionQuestions = null;
      _freeLimitReached = false;
      _questionIndex = 0;
      _correctCount = 0;
      _selectedAnswer = null;
      _answers.clear();
      _startedAt = DateTime.now();
      _lastAnswerRecordedAt = _startedAt;
    });
  }

  Future<void> _answer(int index, StudyQuestion question) async {
    if (_selectedAnswer != null || _isAnswering) return;
    _isAnswering = true;
    final isCorrect = index == question.correctAnswerIndex;
    final answeredAt = DateTime.now();
    final answerStartedAt = _lastAnswerRecordedAt ?? _startedAt ?? answeredAt;
    try {
      final repository = await _statisticsRepository;
      await repository.recordAnswer(isCorrect: isCorrect);
      await ref.read(analyticsServiceProvider).questionAnswered(
        questionId: question.question.id,
        isCorrect: isCorrect,
      );
      await _recordAnswerInCalendar(
        isCorrect: isCorrect,
        answeredAt: answeredAt,
        duration: answeredAt.difference(answerStartedAt),
      );
      await ref.read(usageLimitProvider.notifier).recordAnswer();
      _lastAnswerRecordedAt = answeredAt;
      if (!mounted) return;
      setState(() {
        _selectedAnswer = index;
        _answers[question.question.id] = index;
        if (isCorrect) _correctCount++;
      });
    } finally {
      _isAnswering = false;
    }
  }

  Future<void> _recordAnswerInCalendar({
    required bool isCorrect,
    required DateTime answeredAt,
    required Duration duration,
  }) => ref.read(studyCalendarRepositoryProvider).recordStudy(
    LearningHistory(
      id: '${answeredAt.microsecondsSinceEpoch}',
      type: widget.subject != null
          ? LearningType.category
          : LearningType.quickQuiz,
      completedAt: answeredAt,
      questionCount: 1,
      correctCount: isCorrect ? 1 : 0,
      unansweredCount: 0,
      duration: duration,
      category: widget.subject ?? '',
      answers: const [],
    ),
  );

  Future<void> _next(int questionCount) async {
    if (_questionIndex == questionCount - 1) {
      final repository = await _statisticsRepository;
      await repository.endSession();
      await _saveHistory();
      await ref.read(analyticsServiceProvider).finishQuiz(
        quizType: widget.subject == null ? 'quick_quiz' : 'category',
        questionCount: questionCount,
        correctCount: _correctCount,
      );
      if (!mounted) return;
      setState(() => _isFinished = true);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedAnswer = null;
    });
  }

  Future<void> _saveHistory() async {
    final questions = _sessionQuestions;
    final startedAt = _startedAt;
    if (questions == null || startedAt == null) return;
    final completedAt = DateTime.now();
    final type = widget.subject != null
        ? LearningType.category
        : LearningType.quickQuiz;
    final history = LearningHistory(
      id: '${completedAt.microsecondsSinceEpoch}',
      type: type,
      completedAt: completedAt,
      questionCount: questions.length,
      correctCount: _correctCount,
      unansweredCount: questions.length - _answers.length,
      duration: completedAt.difference(startedAt),
      category: widget.subject ?? '',
      answers: questions.where((item) => _answers.containsKey(item.question.id)).map((item) {
        final selected = _answers[item.question.id]!;
        return HistoryAnswer(
          question: item.question.text,
          selectedAnswer: item.choices[selected],
          correctAnswer: item.choices[item.correctAnswerIndex],
          explanation: item.question.explanation,
          isCorrect: selected == item.correctAnswerIndex,
        );
      }).toList(),
    );
    final historyRepository = await ref.read(learningHistoryRepositoryProvider.future);
    await historyRepository.save(history);
    _startedAt = null;
    _lastAnswerRecordedAt = null;
  }

  @override
  void dispose() {
    _statisticsRepository.then((repository) => repository.endSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.favoritesOnly ? 'お気に入り' : widget.subject ?? '一問一答',
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _isFinished
              ? _result(context)
              : _isStudying
                  ? _question(context)
                  : _introduction(context),
        ),
      );

  Widget _introduction(BuildContext context) => ListView(
        key: const ValueKey('introduction'),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.bolt_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            widget.favoritesOnly
                ? 'お気に入りをまとめて復習'
                : widget.subject == null
                    ? 'すきま時間に知識を確認'
                    : '${widget.subject}を集中学習',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            '問題と選択肢は、学習を始めるたびにランダムな順番で表示されます。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          if (widget.favoritesOnly &&
              (ref.watch(favoriteQuestionIdsProvider).asData?.value.isEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: const Text('お気に入りはまだありません',
                  textAlign: TextAlign.center),
            )
          else
            FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: const Text('学習を始める')),
        ],
      );

  Widget _question(BuildContext context) {
    final questions = ref.watch(subjectQuestionsProvider(widget.subject));
    return questions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _loadError(error),
      data: (items) {
        final favoriteIds = ref.watch(favoriteQuestionIdsProvider);
        if (widget.favoritesOnly && favoriteIds.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final filteredItems = widget.favoritesOnly
            ? items
                .where((question) =>
                    favoriteIds.asData?.value.contains(question.id) ?? false)
                .toList()
            : items;
        if (_sessionQuestions == null) {
          final proPlan = ref.watch(isProProvider);
          if (proPlan.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (proPlan.hasError) return _loadError(proPlan.error!);
          final hasProPlan = proPlan.requireValue;
          debugPrint('[QuestionsScreen] isProProvider=$hasProPlan');

          // A Pro entitlement must bypass all free-usage reads and UI.
          if (hasProPlan) {
            _sessionQuestions = createStudySession(filteredItems, isPro: true);
          } else {
            final usage = ref.watch(usageLimitProvider);
            if (usage.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (usage.hasError) return _loadError(usage.error!);
            final used = usage.requireValue;
            final limitReached = used >= freeDailyQuestionLimit;
            _freeLimitReached = limitReached;
            debugPrint(
              '[QuestionsScreen] UsageLimitService result=$limitReached '
              'used=$used',
            );
            final remaining = (freeDailyQuestionLimit - used).clamp(
              0,
              freeDailyQuestionLimit,
            );
            _sessionQuestions = createStudySession(
              filteredItems,
              isPro: false,
            ).take(remaining).toList();
          }
        }
        final session = _sessionQuestions!;
        if (session.isEmpty && widget.favoritesOnly) {
          return const Center(child: Text('お気に入りはまだありません'));
        }
        if (session.isEmpty && _freeLimitReached) {
          debugPrint(
            '[QuestionsScreen] show free-limit UI reason=daily-limit-reached',
          );
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('本日の無料分10問を学習しました。'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.push('/pro'), child: const Text('Pro版で続ける')),
          ]));
        }
        return _buildQuestionSession(context);
      },
    );
  }

  Widget _buildQuestionSession(BuildContext context) {
    final session = _sessionQuestions!;
    if (session.isEmpty) {
      return const Center(child: Text('学習できる問題がありません'));
    }
    final question = session[_questionIndex];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _questionList(context, question, _questionIndex, session.length),
    );
  }

  Future<void> _refresh() async {
    try {
      final repository = await ref.read(questionRepositoryProvider.future);
      await repository.refresh();
      ref.invalidate(questionsProvider);
      ref.invalidate(subjectQuestionsProvider(widget.subject));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新できませんでした。キャッシュ済みの問題を表示します。')));
    }
  }

  Widget _loadError(Object error) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          const Text('問題データを取得できませんでした。'),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(subjectQuestionsProvider(widget.subject)),
            child: const Text('再試行'),
          ),
        ]),
      );

  Widget _questionList(BuildContext context, StudyQuestion studyQuestion, int index, int count) {
    final question = studyQuestion.question;
    return ListView(
      key: ValueKey('question-${question.id}'),
      children: [
        Row(children: [
          Expanded(child: Text('問題 ${index + 1} / $count', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))),
          Consumer(builder: (context, ref, _) {
            final isFavorite = ref.watch(favoriteQuestionIdsProvider).asData?.value.contains(question.id) ?? false;
            return IconButton(
              tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
              onPressed: () async {
                final repository = await ref.read(favoriteQuestionRepositoryProvider.future);
                await repository.toggle(question.id);
                await ref.read(analyticsServiceProvider).favoriteChanged(
                  added: !isFavorite,
                );
              },
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              color: isFavorite ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
            );
          }),
        ]),
        const SizedBox(height: 14),
        if (question.subject.isNotEmpty || question.category.isNotEmpty) ...[
          Text([question.subject, question.category].where((value) => value.isNotEmpty).join(' / '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
        ],
        Text(question.text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        if (question.imageUrl.isNotEmpty) ...[
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(question.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          const SizedBox(height: 24),
        ],
        for (var answerIndex = 0; answerIndex < studyQuestion.choices.length; answerIndex++) ...[
          AppCard(
            onTap: () => _answer(answerIndex, studyQuestion),
            child: Row(children: [
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('${answerIndex + 1}')),
              const SizedBox(width: 16),
              Expanded(child: Text(studyQuestion.choices[answerIndex])),
              if (_selectedAnswer == answerIndex)
                Icon(answerIndex == studyQuestion.correctAnswerIndex ? Icons.check_circle_rounded : Icons.cancel_rounded, color: answerIndex == studyQuestion.correctAnswerIndex ? Colors.green : Colors.red),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (_selectedAnswer != null) ...[
          const SizedBox(height: 12),
          Text(
            _selectedAnswer == studyQuestion.correctAnswerIndex ? '正解です！' : '正解は「${studyQuestion.choices[studyQuestion.correctAnswerIndex]}」です。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (question.explanation.isNotEmpty) ...[const SizedBox(height: 16), Text(question.explanation)],
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => _next(count), child: Text(index == count - 1 ? '結果を見る' : '次の問題へ')),
        ],
      ],
    );
  }

  Widget _result(BuildContext context) {
    final total = _sessionQuestions!.length;
    final incorrect = total - _correctCount;
    final accuracy = total == 0 ? 0 : (_correctCount * 100 / total).round();
    return ListView(
      key: const ValueKey('result'),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.emoji_events_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text('学習結果', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        AppCard(child: Column(children: [
          _ResultRow(label: '正答率', value: '$accuracy%'),
          const Divider(),
          _ResultRow(label: '正解数', value: '$_correctCount問'),
          const Divider(),
          _ResultRow(label: '不正解数', value: '$incorrect問'),
        ])),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.replay_rounded), label: const Text('もう一度学習する')),
      ],
    );
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
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      );
}
