import 'package:flutter/material.dart';

import 'app_theme_mode.dart';
import 'app_theme_tokens.dart';

/// Builds a complete [ThemeData] configured for bundled Vazirmatn RTL typography,
/// JetBrains Mono code blocks, and smooth [AnimatedTheme] transitions.
class AppThemeBuilder {
  const AppThemeBuilder._();

  static const String persianFontFamily = 'Vazirmatn';
  static const String monoFontFamily = 'JetBrainsMono';

  static ThemeData build({
    required AppThemePreset preset,
    double fontScale = 1.0,
  }) {
    final tokens = OrbiThemeTokens.forPreset(preset);
    final brightness = preset.isDark ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accentPrimary,
      onPrimary: tokens.sendButtonFg,
      secondary: tokens.accentSecondary,
      onSecondary: tokens.sendButtonFg,
      error: tokens.dangerColor,
      onError: Colors.white,
      surface: tokens.surfaceBase,
      onSurface: tokens.textPrimary,
      surfaceContainerHighest: tokens.surfaceElevated,
      outline: tokens.strokeTopLeft,
    );

    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
          fontFamily: persianFontFamily,
          bodyColor: tokens.textPrimary,
          displayColor: tokens.textPrimary,
        );

    final scaledBody = 15.0 * fontScale;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: persianFontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.backgroundTop,
      canvasColor: tokens.surfaceBase,
      splashFactory: InkSparkle.splashFactory,
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.35,
          letterSpacing: -0.2,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 19 * fontScale,
          height: 1.45,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16 * fontScale,
          height: 1.5,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: scaledBody,
          fontWeight: FontWeight.w400,
          height: 1.72,
          color: tokens.textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.w400,
          height: 1.68,
          color: tokens.textSecondary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12.5 * fontScale,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: tokens.textMuted,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13.5 * fontScale,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: tokens.textPrimary,
        centerTitle: true,
      ),
      dividerColor: withAlphaFraction(tokens.textMuted, 0.16),
      iconTheme: IconThemeData(color: tokens.textPrimary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceElevated,
        contentTextStyle: TextStyle(
          fontFamily: persianFontFamily,
          color: tokens.textPrimary,
          fontSize: 13.5,
          height: 1.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      extensions: [tokens],
    );
  }
}
