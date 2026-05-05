import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';

enum TextVariant {
  displayLarge,
  displayMedium,
  headingLarge,
  headingMedium,
  headingSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  caption,
}

class CommonText extends StatelessWidget {
  final String text;
  final TextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? fontSize;
  final FontWeight? fontWeight;

  const CommonText(
    this.text, {
    super.key,
    this.variant = TextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontSize,
    this.fontWeight,
  });

  TextStyle _resolveStyle() {
    TextStyle base;
    switch (variant) {
      case TextVariant.displayLarge:
        base = AppTextStyles.displayLarge;
      case TextVariant.displayMedium:
        base = AppTextStyles.displayMedium;
      case TextVariant.headingLarge:
        base = AppTextStyles.headingLarge;
      case TextVariant.headingMedium:
        base = AppTextStyles.headingMedium;
      case TextVariant.headingSmall:
        base = AppTextStyles.headingSmall;
      case TextVariant.bodyLarge:
        base = AppTextStyles.bodyLarge;
      case TextVariant.bodyMedium:
        base = AppTextStyles.bodyMedium;
      case TextVariant.bodySmall:
        base = AppTextStyles.bodySmall;
      case TextVariant.labelLarge:
        base = AppTextStyles.labelLarge;
      case TextVariant.labelMedium:
        base = AppTextStyles.labelMedium;
      case TextVariant.caption:
        base = AppTextStyles.caption;
    }
    return base.copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _resolveStyle(),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class CommonTextAccent extends StatelessWidget {
  final String text;
  final Color color;
  final double? fontSize;
  final FontWeight fontWeight;

  const CommonTextAccent(
    this.text, {
    super.key,
    this.color = AppColors.primaryEmerald,
    this.fontSize,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight,
        letterSpacing: 0.2,
      ),
    );
  }
}
