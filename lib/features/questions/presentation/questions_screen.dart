import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';

class QuestionsScreen extends StatelessWidget {
  const QuestionsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '問題一覧',
    child: ListView.separated(
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), leading: CircleAvatar(child: Text('${index + 1}')), title: Text('第${32 - index}回 国家試験'), subtitle: const Text('全160問'), trailing: const Icon(Icons.chevron_right_rounded))),
    ),
  );
}
