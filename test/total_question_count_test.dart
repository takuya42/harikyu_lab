import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/constants/question_sheet_constants.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';

Question question(String id) => Question(
      id: id,
      text: '問題',
      choices: const ['A', 'B', 'C', 'D'],
      correctAnswerIndex: 0,
    );

void main() {
  test('全カテゴリを集計し、問題の追加・削除を反映する', () async {
    final categories = questionSheetGids.keys.toList();
    final updates = StreamController<List<Question>>();
    final container = ProviderContainer(
      overrides: [
        for (final category in categories)
          categoryQuestionsProvider(category).overrideWith(
            (ref) => category == categories.first
                ? updates.stream
                : Stream.value([question(category), question('shared')]),
          ),
      ],
    );
    final subscription = container.listen(totalQuestionCountProvider, (_, _) {});
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await updates.close();
    });

    expect(container.read(totalQuestionCountProvider).isLoading, isTrue);
    updates.add([question('first'), question('shared')]);
    await Future.wait([
      for (final category in categories)
        container.read(categoryQuestionsProvider(category).future),
    ]);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue,
        categories.length + 1);

    updates.add([question('first'), question('shared'), question('added')]);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue,
        categories.length + 2);

    updates.add([]);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue,
        categories.length);
  });
}
