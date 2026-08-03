import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/mock_exam/application/exam_timer_controller.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/domain/study_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/learning_history.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';

const _questionCountPreferenceKey = 'mock_exam_question_count';
const _timeLimitPreferenceKey = 'mock_exam_time_limit_minutes';
const _questionCountOptions = [20, 50, 100, 0];
const _debugTimeLimitValue = 10;
const _timeLimitOptions = [if (kDebugMode) _debugTimeLimitValue, 0, 20, 40, 60, 90];

Duration _timeLimitDuration(int value) => value == _debugTimeLimitValue && kDebugMode
    ? const Duration(seconds: 10)
    : Duration(minutes: value);

String _timeLimitLabel(int value) {
  if (value == _debugTimeLimitValue && kDebugMode) return '10秒（開発用）';
  return value == 0 ? '制限なし' : '$value分';
}

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key});

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen>
    with WidgetsBindingObserver {
  List<StudyQuestion>? _session;
  List<Question>? _availableQuestions;
  final List<StudyQuestion> _incorrectQuestions = [];
  final Map<String, int> _answers = {};
  ProviderSubscription<ExamTimerState>? _timerSubscription;
  int _index = 0;
  int? _selectedAnswer;
  int _correctCount = 0;
  int _answeredCount = 0;
  bool _finished = false;
  bool _starting = false;
  int _questionCount = 20;
  int _timeLimitMinutes = 0;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerSubscription = ref.listenManual(examTimerProvider, (previous, next) {
      if (next.isTimeUp && previous?.isTimeUp != true) _handleTimeUp();
    });
    _restoreSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _session != null && !_finished) {
      ref.read(examTimerProvider.notifier).pause();
    }
  }

  Future<void> _restoreSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final count = preferences.getInt(_questionCountPreferenceKey);
      final limit = preferences.getInt(_timeLimitPreferenceKey);
      if (_questionCountOptions.contains(count)) _questionCount = count!;
      if (_timeLimitOptions.contains(limit)) _timeLimitMinutes = limit!;
    });
  }

  Future<void> _selectQuestionCount(int? value) async {
    if (value == null) return;
    final isPro = ref.read(proAccessProvider).value?.isPro ?? false;
    if (!isPro && value != freeMockExamQuestionLimit) {
      await context.push('/pro');
      return;
    }
    setState(() => _questionCount = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_questionCountPreferenceKey, value);
  }

  Future<void> _selectTimeLimit(int? value) async {
    if (value == null) return;
    setState(() => _timeLimitMinutes = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_timeLimitPreferenceKey, value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerSubscription?.close();
    super.dispose();
  }

  Future<void> _startAnimated(List<Question> questions, int count) async {
    if (_starting) return;
    setState(() => _starting = true);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    _start(createStudySession(questions, questionCount: count));
  }

  void _start(List<StudyQuestion> questions) {
    unawaited(ref.read(analyticsServiceProvider).startQuiz(quizType: 'mock_exam'));
    ref.read(examTimerProvider.notifier).start(_timeLimitDuration(_timeLimitMinutes));
    setState(() {
      _session = questions;
      _incorrectQuestions.clear();
      _answers.clear();
      _index = 0;
      _selectedAnswer = null;
      _correctCount = 0;
      _answeredCount = 0;
      _finished = false;
      _starting = false;
      _startedAt = DateTime.now();
    });
  }

  int _effectiveQuestionCount(int available) {
    final configured = _questionCount == 0 ? available : _questionCount;
    final isPro = ref.read(proAccessProvider).value?.isPro ?? false;
    return isPro ? configured : configured.clamp(0, freeMockExamQuestionLimit);
  }

  void _answer(int answer, StudyQuestion question) {
    if (_selectedAnswer != null || ref.read(examTimerProvider).isPaused) return;
    setState(() {
      _selectedAnswer = answer;
      _answers[question.question.id] = answer;
      _answeredCount++;
      if (answer == question.correctAnswerIndex) {
        _correctCount++;
      } else {
        _incorrectQuestions.add(question);
      }
    });
    unawaited(ref.read(analyticsServiceProvider).questionAnswered(
      questionId: question.question.id,
      isCorrect: answer == question.correctAnswerIndex,
    ));
  }

  Future<void> _next() async {
    if (_index + 1 == _session!.length) {
      await _finishExam();
      return;
    }
    setState(() {
      _index++;
      _selectedAnswer = null;
    });
  }

  Future<void> _finishExam() async {
    if (!mounted || _finished || _session == null) return;
    ref.read(examTimerProvider.notifier).stop();
    setState(() => _finished = true);
    await _saveHistory();
    await ref.read(analyticsServiceProvider).finishQuiz(
      quizType: 'mock_exam',
      questionCount: _session!.length,
      correctCount: _correctCount,
    );
  }

  Future<void> _saveHistory() async {
    final session = _session;
    final startedAt = _startedAt;
    if (session == null || startedAt == null) return;
    _startedAt = null;
    final completedAt = DateTime.now();
    final history = LearningHistory(
      id: '${completedAt.microsecondsSinceEpoch}',
      type: LearningType.mockExam,
      completedAt: completedAt,
      questionCount: session.length,
      correctCount: _correctCount,
      unansweredCount: session.length - _answers.length,
      duration: ref.read(examTimerProvider).elapsed,
      category: '全科目',
      answers: session.where((item) => _answers.containsKey(item.question.id)).map((item) {
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
    final calendarRepository = ref.read(studyCalendarRepositoryProvider);
    await calendarRepository.recordStudy(history);
    final historyRepository = await ref.read(learningHistoryRepositoryProvider.future);
    await historyRepository.save(history);
  }

  Future<void> _handleTimeUp() async {
    if (!mounted || _finished || _session == null) return;
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '時間切れ',
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(animation), child: child),
      ),
      pageBuilder: (_, _, _) => const AlertDialog(
        icon: Icon(Icons.timer_off_rounded, size: 36),
        title: Text('時間切れです', textAlign: TextAlign.center),
      ),
    ).timeout(const Duration(milliseconds: 800), onTimeout: () {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
    await _finishExam();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(examTimerProvider);
    return AppPage(
      title: '模擬試験',
      child: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: _finished
              ? _result()
              : _session == null
                  ? _introduction()
                  : _question(timer),
        ),
        if (timer.isPaused && !_finished) _pauseOverlay(),
      ]),
    );
  }

  Widget _introduction() => ref.watch(mockExamQuestionsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _loadError(error),
        data: (questions) {
          if (questions.isEmpty) return _loadError('問題がありません。');
          _availableQuestions = questions;
          final isPro = ref.watch(proAccessProvider).value?.isPro ?? false;
          final requested = _effectiveQuestionCount(questions.length);
          final count = questions.length < requested ? questions.length : requested;
          return ListView(key: const ValueKey('exam-introduction'), padding: const EdgeInsets.only(bottom: 16), children: [
            const SizedBox(height: 18),
            Container(
              width: 76,
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 120),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text('本番形式で実力を確認', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.5)),
            const SizedBox(height: 10),
            Text('全問題から重複なく$count問を出題します。\n問題と選択肢の順番は毎回変わります。', textAlign: TextAlign.center, style: TextStyle(height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 26),
            _ExamSettingsCard(questionCount: isPro ? _questionCount : freeMockExamQuestionLimit, timeLimitMinutes: _timeLimitMinutes, onQuestionCountChanged: _selectQuestionCount, onTimeLimitChanged: _selectTimeLimit),
            if (!isPro) ...[
              const SizedBox(height: 12),
              TextButton.icon(onPressed: () => context.push('/pro'), icon: const Icon(Icons.workspace_premium_outlined), label: const Text('Pro版で模擬試験を無制限に')),
            ],
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _starting ? 0 : 1,
              duration: const Duration(milliseconds: 260),
              child: AnimatedScale(
                scale: _starting ? .96 : 1,
                duration: const Duration(milliseconds: 240),
                child: FilledButton.icon(
                  onPressed: _starting ? null : () => _startAnimated(questions, requested),
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text('試験を始める'),
                ),
              ),
            ),
          ]);
        },
      );

  Widget _loadError(Object error) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 48),
        const SizedBox(height: 16),
        const Text('模擬試験データを取得できませんでした。'),
        const SizedBox(height: 8),
        Text('$error', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => ref.invalidate(mockExamQuestionsProvider), child: const Text('再試行')),
      ]));

  Widget _question(ExamTimerState timer) {
    final item = _session![_index];
    final progress = (_index + 1) / _session!.length;
    return Column(key: const ValueKey('exam-question'), children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => LinearProgressIndicator(value: value, minHeight: 7, borderRadius: BorderRadius.circular(99)),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(99)),
          child: Text('問題 ${_index + 1} / ${_session!.length}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
        ),
        const Spacer(),
        IconButton(key: const ValueKey('pause-exam'), tooltip: '一時停止', onPressed: () => ref.read(examTimerProvider.notifier).pause(), icon: const Icon(Icons.pause_circle_outline_rounded, size: 26)),
        const SizedBox(width: 20),
        _TimerBadge(timer: timer, text: _formatDuration(timer.hasTimeLimit ? Duration(seconds: (timer.remaining.inMilliseconds / 1000).ceil()) : timer.elapsed)),
      ]),
      const SizedBox(height: 18),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(item.question.id);
            return FadeTransition(opacity: animation, child: SlideTransition(position: Tween(begin: Offset(incoming ? .12 : -.12, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child));
          },
          child: ListView(key: ValueKey(item.question.id), padding: const EdgeInsets.only(bottom: 24), children: [
            TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 360), builder: (_, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child)), child: Text(item.question.text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.45))),
            const SizedBox(height: 22),
            for (var answer = 0; answer < item.choices.length; answer++)
              _StaggeredChoice(index: answer, selected: _selectedAnswer == answer, correct: answer == item.correctAnswerIndex, showResult: _selectedAnswer != null, label: item.choices[answer], onTap: () => _answer(answer, item)),
            if (_selectedAnswer != null) ...[
              const SizedBox(height: 8),
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedAnswer == item.correctAnswerIndex ? '正解です！' : '正解は「${item.choices[item.correctAnswerIndex]}」です。', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (item.question.explanation.isNotEmpty) ...[const SizedBox(height: 10), Text(item.question.explanation, style: const TextStyle(height: 1.55))],
              ])),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _next, child: Text(_index + 1 == _session!.length ? '結果を見る' : '次の問題へ')),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _pauseOverlay() => Positioned.fill(child: ColoredBox(color: Colors.black54, child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.pause_circle_filled_rounded, size: 42),
        const SizedBox(height: 12),
        const Text('試験を一時停止中', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        FilledButton.icon(key: const ValueKey('resume-exam'), onPressed: () => ref.read(examTimerProvider.notifier).resume(), icon: const Icon(Icons.play_arrow_rounded), label: const Text('再開')),
      ]))))));

  Widget _result() {
    final total = _session!.length;
    final unanswered = total - _answeredCount;
    final accuracy = total == 0 ? 0 : (_correctCount * 100 / total).round();
    final stats = [
      (Icons.check_circle_rounded, '正解', '$_correctCount問', const Color(0xFF168A62)),
      (Icons.cancel_rounded, '不正解', '${_answeredCount - _correctCount}問', const Color(0xFFD14343)),
      (Icons.timer_rounded, '回答時間', _formatDuration(ref.read(examTimerProvider).elapsed), Theme.of(context).colorScheme.primary),
      (Icons.edit_note_rounded, '未回答', '$unanswered問', const Color(0xFF7A5BA7)),
    ];
    final colors = Theme.of(context).colorScheme;
    return Column(key: const ValueKey('mock-exam-result'), children: [
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      const SizedBox(height: 16),
      Center(child: Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primaryContainer), child: Icon(Icons.celebration_rounded, semanticLabel: '試験終了', size: 38, color: colors.onPrimaryContainer))),
      const SizedBox(height: 18),
      Text('模擬試験終了', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.6)),
      const SizedBox(height: 8),
      Text('よく頑張りました！', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600)),
      const SizedBox(height: 30),
      Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: accuracy / 100), duration: const Duration(seconds: 1), curve: Curves.easeOutCubic, builder: (_, value, __) => SizedBox(width: 232, height: 232, child: Stack(alignment: Alignment.center, children: [SizedBox.expand(child: CircularProgressIndicator(value: value, strokeWidth: 18, strokeCap: StrokeCap.round, backgroundColor: colors.surfaceContainerHighest)), Container(width: 176, height: 176, decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surface, boxShadow: const [BoxShadow(color: Color(0x120F172A), blurRadius: 24, offset: Offset(0, 8))])), Column(mainAxisSize: MainAxisSize.min, children: [Text('正答率', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('${(value * 100).round()}%', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -2, color: colors.primary))])])))),
      const SizedBox(height: 36),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: stats.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.42), itemBuilder: (_, index) {
        final stat = stats[index];
        return TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 350 + index * 100), curve: Interval(index * .12, 1, curve: Curves.easeOutCubic), builder: (_, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 14 * (1 - value)), child: child)), child: AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(stat.$3, maxLines: 1, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.8, color: stat.$4)), const SizedBox(height: 7), Row(mainAxisSize: MainAxisSize.min, children: [Icon(stat.$1, color: stat.$4, size: 18), const SizedBox(width: 6), Text(stat.$2, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700))])])));
      }),
      const SizedBox(height: 28),
      Text('間違えた問題一覧', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      if (_incorrectQuestions.isEmpty)
        const AppCard(child: Center(child: Text('回答した問題は全問正解です！')))
      else
        for (final item in _incorrectQuestions) ...[
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ReviewLine(icon: Icons.help_rounded, label: '問題', value: item.question.text),
            const Divider(height: 24),
            _ReviewLine(icon: Icons.check_rounded, label: '正解', value: item.choices[item.correctAnswerIndex], color: const Color(0xFF168A62)),
            const SizedBox(height: 10),
            _ReviewLine(icon: Icons.close_rounded, label: 'あなたの回答', value: item.choices[_answers[item.question.id]!], color: const Color(0xFFD14343)),
            if (item.question.explanation.isNotEmpty) ...[const Divider(height: 24), _ReviewLine(icon: Icons.lightbulb_rounded, label: '解説', value: item.question.explanation)],
          ])),
          const SizedBox(height: 12),
        ],
      ])),
      Container(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
        decoration: BoxDecoration(color: colors.surface, border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)))),
        child: Row(children: [
          Expanded(child: FilledButton.tonalIcon(onPressed: () => _start(createStudySession(_availableQuestions!, questionCount: _effectiveQuestionCount(_availableQuestions!.length))), icon: const Icon(Icons.replay_rounded), label: const Text('もう一度挑戦'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(onPressed: () => context.go('/home'), icon: const Icon(Icons.home_rounded), label: const Text('ホームへ戻る'))),
        ]),
      ),
    ]);
  }
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.timer, required this.text});
  final ExamTimerState timer;
  final String text;

  @override
  Widget build(BuildContext context) {
    final seconds = timer.remaining.inSeconds;
    final color = timer.hasTimeLimit && seconds <= 60 ? Theme.of(context).colorScheme.error : timer.hasTimeLimit && seconds <= 300 ? const Color(0xFFE87914) : Theme.of(context).colorScheme.primary;
    return AnimatedContainer(duration: const Duration(milliseconds: 280), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .25))), child: Row(children: [Icon(Icons.schedule_rounded, size: 18, color: color), const SizedBox(width: 6), AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 280), style: Theme.of(context).textTheme.titleMedium!.copyWith(color: color, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()]), child: Text(text))]));
  }
}

