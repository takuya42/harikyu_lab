import 'package:flutter/material.dart';
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
        mockExamQuestionsProvider
            .overrideWith((ref) => Stream.value(_questions)),
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

  testWidgets('試験設定が画面幅に応じて横並びと縦並びに切り替わる', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模試'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsWidgets);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.assignment_outlined)).size,
      20,
    );
    expect(find.text('📄 問題数'), findsNothing);
    expect(find.text('⏱ 制限時間'), findsNothing);
    expect(
      tester.getCenter(find.text('問題数')).dy,
      tester.getCenter(find.text('制限時間')).dy,
    );
    final dropdowns = find.byType(DropdownButtonFormField<int>);
    expect(dropdowns, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      expect(tester.getSize(dropdowns.at(index)).height, 52);
    }

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('問題数')).dy,
      lessThan(tester.getCenter(find.text('制限時間')).dy),
    );
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
