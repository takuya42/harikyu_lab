import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/app/app.dart';

void main() {
  testWidgets('スプラッシュからホームへ遷移する', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HarikyuLabApp()));
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
    await tester.pumpWidget(const ProviderScope(child: HarikyuLabApp()));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('アカウント'), findsOneWidget);
  });

  testWidgets('回答結果がホームの学習データへ反映される', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HarikyuLabApp()));
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
