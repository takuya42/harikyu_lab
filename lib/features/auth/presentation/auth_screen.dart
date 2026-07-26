import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.isRegistration});
  final bool isRegistration;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      if (widget.isRegistration) {
        await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_messageFor(error.code));
    } on Object {
      if (mounted) _showError('通信に失敗しました。接続を確認してもう一度お試しください。');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _messageFor(String code) => switch (code) {
        'invalid-email' => 'メールアドレスの形式を確認してください。',
        'weak-password' => 'パスワードは6文字以上で入力してください。',
        'email-already-in-use' => 'このメールアドレスは既に登録されています。',
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'メールアドレスまたはパスワードが正しくありません。',
        'network-request-failed' => '通信に失敗しました。接続を確認してください。',
        _ => widget.isRegistration ? '新規登録に失敗しました。' : 'ログインに失敗しました。',
      };

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.isRegistration ? '新規登録' : 'ログイン',
        child: Form(
          key: _formKey,
          child: ListView(children: [
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'メールアドレス', prefixIcon: Icon(Icons.mail_outline)),
              validator: (value) => value == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
                  ? '有効なメールアドレスを入力してください'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'パスワード', prefixIcon: Icon(Icons.lock_outline)),
              validator: (value) => (value?.length ?? 0) < 6 ? 'パスワードは6文字以上で入力してください' : null,
            ),
            if (widget.isRegistration) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmationController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'パスワード確認', prefixIcon: Icon(Icons.lock_reset_outlined)),
                validator: (value) => value != _passwordController.text ? 'パスワードが一致しません' : null,
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.isRegistration ? '登録する' : 'ログイン'),
            ),
          ]),
        ),
      );
}