class _StaggeredChoice extends StatelessWidget {
  const _StaggeredChoice({required this.index, required this.selected, required this.correct, required this.showResult, required this.label, required this.onTap});
  final int index;
  final bool selected;
  final bool correct;
  final bool showResult;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 320 + index * 50), curve: Interval((index * .08).clamp(0.0, .35).toDouble(), 1, curve: Curves.easeOutCubic), builder: (_, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child)), child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _PressableChoice(selected: selected, color: primary, onTap: onTap, child: Row(children: [AnimatedContainer(duration: const Duration(milliseconds: 200), width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? primary : Theme.of(context).colorScheme.surfaceContainerHighest), child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Theme.of(context).colorScheme.onPrimary : null))), const SizedBox(width: 14), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))), if (selected) Icon(showResult && correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: showResult && correct ? const Color(0xFF168A62) : Theme.of(context).colorScheme.error)]))));
  }
}

class _PressableChoice extends StatefulWidget {
  const _PressableChoice({required this.selected, required this.color, required this.onTap, required this.child});
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_PressableChoice> createState() => _PressableChoiceState();
}

class _PressableChoiceState extends State<_PressableChoice> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(scale: pressed ? .97 : 1, duration: const Duration(milliseconds: 120), child: AnimatedContainer(duration: const Duration(milliseconds: 200), decoration: BoxDecoration(color: widget.selected ? widget.color.withValues(alpha: .1) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.selected ? widget.color : Theme.of(context).colorScheme.outlineVariant), boxShadow: [BoxShadow(color: widget.selected ? widget.color.withValues(alpha: .12) : Colors.black.withValues(alpha: .035), blurRadius: widget.selected ? 18 : 12, offset: const Offset(0, 5))]), child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias, child: InkWell(onTap: widget.onTap, onHighlightChanged: (value) => setState(() => pressed = value), child: Padding(padding: const EdgeInsets.all(16), child: widget.child)))));
}

