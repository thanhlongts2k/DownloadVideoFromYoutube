import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF090D16);
  static const Color surface = Color(0xFF111726);
  static const Color surfaceLight = Color(0xFF1A2234);
  
  static const Color glassSurface = Color(0x331E293B);
  static const Color glassBorder = Color(0x3394A3B8);
  static const Color glassBorderGlow = Color(0x66FF0033);

  static const Color primary = Color(0xFFFF0033);
  static const Color primaryGradientEnd = Color(0xFFFF416C);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF1744);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFFF0033), Color(0xFFFF416C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00B4D8), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [
      Color(0x2E1E293B),
      Color(0x1A0F172A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
