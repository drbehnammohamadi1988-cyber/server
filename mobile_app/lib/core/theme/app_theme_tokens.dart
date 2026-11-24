import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme_mode.dart';

/// Custom visual tokens powering Glassmorphism, Dark/Light Neumorphism,
/// Pure AMOLED, and Frost Light without duplicating widget styling.
@immutable
class OrbiThemeTokens extends ThemeExtension<OrbiThemeTokens> {
  const OrbiThemeTokens({
    required this.preset,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.ambientGlowPrimary,
    required this.ambientGlowSecondary,
    required this.ambientGlowTertiary,
    required this.ghostGlowColor,
    required this.surfaceBase,
    required this.surfaceElevated,
    required this.glassTint,
    required this.strokeTopLeft,
    required this.strokeBottomRight,
    required this.neuLightShadow,
    required this.neuDarkShadow,
    required this.isNeumorphic,
    required this.isGlass,
    required this.isAmoled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.titleGradient,
    required this.sendButtonBg,
    required this.sendButtonFg,
    required this.userBubbleBg,
    required this.aiBubbleBg,
    required this.codeBg,
    required this.codeHeaderBg,
    required this.successColor,
    required this.warningColor,
    required this.dangerColor,
  });

  final AppThemePreset preset;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color ambientGlowPrimary;
  final Color ambientGlowSecondary;
  final Color ambientGlowTertiary;
  final Color ghostGlowColor;
  final Color surfaceBase;
  final Color surfaceElevated;
  final Color glassTint;
  final Color strokeTopLeft;
  final Color strokeBottomRight;
  final Color neuLightShadow;
  final Color neuDarkShadow;
  final bool isNeumorphic;
  final bool isGlass;
  final bool isAmoled;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentPrimary;
  final Color accentSecondary;
  final List<Color> titleGradient;
  final Color sendButtonBg;
  final Color sendButtonFg;
  final Color userBubbleBg;
  final Color aiBubbleBg;
  final Color codeBg;
  final Color codeHeaderBg;
  final Color successColor;
  final Color warningColor;
  final Color dangerColor;

