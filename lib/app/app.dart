import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harikyu_lab/core/router/app_router.dart';
import 'package:harikyu_lab/core/theme/app_theme.dart';
import 'package:harikyu_lab/features/questions/data/question_repository.dart';

class HarikyuLabApp extends ConsumerWidget {
  const HarikyuLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching here starts the initial download while the splash screen is shown.
    ref.watch(questionsProvider);
    return MaterialApp.router(
      title: 'はりきゅうラボ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
