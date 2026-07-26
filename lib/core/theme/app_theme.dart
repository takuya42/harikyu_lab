import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/constants/app_constants.dart';
import 'package:harikyu_lab/core/theme/app_theme_extension.dart';

abstract final class AppTheme {
  static const _blue = Color(0xFF246BFD);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xFFF7F9FC),
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: Color(0xFF172033), fontSize: 22, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.cardRadius)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE7EFFF),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? _blue : const Color(0xFF687386),
      )),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.controlRadius)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    )),
    dividerTheme: const DividerThemeData(color: Color(0xFFE9EDF3), thickness: 1),
    splashFactory: InkSparkle.splashFactory,
    extensions: const [AppSurfaceTheme(
      subtle: Color(0xFFF1F5FB), success: Color(0xFF19A974), warning: Color(0xFFFFA928),
    )],
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
