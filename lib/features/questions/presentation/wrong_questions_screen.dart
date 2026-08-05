import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/data/wrong_question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:harikyu_lab/features/questions/presentation/questions_screen.dart';

class WrongQuestionsScreen extends ConsumerWidget {
  const WrongQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
        title: '間違えた問題',
        leading: BackButton(onPressed: () => context.pop()),
        child: ref.watch(wrongQuestionEntriesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LoadError(error: error),
              data: (entries) => ref.watch(allQuestionsProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _LoadError(error: error),
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
                        for (final entry in entries) entry.questionId,
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

class _WrongQuestionCard extends StatelessWidget {
  const _WrongQuestionCard({
    required this.question,
    required this.wrongQuestionIds,
  });

  final Question question;
  final List<String> wrongQuestionIds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final category = [question.subject, question.category]
        .where((value) => value.isNotEmpty)
        .join(' / ');
    return AppCard(
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
    );
  }
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('$error', textAlign: TextAlign.center),
      );
}
