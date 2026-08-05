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
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: colors.primaryContainer,
        child: Icon(
          Icons.person_add_alt_1_rounded,
          color: colors.onPrimaryContainer,
        ),
      ),
      title: Text(
        'ログインが必要です',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
      ),
      content: Text(
        'この機能を利用するには、ログインまたは無料アカウントの作成が必要です。',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: colors.onSurfaceVariant,
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('あとで'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ログイン / 新規登録'),
        ),
      ],
    );
  }
}
