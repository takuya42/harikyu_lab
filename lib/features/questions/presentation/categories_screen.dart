import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/questions/domain/subjects.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'カテゴリ',
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Text('学習する科目を選んでください',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var index = 0; index < subjects.length; index++) ...[
                  ListTile(
                    leading: Icon(Icons.menu_book_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text(subjects[index],
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go(Uri(
                      path: '/questions',
                      queryParameters: {'subject': subjects[index]},
                    ).toString()),
                  ),
                  if (index < subjects.length - 1) const Divider(height: 1),
                ],
              ]),
            ),
          ],
        ),
      );
}
