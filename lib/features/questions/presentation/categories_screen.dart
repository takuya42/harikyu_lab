import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/domain/subjects.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
        title: 'カテゴリ',
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Text('学習する科目を選んでください',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var index = 0; index < subjects.length; index++) ...[
                    ListTile(
                      splashColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .16),
                      leading: Icon(Icons.menu_book_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(subjects[index],
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing:
                          const Icon(Icons.chevron_right_rounded, size: 28),
                      onTap: () async {
                        if (!(ref.read(proAccessProvider).value?.isPro ?? false)) {
                          await context.push('/pro');
                          return;
                        }
                        await ref.read(analyticsServiceProvider).categorySelected(subjects[index]);
                        if (context.mounted) {
                          context.go(Uri(path: '/questions', queryParameters: {'subject': subjects[index]}).toString());
                        }
                      },
                    ),
                    if (index < subjects.length - 1)
                      const Divider(height: 1),
                  ],
                ]),
              ),
            ),
          ],
        ),
      );
}
