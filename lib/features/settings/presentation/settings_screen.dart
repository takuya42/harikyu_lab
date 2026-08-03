import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/analytics/analytics_service.dart';
import 'package:harikyu_lab/core/constants/app_urls.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';
import 'package:harikyu_lab/features/auth/data/auth_providers.dart';
import 'package:harikyu_lab/features/learning_history/data/learning_history_repository.dart';
import 'package:harikyu_lab/features/learning_history/data/study_calendar_repository.dart';
import 'package:harikyu_lab/features/questions/data/favorite_question_repository.dart';
import 'package:harikyu_lab/features/settings/data/settings_service.dart';
import 'package:harikyu_lab/features/study_statistics/data/study_statistics_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).settingsOpened();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    return AppPage(
      title: '設定',
      child: ListView(
        children: [
          _heading('アカウント'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(user?.email ?? 'ログインしていません'),
                ),
                if (user == null) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('ログイン'),
                    onTap: () => context.go('/login'),
                  ),
                ] else ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('ログアウト'),
                    enabled: !_processing,
                    onTap: _logout,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _heading('サポート・法的情報'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _tile(Icons.description_outlined, '利用規約', () {
                  return _openPage(AppUrls.termsOfService);
                }),
                const Divider(height: 1, indent: 56),
                _tile(Icons.privacy_tip_outlined, 'プライバシーポリシー', () {
                  return _openPage(AppUrls.privacyPolicy);
                }),
                const Divider(height: 1, indent: 56),
                _tile(Icons.support_agent_outlined, 'お問い合わせ', () {
                  return _openPage(
                    AppUrls.contactForm,
                    failureMessage: 'お問い合わせページを開けませんでした',
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _heading('データ管理'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _tile(Icons.restart_alt, 'データ初期化', _resetData),
                if (user != null) ...[
                  const Divider(height: 1, indent: 56),
                  _tile(Icons.person_remove_outlined, '退会', _deleteAccount,
                      color: Theme.of(context).colorScheme.error),
                ],
              ],
            ),
          ),
          if (_processing) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      );

  Widget _tile(IconData icon, String title, Future<void> Function() onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: color == null ? null : TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      enabled: !_processing,
      onTap: onTap,
    );
  }

  Future<bool> _confirm(String title, String message, String action,
      {bool destructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error)
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _logout() async {
    if (!await _confirm('ログアウトしますか？', '端末に保存された学習データは保持されます。', 'ログアウト')) {
      return;
    }
    await _run(() async {
      await ref.read(firebaseAuthProvider).signOut();
      if (mounted) context.go('/login');
    });
  }

  Future<void> _resetData() async {
    if (!await _confirm(
      '学習データを初期化しますか？',
      'お気に入り、学習履歴、統計データが削除されます。この操作は取り消せません。',
      '初期化',
      destructive: true,
    )) return;
    await _run(() async {
      final service = await ref.read(settingsServiceProvider.future);
      await service.resetLearningData();
      ref.invalidate(favoriteQuestionRepositoryProvider);
      ref.invalidate(favoriteQuestionIdsProvider);
      ref.invalidate(studyStatisticsRepositoryProvider);
      ref.invalidate(studyStatisticsProvider);
      ref.invalidate(learningHistoryRepositoryProvider);
      ref.invalidate(learningHistoryProvider);
      ref.invalidate(studyCalendarRepositoryProvider);
      ref.invalidate(studyCalendarProvider);
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(studyStreakProvider);
      ref.invalidate(dailyGoalProvider);
      _showMessage('学習データを初期化しました。');
    });
  }

  Future<void> _deleteAccount() async {
    if (!await _confirm(
      '退会しますか？',
      'アカウントとすべてのユーザーデータが完全に削除されます。この操作は取り消せません。',
      '退会する',
      destructive: true,
    )) return;
    await _run(() async {
      final service = await ref.read(settingsServiceProvider.future);
      await service.deleteAccount();
      if (mounted) context.go('/login');
    }, deletingAccount: true);
  }

  Future<void> _openPage(
    String url, {
    String failureMessage = 'ページを開けませんでした',
  }) async {
    await _run(
      () async {
        final service = await ref.read(settingsServiceProvider.future);
        await service.openExternalUrl(url);
      },
      failureMessage: failureMessage,
    );
  }

  Future<void> _run(Future<void> Function() operation,
      {bool deletingAccount = false, String? failureMessage}) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await operation();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        _showMessage('安全のため再ログインしてから、もう一度退会操作を行ってください。');
      } else {
        _showMessage(deletingAccount
            ? '退会処理に失敗しました。時間をおいてもう一度お試しください。'
            : '認証処理に失敗しました。もう一度お試しください。');
      }
    } on Object {
      _showMessage(failureMessage ??
          (deletingAccount
              ? 'ユーザーデータの削除に失敗しました。通信状態を確認してください。'
              : '処理に失敗しました。通信状態や対応アプリを確認してください。'));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
