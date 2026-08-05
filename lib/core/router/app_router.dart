import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/features/learning_history/presentation/learning_history_screen.dart';
import 'package:harikyu_lab/features/home/presentation/home_screen.dart';
import 'package:harikyu_lab/features/questions/presentation/questions_screen.dart';
import 'package:harikyu_lab/features/questions/presentation/wrong_questions_screen.dart';
import 'package:harikyu_lab/features/questions/presentation/categories_screen.dart';
import 'package:harikyu_lab/features/mock_exam/presentation/mock_exam_screen.dart';
import 'package:harikyu_lab/features/settings/presentation/settings_screen.dart';
import 'package:harikyu_lab/features/splash/presentation/splash_screen.dart';
import 'package:harikyu_lab/features/auth/presentation/auth_screen.dart';
import 'package:harikyu_lab/features/pro/presentation/pro_purchase_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    observers: [
      FirebaseAnalyticsObserver(analytics: ref.watch(firebaseAnalyticsProvider)),
    ],
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(name: 'Home', path: '/home', pageBuilder: (_, state) => _fadeSlidePage(state, const HomeScreen())),
          GoRoute(
            name: 'Questions',
            path: '/questions',
            pageBuilder: (_, state) => _fadeSlidePage(state, QuestionsScreen(
              subject: state.uri.queryParameters['subject'],
              autoStart: state.uri.queryParameters['start'] == '1',
            )),
          ),
          GoRoute(name: 'Category', path: '/categories', builder: (_, _) => const CategoriesScreen()),
          GoRoute(name: 'Mock Exam', path: '/mock-exam', pageBuilder: (_, state) => _fadeSlidePage(state, const MockExamScreen())),
          GoRoute(
            path: '/favorites',
            builder: (_, state) => QuestionsScreen(
              favoritesOnly: true,
              autoStart: state.uri.queryParameters['start'] == '1',
            ),
          ),
          GoRoute(path: '/wrong-questions', builder: (_, _) => const WrongQuestionsScreen()),
          GoRoute(
            path: '/wrong-questions/session',
            builder: (_, state) {
              final extra = state.extra;
              return QuestionsScreen(
                wrongQuestionsOnly: true,
                initialQuestionId: state.uri.queryParameters['questionId'],
                wrongQuestionIds: extra is WrongQuestionsSessionExtra
                    ? extra.wrongQuestionIds
                    : const [],
                autoStart: state.uri.queryParameters['start'] == '1',
              );
            },
          ),
          GoRoute(name: 'Calendar', path: '/history', pageBuilder: (_, state) => _fadeSlidePage(state, const LearningHistoryScreen())),
          GoRoute(name: 'Settings', path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/pro', builder: (_, _) => const ProPurchaseScreen()),
          GoRoute(path: '/login', pageBuilder: (_, state) => _fadeSlidePage(state, AuthScreen(
              isRegistration: false,
              returnTo: state.uri.queryParameters['returnTo'],
            ))),
          GoRoute(path: '/register', pageBuilder: (_, state) => _fadeSlidePage(state, AuthScreen(
              isRegistration: true,
              returnTo: state.uri.queryParameters['returnTo'],
            ))),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.035, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});
  final String location;
  final Widget child;

  static const _locations = ['/home', '/questions', '/mock-exam', '/history', '/settings'];

  int get _selectedIndex {
    final index = _locations.indexOf(location);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final showNavigation = _locations.contains(location);
    return Scaffold(
      // ShellRoute owns this child (and the Navigator key inside it). Keeping an
      // outgoing copy in an AnimatedSwitcher temporarily inserts that same
      // GlobalKey into two widget subtrees when the location changes.
      body: child,
      bottomNavigationBar: showNavigation ? NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_locations[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined, size: 23), selectedIcon: Icon(Icons.home_rounded, size: 27), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined, size: 23), selectedIcon: Icon(Icons.menu_book_rounded, size: 27), label: '問題'),
          NavigationDestination(icon: Icon(Icons.timer_outlined, size: 23), selectedIcon: Icon(Icons.timer_rounded, size: 27), label: '模試'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined, size: 23), selectedIcon: Icon(Icons.calendar_month_rounded, size: 27), label: 'カレンダー'),
          NavigationDestination(icon: Icon(Icons.settings_outlined, size: 23), selectedIcon: Icon(Icons.settings_rounded, size: 27), label: '設定'),
        ],
      ) : null,
    );
  }
}
