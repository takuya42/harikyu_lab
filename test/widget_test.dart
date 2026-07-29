import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/app/app.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';

const _questions = [
  Question(
    id: '1',
    text: '十二経脈のうち、手の太陰経はどれか。',
    choices: ['心包経', '肺経', '腎経', '胃経'],
    correctAnswerIndex: 1,
  ),
];

ProviderScope testApp() => ProviderScope(
      overrides: [
        questionsProvider.overrideWith((ref) => Stream.value(_questions)),
      ],
      child: const HarikyuLabApp(),
    );

void main() {
  testWidgets('スプラッシュからホームへ遷移する', (tester) async {
    await tester.pumpWidget(testApp());
    expect(find.text('はりきゅうラボ'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('今日も、一歩ずつ。'), findsOneWidget);
    expect(find.text('過去問'), findsNothing);
    expect(find.text('0分'), findsOneWidget);
    expect(find.text('0日'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('正答率'), findsOneWidget);
  });

  testWidgets('ボトムナビゲーションで設定へ遷移する', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('アカウント'), findsOneWidget);
  });

  testWidgets('シェル内の画面遷移でGlobalKeyが重複しない', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模試'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('設定'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('今日も、一歩ずつ。'), findsOneWidget);
  });

  testWidgets('回答結果がホームの学習データへ反映される', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('問題'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学習を始める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('肺経'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(find.text('1日'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
