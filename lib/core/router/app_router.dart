import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/feature_placeholder.dart';
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
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/questions',
            builder: (_, state) => QuestionsScreen(
              subject: state.uri.queryParameters['subject'],
            ),
          ),
          GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
          GoRoute(path: '/mock-exam', builder: (_, _) => const MockExamScreen()),
          GoRoute(path: '/favorites', builder: (_, _) => const QuestionsScreen(favoritesOnly: true)),
          GoRoute(path: '/mistakes', builder: (_, _) => const QuestionsScreen(mistakesOnly: true)),
          GoRoute(path: '/history', builder: (_, _) => const FeaturePlaceholder(title: '学習履歴', description: '日々の学習量や正答率を振り返り、成長を確認できます。', icon: Icons.insights_rounded)),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/login', builder: (_, _) => const AuthScreen(isRegistration: false)),
          GoRoute(path: '/register', builder: (_, _) => const AuthScreen(isRegistration: true)),
        ],
      ),
    ],
  );
});

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
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(.025, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(location), child: child),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_locations[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined, size: 23), selectedIcon: Icon(Icons.home_rounded, size: 27), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined, size: 23), selectedIcon: Icon(Icons.menu_book_rounded, size: 27), label: '問題'),
          NavigationDestination(icon: Icon(Icons.timer_outlined, size: 23), selectedIcon: Icon(Icons.timer_rounded, size: 27), label: '模試'),
          NavigationDestination(icon: Icon(Icons.insights_outlined, size: 23), selectedIcon: Icon(Icons.insights_rounded, size: 27), label: '履歴'),
          NavigationDestination(icon: Icon(Icons.settings_outlined, size: 23), selectedIcon: Icon(Icons.settings_rounded, size: 27), label: '設定'),
        ],
      ),
    );
  }
}
