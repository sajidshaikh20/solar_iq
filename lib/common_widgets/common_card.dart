import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CommonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? activeColor;
  final bool isActive;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const CommonCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.activeColor,
    this.isActive = false,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTheme.radiusXLarge;
    final decoration = isActive && activeColor != null
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: activeColor!.withOpacity(0.08),
            border: Border.all(color: activeColor!.withOpacity(0.35), width: 1.2),
          )
        : AppTheme.glassCard;

    final resolvedShadows = shadows ??
        (isActive && activeColor != null
            ? [
                BoxShadow(
                  color: activeColor!.withOpacity(0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ]
            : []);

    final finalDecoration = decoration.copyWith(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: resolvedShadows,
    );

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: finalDecoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
