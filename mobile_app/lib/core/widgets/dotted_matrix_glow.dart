import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';
import 'surface_container.dart';

/// Luminous Dotted-Matrix progress card displayed while Orbi AI constructs a
/// downloadable document, web preview, or structured artifact.
class DottedMatrixGlowCard extends StatefulWidget {
  const DottedMatrixGlowCard({
    super.key,
    this.title = 'در حال ساخت فایل و سند اختصاصی شما...',
    this.subtitle = 'ساختاردهی محتوا و آماده‌سازی خروجی باکیفیت',
    this.reducedBlur = false,
  });

  final String title;
  final String subtitle;
  final bool reducedBlur;

  @override
  State<DottedMatrixGlowCard> createState() => _DottedMatrixGlowCardState();
}

class _DottedMatrixGlowCardState extends State<DottedMatrixGlowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return OrbiSurface(
      borderRadius: 20,
      reducedBlur: widget.reducedBlur,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _DottedMatrixPainter(
                        progress: _controller.value,
                        dotColor: tokens.accentPrimary,
                        secondaryColor: tokens.accentSecondary,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation(tokens.accentPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 14.5,
                                    color: tokens.textPrimary,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DottedMatrixPainter extends CustomPainter {
  const _DottedMatrixPainter({
    required this.progress,
    required this.dotColor,
    required this.secondaryColor,
  });

  final double progress;
  final Color dotColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 14.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();
    final sweepX = progress * (size.width + 80) - 40;

    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        final x = c * spacing + 7;
        final y = r * spacing + 7;
        final dist = (x - sweepX).abs();
        final wave = math.max(0.0, 1.0 - (dist / 90.0));
        final alpha = 0.08 + wave * 0.42;
        final color = Color.lerp(dotColor, secondaryColor, wave)!;
        canvas.drawCircle(
          Offset(x, y),
          1.15 + wave * 1.15,
          Paint()..color = withAlphaFraction(color, alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DottedMatrixPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dotColor != dotColor;
}
