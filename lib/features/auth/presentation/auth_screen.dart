import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/core/providers/firebase_firestore_provider.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';

const _brandColor = Color(0xFF5A6DBA);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.isRegistration});
  final bool isRegistration;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  late final AnimationController _entranceController;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (widget.isRegistration && !_acceptedTerms) {
      _showError('利用規約とプライバシーポリシーへの同意が必要です。');
      return;
    }
    await _runAuth(() async {
      final auth = ref.read(firebaseAuthProvider);
      if (widget.isRegistration) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final user = credential.user;
        if (user != null) {
          final name = _nameController.text.trim();
          await user.updateDisplayName(name);
          final now = FieldValue.serverTimestamp();
          await ref
              .read(firebaseFirestoreProvider)
              .collection('users')
              .doc(user.uid)
              .set({
            'name': name,
            'email': user.email ?? _emailController.text.trim(),
            'plan': 'free',
            'createdAt': now,
            'updatedAt': now,
          });
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    });
  }

  Future<void> _runAuth(Future<void> Function() operation) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await operation();
      if (widget.isRegistration) {
        await ref.read(analyticsServiceProvider).signUp();
      } else {
        await ref.read(analyticsServiceProvider).login();
      }
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_messageFor(error.code));
    } on FirebaseException catch (error) {
      if (mounted) _showError(_messageFor(error.code));
    } on Object {
      if (mounted) _showError('通信に失敗しました。接続を確認してもう一度お試しください。');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );
    if (!mounted || email == null || email.isEmpty) return;
    try {
      await ref.read(firebaseAuthProvider).sendPasswordResetEmail(email: email);
      if (mounted) _showMessage('パスワード再設定メールを送信しました。');
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_messageFor(error.code));
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

  String _messageFor(String code) => switch (code) {
        'invalid-email' => 'メールアドレスの形式を確認してください。',
        'weak-password' => 'パスワードは8文字以上で入力してください。',
        'email-already-in-use' => 'このメールアドレスは既に登録されています。',
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'メールアドレスまたはパスワードが違います。',
        'network-request-failed' || 'unavailable' =>
          '通信に失敗しました。接続を確認してください。',
        'too-many-requests' => 'しばらく時間をおいてから、もう一度お試しください。',
        _ => widget.isRegistration ? '新規登録に失敗しました。' : 'ログインに失敗しました。',
      };

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _entranceController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final isRegistration = widget.isRegistration;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          FadeTransition(
                            opacity: _interval(.18, .82),
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, .08), end: Offset.zero)
                                  .animate(_interval(.18, .82)),
                              child: _AuthCard(
                                formKey: _formKey,
                                isRegistration: isRegistration,
                                nameController: _nameController,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmationController: _confirmationController,
                                obscurePassword: _obscurePassword,
                                obscureConfirmation: _obscureConfirmation,
                                acceptedTerms: _acceptedTerms,
                                submitting: _submitting,
                                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                                onToggleConfirmation: () => setState(
                                  () => _obscureConfirmation = !_obscureConfirmation,
                                ),
                                onTermsChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                                onSubmit: _submit,
                                onResetPassword: _resetPassword,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          FadeTransition(
                            opacity: _interval(.58, 1),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  isRegistration
                                      ? 'すでにアカウントをお持ちの方はこちら'
                                      : 'アカウントをお持ちでない方はこちら',
                                ),
                                TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => context.pushReplacement(isRegistration ? '/login' : '/register'),
                                  child: Text(isRegistration ? 'ログイン' : '新規登録'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns the text-input resources for exactly as long as the dialog route exists.
///
/// `showDialog` completes its future as soon as `Navigator.pop` is called, while
/// the dialog remains mounted during its reverse transition. Disposing a
/// controller in the caller immediately after awaiting that future therefore
/// leaves the still-mounted [TextField] attached to a disposed controller.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded),
        title: const Text('パスワードを再設定'),
        content: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => context.pop(_controller.text.trim()),
            child: const Text('送信'),
          ),
        ],
      );
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A6DBA), Color(0xFF8593D0), Color(0xFFF7F8FD), Colors.white],
            stops: [0, .18, .43, .68],
          ),
        ),
      );
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.isRegistration,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmationController,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.acceptedTerms,
    required this.submitting,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onTermsChanged,
    required this.onSubmit,
    required this.onResetPassword,
  });

  final GlobalKey<FormState> formKey;
  final bool isRegistration;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final bool acceptedTerms;
  final bool submitting;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final ValueChanged<bool?> onTermsChanged;
  final VoidCallback onSubmit;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 7,
        shadowColor: const Color(0x245A6DBA),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isRegistration) ...[
                  TextFormField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: '名前',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true) ? '名前を入力してください' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (value) => value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
                      ? '有効なメールアドレスを入力してください'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction: isRegistration ? TextInputAction.next : TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: isRegistration ? null : (_) => onSubmit(),
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword ? 'パスワードを表示' : 'パスワードを隠す',
                      onPressed: onTogglePassword,
                      icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'パスワードは8文字以上で入力してください'
                      : null,
                ),
                if (isRegistration) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmationController,
                    obscureText: obscureConfirmation,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      labelText: 'パスワード確認',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        tooltip: obscureConfirmation ? 'パスワードを表示' : 'パスワードを隠す',
                        onPressed: onToggleConfirmation,
                        icon: Icon(obscureConfirmation ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) => value != passwordController.text ? 'パスワードが一致しません' : null,
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: acceptedTerms,
                    onChanged: submitting ? null : onTermsChanged,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('利用規約とプライバシーポリシーに同意します', style: TextStyle(fontSize: 13)),
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: submitting ? null : onResetPassword, child: const Text('パスワードを忘れた方')),
                  ),
                const SizedBox(height: 10),
                _AnimatedAuthButton(
                  onPressed: submitting ? null : onSubmit,
                  loading: submitting,
                  label: isRegistration ? '新規登録' : 'ログイン',
                ),
              ],
            ),
          ),
        ),
      );
}

class _AnimatedAuthButton extends StatefulWidget {
  const _AnimatedAuthButton({required this.onPressed, required this.loading, required this.label});
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  State<_AnimatedAuthButton> createState() => _AnimatedAuthButtonState();
}

class _AnimatedAuthButtonState extends State<_AnimatedAuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: const Duration(milliseconds: 110),
        child: SizedBox(
          height: 56,
          child: Listener(
            onPointerDown: widget.onPressed == null ? null : (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.loading
                    ? const SizedBox.square(
                        key: ValueKey('loading'),
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(widget.label, key: const ValueKey('label')),
              ),
            ),
          ),
        ),
      );
}
