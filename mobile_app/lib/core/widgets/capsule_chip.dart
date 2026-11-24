import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';
import 'surface_container.dart';

/// Capsule (`borderRadius: 999`) interactive chip for quick starter actions
/// and capability badges.
class CapsuleChip extends StatelessWidget {
  const CapsuleChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.reducedBlur = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool reducedBlur;

  @override
  Widget build(BuildContext context) {
    final tokens = context.orbiTokens;
    return OrbiSurface(
      borderRadius: 999,
      reducedBlur: reducedBlur,
      tintOverride: selected ? tokens.accentPrimary : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? tokens.textPrimary : tokens.accentPrimary,
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.textPrimary,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}
