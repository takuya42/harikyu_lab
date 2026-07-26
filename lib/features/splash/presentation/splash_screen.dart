import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'app-mark',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: colors.onPrimary, shape: BoxShape.circle),
                  child: Icon(Icons.spa_outlined, size: 56, color: colors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppConstants.appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: colors.onPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(AppConstants.subtitle, style: TextStyle(color: colors.onPrimary.withValues(alpha: .84), letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }
}
