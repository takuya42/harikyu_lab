import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/question_sheet_constants.dart';
import 'package:harikyu_lab/core/theme/app_theme.dart';
import 'package:harikyu_lab/features/home/presentation/home_screen.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/learning_history/domain/study_calendar_day.dart';
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';
import 'package:harikyu_lab/features/questions/domain/question.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Calendar extends Fake implements StudyCalendarRepository {
  @override
  Stream<List<StudyCalendarDay>> watch() => Stream.value([]);
  @override
  Stream<int> watchDailyGoal() => Stream.value(10);
  @override
  Future<void> refresh() async {}
}

void main() {
  for (final initialLocation in ['/home', '/other']) {
    testWidgets('初期画面$initialLocationからHomeを表示・再表示しても描画エラーなく最新件数を表示する', (
      tester,
    ) async {
      final category = questionSheetGids.keys.first;
      const cached = Question(
        id: '1',
        text: 'キャッシュ問題',
        choices: ['A', 'B', 'C', 'D'],
        correctAnswerIndex: 0,
      );
      SharedPreferences.setMockInitialValues({
        for (final subject in questionSheetGids.keys)
          'home_test_$subject': jsonEncode(
            subject == category ? [cached.toJson()] : [],
          ),
      });
      final preferences = await SharedPreferences.getInstance();
      var count = 1;
      var requests = 0;
      var delayNextRequest = false;
      Completer<http.Response>? pendingResponse;
      String csv(int count) =>
          'id,subject,question,choice1,choice2,choice3,choice4,answer\n'
          '${[for (var i = 1; i <= count; i++) '$i,$category,問題$i,A,B,C,D,1'].join('\n')}';
      http.Response response(int count) =>
          http.Response.bytes(utf8.encode(csv(count)), 200);
      final client = MockClient((request) {
        final subject = request.url.queryParameters['subject'];
        if (subject != category) return Future.value(response(0));
        requests++;
        if (delayNextRequest) {
          delayNextRequest = false;
          pendingResponse = Completer<http.Response>();
          return pendingResponse!.future;
        }
        return Future.value(response(count));
      });
      final container = ProviderContainer(
        overrides: [
          isProProvider.overrideWithValue(const AsyncData(false)),
          studyCalendarRepositoryProvider.overrideWithValue(_Calendar()),
          for (final subject in questionSheetGids.keys)
            categoryQuestionRepositoryProvider(subject).overrideWith(
              (ref) async => GoogleSheetsQuestionRepository(
                client: client,
                preferences: preferences,
                sheetUrl: Uri.https('example.com', '/questions.csv', {
                  'subject': subject,
                }).toString(),
                cacheKey: 'home_test_$subject',
              ),
            ),
        ],
      );
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/other',
            builder: (_, _) => const Scaffold(body: Text('別画面')),
          ),
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        ],
      );
      addTearDown(() {
        router.dispose();
        container.dispose();
        client.close();
      });
      // Keep another widget subscribed while the Navigator mounts HomeScreen.
      // Invalidating in initState would mark this ancestor dirty during build.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(totalQuestionCountProvider);
              return MaterialApp.router(
                theme: AppTheme.light,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(container.read(totalQuestionCountProvider).requireValue, 1);
      if (initialLocation == '/home') {
        router.go('/other');
        await tester.pumpAndSettle();
      }

      count = 2;
      delayNextRequest = true;
      final previousRequests = requests;
      router.go('/home');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(requests, greaterThan(previousRequests));
      expect(find.text('1問'), findsOneWidget);
      expect(pendingResponse, isNotNull);
      pendingResponse!.complete(response(2));
      await tester.pumpAndSettle();
      expect(find.text('2問'), findsOneWidget);

      router.go('/other');
      await tester.pumpAndSettle();
      count = 3;
      router.go('/home');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('3問'), findsOneWidget);

      count = 4;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('4問'), findsOneWidget);

      count = 0;
      final refreshing = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refreshing;
      expect(tester.takeException(), isNull);
      expect(find.text('0問'), findsAtLeastNWidgets(1));
      expect(find.text('総回答数'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
