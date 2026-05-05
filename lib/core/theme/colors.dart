import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundCard = Color(0xFFFFFFFF);
  
  // Primaries (Premium Emerald focus)
  static const Color primaryEmerald = Color(0xFF00897B); // Deep Teal
  static const Color primaryMint = Color(0xFF00BFA5);    // Vibrant Emerald
  static const Color primaryAccent = Color(0xFF1DE9B6);  // Light Cyan/Mint

  // Secondary
  static const Color secondaryNavy = Color(0xFF102A2D); // Darker Teal-Navy
  static const Color secondaryGray = Color(0xFF455A64);

  // Text
  static const Color textPrimary = Color(0xFF102A2D);
  static const Color textSecondary = Color(0xFF455A64);
  static const Color textTertiary = Color(0xFF78909C);

  // Border & Accents
  static const Color borderColor = Color(0xFFE0F2F1); // Very light teal border
  static const Color focusColor = Color(0xFF00BFA5);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryEmerald, primaryMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundLight, Colors.white, Color(0xFFE0F2F1)],
  );

  static BoxDecoration emeraldGlow(double intensity) => BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: primaryMint.withOpacity(0.3 * intensity),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      );
}