class _ExamSettingsCard extends StatelessWidget {
  const _ExamSettingsCard({required this.questionCount, required this.timeLimitMinutes, required this.onQuestionCountChanged, required this.onTimeLimitChanged});
  final int questionCount;
  final int timeLimitMinutes;
  final ValueChanged<int?> onQuestionCountChanged;
  final ValueChanged<int?> onTimeLimitChanged;

  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.tune_rounded, size: 22, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 12), Text('試験設定', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _SettingField(icon: Icons.quiz_outlined, label: '問題数', value: questionCount, items: _questionCountOptions, itemLabel: (value) => value == 0 ? '全問題' : '$value問', onChanged: onQuestionCountChanged)), const SizedBox(width: 12), Expanded(child: _SettingField(icon: Icons.timer_outlined, label: '制限時間', value: timeLimitMinutes, items: _timeLimitOptions, itemLabel: _timeLimitLabel, onChanged: onTimeLimitChanged))]),
      ]));
}

class _SettingField extends StatelessWidget {
  const _SettingField({required this.icon, required this.label, required this.value, required this.items, required this.itemLabel, required this.onChanged});
  final IconData icon;
  final String label;
  final int value;
  final List<int> items;
  final String Function(int) itemLabel;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 7), Flexible(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)))]), const SizedBox(height: 9), DropdownButtonFormField<int>(initialValue: value, isExpanded: true, borderRadius: BorderRadius.circular(18), decoration: InputDecoration(filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerLowest, contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15), constraints: const BoxConstraints(minHeight: 54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))), items: [for (final item in items) DropdownMenuItem(value: item, child: Text(itemLabel(item), overflow: TextOverflow.ellipsis))], onChanged: onChanged)]);
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.icon, required this.label, required this.value, this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.primary), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(value, style: const TextStyle(height: 1.45))]))]);
}
