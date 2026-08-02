import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/features/learning_history/presentation/learning_history_screen.dart';
import 'package:harikyu_lab/features/home/presentation/home_screen.dart';
import 'package:harikyu_lab/features/questions/presentation/questions_screen.dart';
import 'package:harikyu_lab/features/questions/presentation/categories_screen.dart';
import 'package:harikyu_lab/features/mock_exam/presentation/mock_exam_screen.dart';
import 'package:harikyu_lab/features/settings/presentation/settings_screen.dart';
import 'package:harikyu_lab/features/splash/presentation/splash_screen.dart';
import 'package:harikyu_lab/features/auth/presentation/auth_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', pageBuilder: (_, state) => _fadeSlidePage(state, const HomeScreen())),
          GoRoute(
            path: '/questions',
            pageBuilder: (_, state) => _fadeSlidePage(state, QuestionsScreen(
              subject: state.uri.queryParameters['subject'],
            )),
          ),
          GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
          GoRoute(path: '/mock-exam', pageBuilder: (_, state) => _fadeSlidePage(state, const MockExamScreen())),
          GoRoute(path: '/favorites', builder: (_, _) => const QuestionsScreen(favoritesOnly: true)),
          GoRoute(path: '/mistakes', builder: (_, _) => const QuestionsScreen(mistakesOnly: true)),
          GoRoute(path: '/history', pageBuilder: (_, state) => _fadeSlidePage(state, const LearningHistoryScreen())),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/login', pageBuilder: (_, state) => _fadeSlidePage(state, const AuthScreen(isRegistration: false))),
          GoRoute(path: '/register', pageBuilder: (_, state) => _fadeSlidePage(state, const AuthScreen(isRegistration: true))),
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
