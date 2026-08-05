import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/auth/presentation/login_required_dialog.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/data/wrong_question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/presentation/questions_screen.dart';

class WrongQuestionsScreen extends ConsumerStatefulWidget {
  const WrongQuestionsScreen({super.key});

  @override
  ConsumerState<WrongQuestionsScreen> createState() => _WrongQuestionsScreenState();
}

class _WrongQuestionsScreenState extends ConsumerState<WrongQuestionsScreen> {
  bool _loginPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _loginPromptShown) return;
      _loginPromptShown = true;
      await promptLoginForLearningIfNeeded(
        context,
        ref,
        returnTo: '/wrong-questions',
      );
    });
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: '間違えた模擬問題',
        leading: BackButton(onPressed: () => _goBack(context)),
        child: ref.watch(wrongQuestionEntriesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _WrongQuestionsLoadFallback(error: error),
              data: (entries) => ref.watch(mockExamQuestionsProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _WrongQuestionsLoadFallback(error: error),
                    data: (questions) {
                      final questionsById = {
                        for (final question in questions) question.id: question,
                      };
                      final items = [
                        for (final entry in entries)
                          if (questionsById[entry.questionId] != null)
                            questionsById[entry.questionId]!,
                      ];
                      if (items.isEmpty) return const _EmptyWrongQuestions();
                      final wrongQuestionIds = [
                        for (final item in items) item.id,
                      ];
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _WrongQuestionCard(
                          question: items[index],
                          wrongQuestionIds: wrongQuestionIds,
                        ),
                      );
                    },
                  ),
            ),
      );
}

class _WrongQuestionCard extends ConsumerWidget {
  const _WrongQuestionCard({
    required this.question,
    required this.wrongQuestionIds,
  });

  final Question question;
  final List<String> wrongQuestionIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final category = [question.subject, question.category]
        .where((value) => value.isNotEmpty)
        .join(' / ');
    return Dismissible(
      key: ValueKey('wrong-question-${question.id}'),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(color: colors.error),
      confirmDismiss: (_) => _confirmDelete(context, ref),
      child: AppCard(
        onTap: () => context.push(
          Uri(
            path: '/wrong-questions/session',
            queryParameters: {'questionId': question.id},
          ).toString(),
          extra: WrongQuestionsSessionExtra(
            wrongQuestionIds: wrongQuestionIds,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.replay_outlined, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty) ...[
                    Text(
                      category,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 28),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'この問題を削除しますか？',
            maxLines: 1,
            softWrap: false,
          ),
        ),
        content: const Text('間違えた模擬問題一覧から削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return false;

    try {
      await ref.read(wrongQuestionRepositoryProvider).markCorrect(question.id);
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました。時間をおいて再度お試しください。')),
        );
      }
      return false;
    }
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
}

class _EmptyWrongQuestions extends StatelessWidget {
  const _EmptyWrongQuestions();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.replay_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              '間違えた問題はありません',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '問題を解いて復習しましょう',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

class _WrongQuestionsLoadFallback extends StatelessWidget {
  const _WrongQuestionsLoadFallback({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    debugPrint('[WrongQuestionsScreen] failed to load wrong questions: $error');
    return const _EmptyWrongQuestions();
  }
}
