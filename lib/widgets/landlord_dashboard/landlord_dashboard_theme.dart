import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Corporate-tech palette for the landlord command center.
abstract final class LandlordDashboardTheme {
  static const canvas = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE9ECEF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const accent = AppColors.accent;

  static const soundTint = Color(0xFF0F766E);
  static const grandTint = Color(0xFF2563EB);
  static const justLandedTint = Color(0xFF7C3AED);
  static const commuteTint = Color(0xFFF1F5F9);

  static TextStyle sectionTitle({double size = 20}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.4,
        height: 1.2,
      );

  static TextStyle cardValue({double size = 28}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.6,
        height: 1.1,
      );

  static TextStyle cardLabel() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.1,
        height: 1.25,
      );

  static TextStyle cardSubtext() => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textMuted,
        height: 1.35,
      );

  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.55) : border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
