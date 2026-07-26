import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/feature_placeholder.dart';
import 'package:harikyu_lab/features/home/presentation/home_screen.dart';
import 'package:harikyu_lab/features/questions/presentation/questions_screen.dart';
import 'package:harikyu_lab/features/settings/presentation/settings_screen.dart';
import 'package:harikyu_lab/features/splash/presentation/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/questions', builder: (_, _) => const QuestionsScreen()),
          GoRoute(path: '/categories', builder: (_, _) => const FeaturePlaceholder(title: 'カテゴリ一覧', description: '学習したい分野を選んで、効率よく知識を身につけましょう。', icon: Icons.grid_view_rounded)),
          GoRoute(path: '/mock-exam', builder: (_, _) => const FeaturePlaceholder(title: '模擬試験', description: '本番と同じ出題形式・制限時間で、現在の実力を確認できます。', icon: Icons.timer_rounded)),
          GoRoute(path: '/favorites', builder: (_, _) => const FeaturePlaceholder(title: 'お気に入り', description: 'お気に入りに登録した問題を、いつでもまとめて復習できます。', icon: Icons.favorite_rounded)),
          GoRoute(path: '/mistakes', builder: (_, _) => const FeaturePlaceholder(title: '間違えた問題', description: '間違えた問題にもう一度取り組み、苦手分野を克服しましょう。', icon: Icons.replay_rounded)),
          GoRoute(path: '/history', builder: (_, _) => const FeaturePlaceholder(title: '学習履歴', description: '日々の学習量や正答率を振り返り、成長を確認できます。', icon: Icons.insights_rounded)),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
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
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_locations[index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: '問題'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: '模試'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: '履歴'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: '設定'),
        ],
      ),
    );
  }
}
