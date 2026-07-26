import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppPage(
      title: title,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 40, color: colors.primary),
                ),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, height: 1.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
