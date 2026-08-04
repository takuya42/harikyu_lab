import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';

class AppCard extends StatefulWidget {
  const AppCard({required this.child, this.onTap, this.padding = const EdgeInsets.all(20), super.key});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .985 : 1,
    duration: AppConstants.fastAnimation,
    curve: Curves.easeOutCubic,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: widget.onTap == null ? null : (value) => setState(() => _pressed = value),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    ),
  );
}
