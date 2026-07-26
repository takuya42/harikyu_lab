import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    return AppPage(
      title: '設定',
      child: ListView(children: [
      Text('アカウント', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: authState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(user == null ? Icons.person_outline : Icons.account_circle_outlined,
                    size: 42, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(user?.email ?? 'ログインしてください', textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                if (user == null) ...[
                  FilledButton(onPressed: () => context.go('/login'), child: const Text('ログイン')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => context.go('/register'), child: const Text('新規登録')),
                ] else
                  OutlinedButton(
                    onPressed: () => _confirmLogout(context, ref),
                    child: const Text('ログアウト'),
                  ),
              ]),
      )),
      const SizedBox(height: 16),
      const Card(child: Column(children: [ListTile(leading: Icon(Icons.help_outline), title: Text('ヘルプ・お問い合わせ'), trailing: Icon(Icons.chevron_right)), Divider(height: 1, indent: 56), ListTile(leading: Icon(Icons.info_outline), title: Text('アプリについて'), trailing: Text('1.0.0'))])),
      ]),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ログアウト')),
        ],
      ),
    );
    if (shouldLogout != true) return;
    try {
      await ref.read(firebaseAuthProvider).signOut();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通信に失敗しました。もう一度お試しください。')));
      }
    }
  }
}
