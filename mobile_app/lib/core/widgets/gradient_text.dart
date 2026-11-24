import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// Renders glowing gradient headlines using [ShaderMask] (`#60A5FA` ->
/// `#A78BFA` -> `#C084FC` in Cosmic Glass).
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.colors,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    final palette = colors ?? tokens.titleGradient;

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: palette,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? Theme.of(context).textTheme.headlineMedium)?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}
