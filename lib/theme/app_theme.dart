import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

export '../core/theme/app_theme.dart';

/// Backward-compatible aliases for widgets migrated from the prior theme API.
abstract final class TrueCircleColors {
  static const background = AppColors.background;
  static const surface = AppColors.surface;
  static const textPrimary = AppColors.primaryText;
  static const textSecondary = AppColors.secondaryText;
  static const accent = AppColors.accent;
  static const accentHover = AppColors.accentDark;
  static const onAccent = AppColors.surface;
  static const border = AppColors.divider;
  static const borderStrong = AppColors.disabled;
  static const tagSurface = AppColors.background;
}

abstract final class TrueCircleTheme {
  static ThemeData light() => AppTheme.light;

  static const double cardRadius = AppRadius.lg;

  static BoxDecoration cardDecoration({
    Color color = AppColors.surface,
    double radius = AppRadius.lg,
    bool elevated = true,
  }) =>
      AppTheme.cardDecoration(color: color, radius: radius, elevated: elevated);

  static List<BoxShadow> get cardShadowHover => AppShadows.elevated;

  static TextStyle displayTitle({double fontSize = 22}) =>
      AppTypography.h2.copyWith(fontSize: fontSize);

  static TextStyle sectionHeading({double fontSize = 18}) =>
      AppTypography.h2.copyWith(fontSize: fontSize);

  static TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.secondaryText,
  }) =>
      AppTypography.body.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextStyle metaTag({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.secondaryText,
  }) =>
      AppTypography.caption.copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextStyle buttonLabel() => AppTypography.button;
}
