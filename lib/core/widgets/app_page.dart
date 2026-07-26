import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';

class AppPage extends StatelessWidget {
  const AppPage({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
