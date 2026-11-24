import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// Ambient radial glow background wrapped in [RepaintBoundary] that gently
/// shifts to an arctic-cyan stealth tint when [isGhostMode] is enabled.
class AmbientCosmicBackground extends StatelessWidget {
  const AmbientCosmicBackground({
    super.key,
    required this.child,
    this.isGhostMode = false,
  });

  final Widget child;
  final bool isGhostMode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final isDark = tokens.preset.isDark;

    final primaryGlow = isGhostMode
        ? tokens.ghostGlowColor
        : tokens.ambientGlowPrimary;
    final secondaryGlow = isGhostMode
        ? tokens.accentSecondary
        : tokens.ambientGlowSecondary;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.backgroundTop, tokens.backgroundBottom],
              ),
            ),
            child: tokens.isAmoled && !isGhostMode
                ? const SizedBox.expand()
                : CustomPaint(
                    painter: _CosmicGlowPainter(
                      primary: withAlphaFraction(
                        primaryGlow,
                        isDark ? (isGhostMode ? 0.24 : 0.36) : 0.45,
                      ),
                      secondary: withAlphaFraction(
                        secondaryGlow,
                        isDark ? 0.22 : 0.35,
                      ),
                      tertiary: withAlphaFraction(
                        tokens.ambientGlowTertiary,
                        isDark ? 0.16 : 0.28,
                      ),
                    ),
                  ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CosmicGlowPainter extends CustomPainter {
  const _CosmicGlowPainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    final topCenter = Offset(size.width * 0.5, size.height * 0.14);
    final topRadius = size.width * 0.85;
    canvas.drawCircle(
      topCenter,
      topRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [primary, Colors.transparent],
        ).createShader(Rect.fromCircle(center: topCenter, radius: topRadius)),
    );

    final midRight = Offset(size.width * 0.85, size.height * 0.48);
    final midRadius = size.width * 0.7;
    canvas.drawCircle(
      midRight,
      midRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [secondary, Colors.transparent],
        ).createShader(Rect.fromCircle(center: midRight, radius: midRadius)),
    );

    final bottomLeft = Offset(size.width * 0.15, size.height * 0.88);
    final bottomRadius = size.width * 0.65;
    canvas.drawCircle(
      bottomLeft,
      bottomRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [tertiary, Colors.transparent],
        ).createShader(
          Rect.fromCircle(center: bottomLeft, radius: bottomRadius),
        ),
    );
  }

  @override
  bool shouldRepaint(_CosmicGlowPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.tertiary != tertiary;
  }
}
