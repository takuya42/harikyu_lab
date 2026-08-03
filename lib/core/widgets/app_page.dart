import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.child,
    this.leading,
    this.backgroundColor,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: leading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.pageMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.horizontalPadding, 8,
                AppConstants.horizontalPadding, 24,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
