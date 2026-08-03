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
import 'package:harikyu_lab/features/pro/data/pro_access_service.dart';

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
    final user = ref.watch(authStateProvider).asData?.value;
    final colors = Theme.of(context).colorScheme;
    final isPro = ref.watch(proAccessProvider).value?.isPro ?? false;
    return AppPage(
      title: '設定',
      backgroundColor: colors.surface,
      child: ColoredBox(
        color: colors.surface,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            _AnimatedSection(
              index: 0,
              title: 'Pro版',
              child: _SettingsCard(children: [
                _SettingsItem(
                  icon: Icons.workspace_premium_outlined,
                  label: isPro ? 'Pro版をご利用中' : 'Pro版にアップグレード（¥980）',
                  onTap: () async => context.push('/pro'),
                ),
              ]),
            ),
            const SizedBox(height: 28),
            _AnimatedSection(
              index: 1,
              title: 'アカウント',
              child: _SettingsCard(
                children: [
                  _SettingsItem(
                    icon: Icons.person_outline_rounded,
                    label: user?.email ?? 'ログインしていません',
                  ),
                  if (user == null)
                    _SettingsItem(
                      icon: Icons.login_rounded,
                      label: 'ログイン',
                      onTap: () async {
                        context.go('/login');
                        return;
                      },
                    )
                  else
                    _SettingsItem(
                      icon: Icons.logout_rounded,
                      label: 'ログアウト',
                      enabled: !_processing,
                      onTap: _logout,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _AnimatedSection(
              index: 2,
              title: 'サポート・法的情報',
              child: _SettingsCard(
                children: [
                  _SettingsItem(
                    icon: Icons.description_outlined,
                    label: '利用規約',
                    enabled: !_processing,
                    onTap: () => _openPage(AppUrls.termsOfService),
                  ),
                  _SettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'プライバシーポリシー',
                    enabled: !_processing,
                    onTap: () => _openPage(AppUrls.privacyPolicy),
                  ),
                  _SettingsItem(
                    icon: Icons.support_agent_outlined,
                    label: 'お問い合わせ',
                    enabled: !_processing,
                    onTap: () => _openPage(
                      AppUrls.contactForm,
                      failureMessage: 'お問い合わせページを開けませんでした',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _AnimatedSection(
              index: 3,
              title: 'データ管理',
              child: _SettingsCard(
                children: [
                  _SettingsItem(
                    icon: Icons.restart_alt_rounded,
                    label: 'データ初期化',
                    enabled: !_processing,
                    onTap: _resetData,
                  ),
                  if (user != null)
                    _SettingsItem(
                      icon: Icons.delete_outline_rounded,
                      label: '退会',
                      enabled: !_processing,
                      destructive: true,
                      onTap: _deleteAccount,
                    ),
                ],
              ),
            ),
            if (_processing) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(
    String title,
    String message,
    String action, {
    bool destructive = false,
  }) async {
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
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor:
                            Theme.of(context).colorScheme.onError,
                      )
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
    if (!await _confirm(
      'ログアウトしますか？',
      '端末に保存された学習データは保持されます。',
      'ログアウト',
    )) return;
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
      'アカウントを削除しますか？',
      'この操作は元に戻せません。\n学習データ・お気に入り・履歴も削除されます。',
      '削除する',
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
    await _run(() async {
      final service = await ref.read(settingsServiceProvider.future);
      await service.openExternalUrl(url);
    }, failureMessage: failureMessage);
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool deletingAccount = false,
    String? failureMessage,
  }) async {
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

class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({
    required this.index,
    required this.title,
    required this.child,
  });

  final int index;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index * 110)),
      curve: Interval(index * 0.12, 1, curve: Curves.easeOutCubic),
      builder: (context, value, animatedChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: animatedChild,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<_SettingsItem> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, indent: 72, endIndent: 16),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatefulWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;
  final bool enabled;
  final bool destructive;

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final interactive = widget.onTap != null && widget.enabled;
    final accent = widget.destructive ? colors.error : colors.primary;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed
            ? accent.withValues(alpha: widget.destructive ? 0.10 : 0.07)
            : Colors.transparent,
        child: InkWell(
          onHighlightChanged: interactive
              ? (pressed) => setState(() => _pressed = pressed)
              : null,
          onTap: interactive ? () => widget.onTap!() : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: widget.enabled ? 1 : 0.45,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(
                          alpha: widget.destructive ? 0.12 : 0.07,
                        ),
                      ),
                      child: Icon(widget.icon, color: accent, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: widget.destructive ? colors.error : null,
                            fontWeight: widget.destructive
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                    ),
                  ),
                  if (widget.onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: widget.destructive
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