  static OrbiThemeTokens forPreset(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.cosmicGlass:
        return const OrbiThemeTokens(
          preset: AppThemePreset.cosmicGlass,
          backgroundTop: Color(0xFF06060C),
          backgroundBottom: Color(0xFF0B0A16),
          ambientGlowPrimary: Color(0xFF2E1065),
          ambientGlowSecondary: Color(0xFF4C1D95),
          ambientGlowTertiary: Color(0xFF6D28D9),
          ghostGlowColor: Color(0xFF0EA5E9),
          surfaceBase: Color(0xFF121022),
          surfaceElevated: Color(0xFF19162D),
          glassTint: Color(0xFF7C3AED),
          strokeTopLeft: Color(0x3DF5F3FF), // ~0.24 white/lilac
          strokeBottomRight: Color(0x0A7C3AED), // ~0.04 violet
          neuLightShadow: Color(0x18FFFFFF),
          neuDarkShadow: Color(0x66020206),
          isNeumorphic: false,
          isGlass: true,
          isAmoled: false,
          textPrimary: Color(0xFFF8FAFC),
          textSecondary: Color(0xFFCBD5E1),
          textMuted: Color(0xFF94A3B8),
          accentPrimary: Color(0xFFA78BFA),
          accentSecondary: Color(0xFF60A5FA),
          titleGradient: [
            Color(0xFF60A5FA),
            Color(0xFFA78BFA),
            Color(0xFFC084FC),
          ],
          sendButtonBg: Color(0xFFF8FAFC),
          sendButtonFg: Color(0xFF090912),
          userBubbleBg: Color(0x2B7C3AED),
          aiBubbleBg: Color(0x14FFFFFF),
          codeBg: Color(0xFF0A0A14),
          codeHeaderBg: Color(0xFF151328),
          successColor: Color(0xFF34D399),
          warningColor: Color(0xFFFBBF24),
          dangerColor: Color(0xFFFB7185),
        );

      case AppThemePreset.darkNeumorphism:
        return const OrbiThemeTokens(
          preset: AppThemePreset.darkNeumorphism,
          backgroundTop: Color(0xFF14161F),
          backgroundBottom: Color(0xFF171A25),
          ambientGlowPrimary: Color(0xFF1F2437),
          ambientGlowSecondary: Color(0xFF241B40),
          ambientGlowTertiary: Color(0xFF182A3A),
          ghostGlowColor: Color(0xFF22D3EE),
          surfaceBase: Color(0xFF1A1D29),
          surfaceElevated: Color(0xFF202433),
          glassTint: Color(0xFF818CF8),
          strokeTopLeft: Color(0x1AFFFFFF),
          strokeBottomRight: Color(0x28000000),
          neuLightShadow: Color(0xFF232736),
          neuDarkShadow: Color(0xFF0B0C12),
          isNeumorphic: true,
          isGlass: false,
          isAmoled: false,
          textPrimary: Color(0xFFF1F5F9),
          textSecondary: Color(0xFFCBD5E1),
          textMuted: Color(0xFF8892A8),
          accentPrimary: Color(0xFF818CF8),
          accentSecondary: Color(0xFF38BDF8),
          titleGradient: [
            Color(0xFF38BDF8),
            Color(0xFF818CF8),
            Color(0xFFC084FC),
          ],
          sendButtonBg: Color(0xFF818CF8),
          sendButtonFg: Color(0xFF0B0C12),
          userBubbleBg: Color(0xFF222738),
          aiBubbleBg: Color(0xFF1A1D29),
          codeBg: Color(0xFF10121A),
          codeHeaderBg: Color(0xFF181B27),
          successColor: Color(0xFF34D399),
          warningColor: Color(0xFFFBBF24),
          dangerColor: Color(0xFFFB7185),
        );

      case AppThemePreset.softCeramic:
        return const OrbiThemeTokens(
          preset: AppThemePreset.softCeramic,
          backgroundTop: Color(0xFFECEFF5),
          backgroundBottom: Color(0xFFE4E8F1),
          ambientGlowPrimary: Color(0xFFDDE3F5),
          ambientGlowSecondary: Color(0xFFE8DFF7),
          ambientGlowTertiary: Color(0xFFD6EAF8),
          ghostGlowColor: Color(0xFF0284C7),
          surfaceBase: Color(0xFFECEFF5),
          surfaceElevated: Color(0xFFF4F6FA),
          glassTint: Color(0xFF6366F1),
          strokeTopLeft: Color(0xCCFFFFFF),
          strokeBottomRight: Color(0x26A8B2C8),
          neuLightShadow: Color(0xFFFFFFFF),
          neuDarkShadow: Color(0xFFC6CEDD),
          isNeumorphic: true,
          isGlass: false,
          isAmoled: false,
          textPrimary: Color(0xFF0F172A),
          textSecondary: Color(0xFF334155),
          textMuted: Color(0xFF64748B),
          accentPrimary: Color(0xFF5B4EE6),
          accentSecondary: Color(0xFF2563EB),
          titleGradient: [
            Color(0xFF2563EB),
            Color(0xFF6D28D9),
            Color(0xFF9333EA),
          ],
          sendButtonBg: Color(0xFF1E1B4B),
          sendButtonFg: Color(0xFFFFFFFF),
          userBubbleBg: Color(0xFFE2E7F3),
          aiBubbleBg: Color(0xFFF5F7FB),
          codeBg: Color(0xFFE6EAF3),
          codeHeaderBg: Color(0xFFDCE1EE),
          successColor: Color(0xFF059669),
          warningColor: Color(0xFFD97706),
          dangerColor: Color(0xFFE11D48),
        );

      case AppThemePreset.pureAmoled:
        return const OrbiThemeTokens(
          preset: AppThemePreset.pureAmoled,
          backgroundTop: Color(0xFF000000),
          backgroundBottom: Color(0xFF000000),
          ambientGlowPrimary: Color(0xFF3B0764),
          ambientGlowSecondary: Color(0xFF1E1B4B),
          ambientGlowTertiary: Color(0xFF0C4A6E),
          ghostGlowColor: Color(0xFF38BDF8),
          surfaceBase: Color(0xFF07070A),
          surfaceElevated: Color(0xFF0F0F16),
          glassTint: Color(0xFF8B5CF6),
          strokeTopLeft: Color(0x70A78BFA),
          strokeBottomRight: Color(0x2638BDF8),
          neuLightShadow: Color(0x228B5CF6),
          neuDarkShadow: Color(0xFF000000),
          isNeumorphic: false,
          isGlass: true,
          isAmoled: true,
          textPrimary: Color(0xFFFFFFFF),
          textSecondary: Color(0xFFE2E8F0),
          textMuted: Color(0xFF94A3B8),
          accentPrimary: Color(0xFFB794F4),
          accentSecondary: Color(0xFF38BDF8),
          titleGradient: [
            Color(0xFF38BDF8),
            Color(0xFFA78BFA),
            Color(0xFFE879F9),
          ],
          sendButtonBg: Color(0xFFFFFFFF),
          sendButtonFg: Color(0xFF000000),
          userBubbleBg: Color(0xFF130E24),
          aiBubbleBg: Color(0xFF09090F),
          codeBg: Color(0xFF050508),
          codeHeaderBg: Color(0xFF11111B),
          successColor: Color(0xFF34D399),
          warningColor: Color(0xFFFBBF24),
          dangerColor: Color(0xFFFB7185),
        );

      case AppThemePreset.frostLight:
        return const OrbiThemeTokens(
          preset: AppThemePreset.frostLight,
          backgroundTop: Color(0xFFF4F6FE),
          backgroundBottom: Color(0xFFEDE8FC),
          ambientGlowPrimary: Color(0xFFDDD6FE),
          ambientGlowSecondary: Color(0xFFBAE6FD),
          ambientGlowTertiary: Color(0xFFFBCFE8),
          ghostGlowColor: Color(0xFF0EA5E9),
          surfaceBase: Color(0xFFF8FAFF),
          surfaceElevated: Color(0xFFFFFFFF),
          glassTint: Color(0xFF8B5CF6),
          strokeTopLeft: Color(0xE6FFFFFF),
          strokeBottomRight: Color(0x3D8B5CF6),
          neuLightShadow: Color(0x99FFFFFF),
          neuDarkShadow: Color(0x2464748B),
          isNeumorphic: false,
          isGlass: true,
          isAmoled: false,
          textPrimary: Color(0xFF0F172A),
          textSecondary: Color(0xFF334155),
          textMuted: Color(0xFF64748B),
          accentPrimary: Color(0xFF7C3AED),
          accentSecondary: Color(0xFF2563EB),
          titleGradient: [
            Color(0xFF2563EB),
            Color(0xFF7C3AED),
            Color(0xFFDB2777),
          ],
          sendButtonBg: Color(0xFF4C1D95),
          sendButtonFg: Color(0xFFFFFFFF),
          userBubbleBg: Color(0x227C3AED),
          aiBubbleBg: Color(0xB8FFFFFF),
          codeBg: Color(0xFFEFF2FA),
          codeHeaderBg: Color(0xFFE2E7F6),
          successColor: Color(0xFF059669),
          warningColor: Color(0xFFD97706),
          dangerColor: Color(0xFFE11D48),
        );
    }
  }

  @override
  OrbiThemeTokens copyWith({
    AppThemePreset? preset,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? ambientGlowPrimary,
    Color? ambientGlowSecondary,
    Color? ambientGlowTertiary,
    Color? ghostGlowColor,
    Color? surfaceBase,
    Color? surfaceElevated,
    Color? glassTint,
    Color? strokeTopLeft,
    Color? strokeBottomRight,
    Color? neuLightShadow,
    Color? neuDarkShadow,
    bool? isNeumorphic,
    bool? isGlass,
    bool? isAmoled,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentPrimary,
    Color? accentSecondary,
    List<Color>? titleGradient,
    Color? sendButtonBg,
    Color? sendButtonFg,
    Color? userBubbleBg,
    Color? aiBubbleBg,
    Color? codeBg,
    Color? codeHeaderBg,
    Color? successColor,
    Color? warningColor,
    Color? dangerColor,
  }) {
    return OrbiThemeTokens(
      preset: preset ?? this.preset,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      ambientGlowPrimary: ambientGlowPrimary ?? this.ambientGlowPrimary,
      ambientGlowSecondary: ambientGlowSecondary ?? this.ambientGlowSecondary,
      ambientGlowTertiary: ambientGlowTertiary ?? this.ambientGlowTertiary,
      ghostGlowColor: ghostGlowColor ?? this.ghostGlowColor,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      glassTint: glassTint ?? this.glassTint,
      strokeTopLeft: strokeTopLeft ?? this.strokeTopLeft,
      strokeBottomRight: strokeBottomRight ?? this.strokeBottomRight,
      neuLightShadow: neuLightShadow ?? this.neuLightShadow,
      neuDarkShadow: neuDarkShadow ?? this.neuDarkShadow,
      isNeumorphic: isNeumorphic ?? this.isNeumorphic,
      isGlass: isGlass ?? this.isGlass,
      isAmoled: isAmoled ?? this.isAmoled,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      titleGradient: titleGradient ?? this.titleGradient,
      sendButtonBg: sendButtonBg ?? this.sendButtonBg,
      sendButtonFg: sendButtonFg ?? this.sendButtonFg,
      userBubbleBg: userBubbleBg ?? this.userBubbleBg,
      aiBubbleBg: aiBubbleBg ?? this.aiBubbleBg,
      codeBg: codeBg ?? this.codeBg,
      codeHeaderBg: codeHeaderBg ?? this.codeHeaderBg,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      dangerColor: dangerColor ?? this.dangerColor,
    );
  }

  @override
  OrbiThemeTokens lerp(ThemeExtension<OrbiThemeTokens>? other, double t) {
    if (other is! OrbiThemeTokens) return this;
    return OrbiThemeTokens(
      preset: t < 0.5 ? preset : other.preset,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom:
          Color.lerp(backgroundBottom, other.backgroundBottom, t)!,
      ambientGlowPrimary:
          Color.lerp(ambientGlowPrimary, other.ambientGlowPrimary, t)!,
      ambientGlowSecondary:
          Color.lerp(ambientGlowSecondary, other.ambientGlowSecondary, t)!,
      ambientGlowTertiary:
          Color.lerp(ambientGlowTertiary, other.ambientGlowTertiary, t)!,
      ghostGlowColor: Color.lerp(ghostGlowColor, other.ghostGlowColor, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      strokeTopLeft: Color.lerp(strokeTopLeft, other.strokeTopLeft, t)!,
      strokeBottomRight:
          Color.lerp(strokeBottomRight, other.strokeBottomRight, t)!,
      neuLightShadow: Color.lerp(neuLightShadow, other.neuLightShadow, t)!,
      neuDarkShadow: Color.lerp(neuDarkShadow, other.neuDarkShadow, t)!,
      isNeumorphic: t < 0.5 ? isNeumorphic : other.isNeumorphic,
      isGlass: t < 0.5 ? isGlass : other.isGlass,
      isAmoled: t < 0.5 ? isAmoled : other.isAmoled,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      titleGradient: [
        for (var i = 0; i < 3; i++)
          Color.lerp(
            titleGradient[i % titleGradient.length],
            other.titleGradient[i % other.titleGradient.length],
            t,
          )!,
      ],
      sendButtonBg: Color.lerp(sendButtonBg, other.sendButtonBg, t)!,
      sendButtonFg: Color.lerp(sendButtonFg, other.sendButtonFg, t)!,
      userBubbleBg: Color.lerp(userBubbleBg, other.userBubbleBg, t)!,
      aiBubbleBg: Color.lerp(aiBubbleBg, other.aiBubbleBg, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      codeHeaderBg: Color.lerp(codeHeaderBg, other.codeHeaderBg, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      dangerColor: Color.lerp(dangerColor, other.dangerColor, t)!,
    );
  }
}

extension OrbiThemeContextX on BuildContext {
  OrbiThemeTokens get orbiTokens =>
      Theme.of(this).extension<OrbiThemeTokens>() ??
      OrbiThemeTokens.forPreset(AppThemePreset.cosmicGlass);
}

/// Shared helper for smooth opacity modulation.
Color withAlphaFraction(Color color, double fraction) =>
    color.withValues(alpha: clampDouble(fraction, 0.0, 1.0));
