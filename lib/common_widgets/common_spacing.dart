import 'package:flutter/material.dart';
import '../core/constants/app_spacing.dart';

class CommonSpacing extends StatelessWidget {
  final double size;
  final bool horizontal;

  const CommonSpacing.xs({super.key})
      : size = AppSpacing.xs,
        horizontal = false;
  const CommonSpacing.sm({super.key})
      : size = AppSpacing.sm,
        horizontal = false;
  const CommonSpacing.md({super.key})
      : size = AppSpacing.md,
        horizontal = false;
  const CommonSpacing.lg({super.key})
      : size = AppSpacing.lg,
        horizontal = false;
  const CommonSpacing.xl({super.key})
      : size = AppSpacing.xl,
        horizontal = false;
  const CommonSpacing.xxl({super.key})
      : size = AppSpacing.xxl,
        horizontal = false;

  const CommonSpacing.hXs({super.key})
      : size = AppSpacing.xs,
        horizontal = true;
  const CommonSpacing.hSm({super.key})
      : size = AppSpacing.sm,
        horizontal = true;
  const CommonSpacing.hMd({super.key})
      : size = AppSpacing.md,
        horizontal = true;
  const CommonSpacing.hLg({super.key})
      : size = AppSpacing.lg,
        horizontal = true;
  const CommonSpacing.hXl({super.key})
      : size = AppSpacing.xl,
        horizontal = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: horizontal ? size : null,
      height: horizontal ? null : size,
    );
  }
}
