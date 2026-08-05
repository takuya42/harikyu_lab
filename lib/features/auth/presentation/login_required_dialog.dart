import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';

/// Shows a soft sign-up prompt only when the current user is not signed in.
///
/// Returns `true` when the caller can continue the protected learning action.
Future<bool> promptLoginForLearningIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required String returnTo,
}) async {
  ref.read(authStateProvider);
  if (ref.read(firebaseAuthProvider).currentUser != null) return true;
  final shouldStart = await showDialog<bool>(
    context: context,
    builder: (context) => const LoginRequiredDialog(),
  );
  if (shouldStart != true || !context.mounted) return false;
  context.push(
    Uri(
      path: '/register',
      queryParameters: {'returnTo': returnTo},
    ).toString(),
  );
  return false;
}

class LoginRequiredDialog extends StatelessWidget {
  const LoginRequiredDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: colors.primaryContainer,
        child: Icon(Icons.person_add_alt_1_rounded, color: colors.onPrimaryContainer),
      ),
      title: const Text('無料で学習を始めましょう'),
      content: const Text(
        '無料アカウントを作成すると\n\n'
        '・学習履歴を保存\n'
        '・学習カレンダーを記録\n'
        '・お気に入りを保存\n'
        '・端末変更時もデータを引き継ぎ\n\n'
        'もちろん無料でご利用いただけます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('あとで'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('無料で始める'),
        ),
      ],
    );
  }
}
