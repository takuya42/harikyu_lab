import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/constants/question_sheet_constants.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question question(String id) => Question(
      id: id,
      text: '問題',
      choices: const ['A', 'B', 'C', 'D'],
      correctAnswerIndex: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('キャッシュ表示後のCSV取得完了で合計を更新し、再同期で削除も反映する', () async {
    final category = questionSheetGids.keys.first;
    SharedPreferences.setMockInitialValues({
      'count_test_cache': jsonEncode([question('old').toJson()]),
    });
    final preferences = await SharedPreferences.getInstance();
    final response = Completer<http.Response>();
    var csv = 'id,category,question,choice1,choice2,choice3,choice4,answer\n'
        'new1,$category,問題1,A,B,C,D,1\n'
        'new2,$category,問題2,A,B,C,D,1';
    var firstRequest = true;
    final client = MockClient((_) {
      if (firstRequest) {
        firstRequest = false;
        return response.future;
      }
      return Future.value(http.Response(csv, 200));
    });
    final container = ProviderContainer(overrides: [
      categoryQuestionRepositoryProvider(category).overrideWith((ref) async =>
          GoogleSheetsQuestionRepository(
            client: client,
            preferences: preferences,
            sheetUrl: 'https://example.com/questions.csv',
            cacheKey: 'count_test_cache',
          )),
      for (final other in questionSheetGids.keys.where((key) => key != category))
        categoryQuestionsProvider(other).overrideWith((ref) => Stream.value([])),
    ]);
    final subscription = container.listen(totalQuestionCountProvider, (_, _) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
      client.close();
    });
    await container.read(categoryQuestionsProvider(category).future);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue, 1);

    final latest = Completer<void>();
    final listener = container.listen(totalQuestionCountProvider, (_, next) {
      if (next.value == 2 && !latest.isCompleted) latest.complete();
    });
    response.complete(http.Response(csv, 200));
    await latest.future.timeout(const Duration(seconds: 5));
    listener.close();
    expect(container.read(totalQuestionCountProvider).requireValue, 2);

    csv = 'id,category,question,choice1,choice2,choice3,choice4,answer';
    final deleted = Completer<void>();
    final deletionListener = container.listen(totalQuestionCountProvider, (_, next) {
      if (next.value == 0 && !deleted.isCompleted) deleted.complete();
    });
    container.invalidate(categoryQuestionsProvider(category));
    await deleted.future.timeout(const Duration(seconds: 5));
    deletionListener.close();
    expect(container.read(totalQuestionCountProvider).requireValue, 0);
  });

  test('科目間の同じIDは別問題として集計し、追加・削除を反映する', () async {
    final categories = questionSheetGids.keys.toList();
    final updates = StreamController<List<Question>>();
    final container = ProviderContainer(
      overrides: [
        for (final category in categories)
          categoryQuestionsProvider(category).overrideWith(
            (ref) => category == categories.first
                ? updates.stream
                : Stream.value([
                    question(category), question('shared'), question('shared'),
                  ]),
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
        categories.length * 2);

    updates.add([question('first'), question('shared'), question('added')]);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue,
        categories.length * 2 + 1);

    updates.add([]);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue,
        (categories.length - 1) * 2);
  });

  test('科目ごとの行番号IDが重複しても5科目360問になり、取得失敗科目は除外する', () async {
    const counts = {
      '医療概論': 50,
      '衛生学・公衆衛生学': 100,
      '関係法規': 60,
      '解剖学': 100,
      '生理学': 50,
    };
    final container = ProviderContainer(overrides: [
      for (final category in questionSheetGids.keys)
        categoryQuestionsProvider(category).overrideWith((ref) {
          final count = counts[category];
          if (count == null) return Stream.error(StateError('取得失敗'));
          return Stream.value([
            for (var i = 0; i < count; i++) question('row_${i + 2}'),
          ]);
        }),
    ]);
    final subscription = container.listen(totalQuestionCountProvider, (_, _) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    await Future.wait([
      for (final category in questionSheetGids.keys)
        container.read(categoryQuestionsProvider(category).future).then<void>(
          (_) {}, onError: (Object _, StackTrace _) {},
        ),
    ]);
    await container.pump();
    expect(container.read(totalQuestionCountProvider).requireValue, 360);
  });
}
