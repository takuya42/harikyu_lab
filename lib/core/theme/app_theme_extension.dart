import 'package:flutter/material.dart';

@immutable
class AppSurfaceTheme extends ThemeExtension<AppSurfaceTheme> {
  const AppSurfaceTheme({required this.subtle, required this.success, required this.warning});
  final Color subtle;
  final Color success;
  final Color warning;

  @override
  AppSurfaceTheme copyWith({Color? subtle, Color? success, Color? warning}) => AppSurfaceTheme(
    subtle: subtle ?? this.subtle,
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  @override
  AppSurfaceTheme lerp(covariant AppSurfaceTheme? other, double t) => other == null ? this : AppSurfaceTheme(
    subtle: Color.lerp(subtle, other.subtle, t)!,
    success: Color.lerp(success, other.success, t)!,
    warning: Color.lerp(warning, other.warning, t)!,
  );
}
