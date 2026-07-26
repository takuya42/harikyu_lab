import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/app/app.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';

const testQuestion = Question(
  id: '1', subject: '経絡', category: '基礎',
  question: '十二経脈のうち、手の太陰経はどれか。',
  choices: ['心包経', '肺経', '腎経', '胃経'], answer: '2', explanation: '手の太陰経は肺経です。',
);

ProviderScope testApp() => ProviderScope(
  overrides: [questionsProvider.overrideWith((ref) async => [testQuestion])],
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
