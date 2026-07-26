import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/data/favorite_question_repository.dart';
import 'package:harikyu_lab/features/questions/data/mistake_question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/study_session.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key, this.subject, this.favoritesOnly = false, this.mistakesOnly = false});

  final String? subject;
  final bool favoritesOnly;
  final bool mistakesOnly;

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  late final StudyStatisticsRepository _statisticsRepository;
  bool _isStudying = false;
  bool _isFinished = false;
  int? _selectedAnswer;
  int _questionIndex = 0;
  int _correctCount = 0;
  List<StudyQuestion>? _sessionQuestions;

  @override
  void initState() {
    super.initState();
    _statisticsRepository = ref.read(studyStatisticsRepositoryProvider);
  }

  void _start() {
    _statisticsRepository.startSession();
    setState(() {
      _isStudying = true;
      _isFinished = false;
      _sessionQuestions = null;
      _questionIndex = 0;
      _correctCount = 0;
      _selectedAnswer = null;
    });
  }

  void _answer(int index, StudyQuestion question) {
    if (_selectedAnswer != null) return;
    final isCorrect = index == question.correctAnswerIndex;
    _statisticsRepository.recordAnswer(isCorrect: isCorrect);
    if (!isCorrect) {
      ref.read(mistakeQuestionRepositoryProvider.future).then(
            (repository) => repository.add(question.question.id),
          );
    }
    setState(() {
      _selectedAnswer = index;
      if (isCorrect) _correctCount++;
    });
  }

  void _next(int questionCount) {
    if (_questionIndex == questionCount - 1) {
      _statisticsRepository.endSession();
      setState(() => _isFinished = true);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedAnswer = null;
    });
  }

  @override
  void dispose() {
    _statisticsRepository.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.mistakesOnly ? '弱点復習' : widget.favoritesOnly ? 'お気に入り' : widget.subject ?? '一問一答',
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
            widget.mistakesOnly
                ? '間違えた問題をまとめて復習'
                : widget.favoritesOnly
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
          if ((widget.favoritesOnly &&
                  (ref.watch(favoriteQuestionIdsProvider).asData?.value.isEmpty ?? false)) ||
              (widget.mistakesOnly &&
                  (ref.watch(mistakeQuestionIdsProvider).asData?.value.isEmpty ?? false)))
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(widget.mistakesOnly ? 'まだ間違えた問題はありません' : 'お気に入りはまだありません',
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
        final mistakeIds = ref.watch(mistakeQuestionIdsProvider);
        if (widget.favoritesOnly && favoriteIds.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.mistakesOnly && mistakeIds.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final filteredItems = widget.mistakesOnly
            ? items.where((question) => mistakeIds.asData?.value.contains(question.id) ?? false).toList()
            : widget.favoritesOnly
            ? items
                .where((question) =>
                    favoriteIds.asData?.value.contains(question.id) ?? false)
                .toList()
            : items;
        if (_sessionQuestions == null) {
          _sessionQuestions = createStudySession(filteredItems);
        }
        final session = _sessionQuestions!;
        if (session.isEmpty && (widget.favoritesOnly || widget.mistakesOnly)) {
          return Center(child: Text(widget.mistakesOnly ? 'まだ間違えた問題はありません' : 'お気に入りはまだありません'));
        }
        if (session.isEmpty) return _loadError('${widget.subject ?? ''}の問題がありません。');
        final question = session[_questionIndex];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _questionList(context, question, _questionIndex, session.length),
        );
      },
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
