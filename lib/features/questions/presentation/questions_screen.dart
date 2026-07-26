import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/widgets/app_card.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});
  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  Future<void> _refresh() async => Future<void>.delayed(const Duration(milliseconds: 650));

  @override
  Widget build(BuildContext context) => AppPage(
    title: '問題を解く',
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('過去の国家試験', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          for (var index = 0; index < 4; index++) ...[
            AppCard(
              onTap: () => _showStudyDialog(context, 32 - index),
              child: Row(children: [
                Container(
                  width: 48, height: 48, alignment: Alignment.center,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                  child: Text('${32 - index}', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('第${32 - index}回 国家試験', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(index == 0 ? '続きから・68%完了' : '全160問', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );

  Future<void> _showStudyDialog(BuildContext context, int year) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(Icons.play_circle_outline, size: 38, color: Theme.of(context).colorScheme.primary),
      title: Text('第$year回を始めますか？', textAlign: TextAlign.center),
      content: const Text('前回の続きから学習できます。', textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        Row(children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('始める'))),
        ]),
      ],
    ),
  );
}
