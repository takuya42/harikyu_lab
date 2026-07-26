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
    expect(find.text('過去問'), findsOneWidget);
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
}
