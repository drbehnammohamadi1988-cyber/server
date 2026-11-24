import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// Adaptive, zero-jank surface container supporting Refined Glassmorphism,
/// Dark/Light Neumorphism (convex and concave), Pure AMOLED, and Frost Light.
///
/// By default [useBackdropBlur] is `false` so scrollable list items never
/// trigger expensive per-item `BackdropFilter` passes. Enable [useBackdropBlur]
/// only for fixed chrome (floating composer, top bar, sheets, drawer).
class OrbiSurface extends StatelessWidget {
  const OrbiSurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding,
    this.margin,
    this.useBackdropBlur = false,
    this.reducedBlur = false,
    this.concave = false,
    this.blurSigma = 14,
    this.tintOverride,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool useBackdropBlur;
  final bool reducedBlur;
  final bool concave;
  final double blurSigma;
  final Color? tintOverride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final radius = BorderRadius.circular(borderRadius);
    final shouldBlur =
        useBackdropBlur && !reducedBlur && tokens.isGlass && !tokens.isAmoled;

    Widget content = _buildDecoratedSurface(tokens, radius);

    if (shouldBlur) {
      final sigma = blurSigma.clamp(8.0, 16.0);
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return RepaintBoundary(child: content);
  }

  Widget _buildDecoratedSurface(OrbiThemeTokens tokens, BorderRadius radius) {
    if (tokens.isNeumorphic) {
      return _buildNeumorphicSurface(tokens, radius);
    }
    return _buildGlassOrAmoledSurface(tokens, radius);
  }

  Widget _buildNeumorphicSurface(OrbiThemeTokens tokens, BorderRadius radius) {
    final isDark = tokens.preset.isDark;
    final baseColor = tintOverride ??
        (concave ? tokens.backgroundTop : tokens.surfaceElevated);

    final shadows = concave
        ? [
            BoxShadow(
              color: withAlphaFraction(tokens.neuDarkShadow, isDark ? 0.85 : 0.7),
              offset: const Offset(2, 2),
              blurRadius: 5,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: withAlphaFraction(tokens.neuLightShadow, isDark ? 0.5 : 0.85),
              offset: const Offset(-2, -2),
              blurRadius: 5,
              spreadRadius: -2,
            ),
          ]
        : [
            BoxShadow(
              color: withAlphaFraction(tokens.neuDarkShadow, isDark ? 0.9 : 0.75),
              offset: const Offset(5, 5),
              blurRadius: 12,
            ),
            BoxShadow(
              color: withAlphaFraction(tokens.neuLightShadow, isDark ? 0.9 : 0.95),
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
          ];

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: radius,
        border: Border.all(
          color: concave
              ? withAlphaFraction(tokens.accentPrimary, 0.18)
              : withAlphaFraction(tokens.strokeTopLeft, isDark ? 0.12 : 0.7),
          width: 1,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );
  }

  Widget _buildGlassOrAmoledSurface(
      OrbiThemeTokens tokens, BorderRadius radius) {
    final isLight = !tokens.preset.isDark;
    final baseGradient = tintOverride != null
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              withAlphaFraction(tintOverride!, 0.22),
              withAlphaFraction(tintOverride!, 0.09),
            ],
          )
        : tokens.isAmoled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.surfaceElevated,
                  tokens.surfaceBase,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? [
                        withAlphaFraction(Colors.white, 0.76),
                        withAlphaFraction(tokens.glassTint, 0.08),
                      ]
                    : [
                        withAlphaFraction(Colors.white, 0.085),
                        withAlphaFraction(tokens.glassTint, 0.08),
                      ],
              );

    return CustomPaint(
      painter: _LuminousStrokePainter(
        borderRadius: borderRadius,
        topLeftColor: tokens.strokeTopLeft,
        bottomRightColor: tokens.strokeBottomRight,
        strokeWidth: tokens.isAmoled ? 1.15 : 1.0,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: baseGradient,
          boxShadow: tokens.isAmoled
              ? null
              : [
                  BoxShadow(
                    color: withAlphaFraction(
                      tokens.neuDarkShadow,
                      isLight ? 0.12 : 0.35,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

class _LuminousStrokePainter extends CustomPainter {
  const _LuminousStrokePainter({
    required this.borderRadius,
    required this.topLeftColor,
    required this.bottomRightColor,
    required this.strokeWidth,
  });

  final double borderRadius;
  final Color topLeftColor;
  final Color bottomRightColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topLeftColor, bottomRightColor],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_LuminousStrokePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.topLeftColor != topLeftColor ||
        oldDelegate.bottomRightColor != bottomRightColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
