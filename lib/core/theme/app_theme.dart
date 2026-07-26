import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFFF8FAFC),
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: .12),
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
