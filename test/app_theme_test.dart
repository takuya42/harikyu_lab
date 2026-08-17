import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harikyu_lab/core/theme/app_theme.dart';

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() < background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  return (lighter + .05) / (darker + .05);
}

void main() {
  test('dark theme uses accessible semantic text colors', () {
    final theme = AppTheme.dark;
    final colors = theme.colorScheme;

    expect(theme.brightness, Brightness.dark);
    expect(theme.textTheme.bodyMedium!.color, colors.onSurface);
    expect(theme.textTheme.headlineMedium!.color, colors.onSurface);
    expect(_contrast(colors.onSurface, colors.surface), greaterThanOrEqualTo(7));
    expect(
      _contrast(colors.onSurfaceVariant, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(colors.surface.computeLuminance(), greaterThan(colors.surfaceContainerLowest.computeLuminance()));
    expect(colors.outlineVariant, isNot(colors.surface));
  });

  test('dark navigation and buttons derive their colors from ColorScheme', () {
    final theme = AppTheme.dark;
    final colors = theme.colorScheme;
    const selected = <WidgetState>{WidgetState.selected};
    const enabled = <WidgetState>{};

    expect(theme.navigationBarTheme.backgroundColor, colors.surface);
    expect(theme.navigationBarTheme.iconTheme!.resolve(selected)!.color, colors.primary);
    expect(theme.navigationBarTheme.iconTheme!.resolve(enabled)!.color, colors.onSurfaceVariant);
    expect(theme.bottomNavigationBarTheme.selectedItemColor, colors.primary);
    expect(theme.bottomNavigationBarTheme.unselectedItemColor, colors.onSurfaceVariant);
    expect(theme.filledButtonTheme.style!.foregroundColor!.resolve(enabled), colors.onPrimary);
    expect(_contrast(colors.onPrimary, colors.primary), greaterThanOrEqualTo(4.5));
  });

  test('light theme palette remains unchanged', () {
    final colors = AppTheme.light.colorScheme;

    expect(AppTheme.light.brightness, Brightness.light);
    expect(colors.surface, const Color(0xFFFFFDF9));
    expect(colors.onSurface, const Color(0xFF2F2F2F));
    expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF8F5EF));
  });
}
