import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart' as core;

/// Marketplace typography helpers — delegates to core [core.AppTypography].
abstract final class AppTypography {
  static const gray500 = core.AppColors.secondaryText;

  static const double textXs = 12;
  static const double textSm = 14;
  static const double textBase = 15;
  static const double textMd = 16;
  static const double textLg = 18;
  static const double textXl = 20;
  static const double text2xl = 24;
  static const double text3xl = 30;
  static const double text4xl = 36;

  static TextTheme textTheme(TextTheme base) => core.AppTheme.light.textTheme;

  static TextStyle heroTitle() =>
      core.AppTypography.h1.copyWith(fontSize: text4xl);

  static TextStyle heroSubtitle() => core.AppTypography.bodySecondary;

  static TextStyle displayTitle({double size = text3xl}) =>
      core.AppTypography.h1.copyWith(fontSize: size);

  static TextStyle displaySubtitle() => core.AppTypography.bodySecondary;

  static TextStyle sectionTitle() =>
      core.AppTypography.h2.copyWith(fontSize: textXl);

  static TextStyle sectionMeta() => detail();

  static TextStyle cardTitle() =>
      core.AppTypography.bodySecondary.copyWith(fontSize: textSm);

  static TextStyle cardPrice() =>
      core.AppTypography.h3.copyWith(fontSize: textMd);

  static TextStyle detail() => core.AppTypography.caption.copyWith(
        fontSize: textSm,
        fontWeight: FontWeight.w400,
      );

  static TextStyle meta() => core.AppTypography.caption;

  static TextStyle tag({Color? color}) =>
      core.AppTypography.caption.copyWith(color: color ?? gray500);

  static TextStyle searchTabLabel({required bool selected}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: textSm,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? core.AppColors.surface : core.AppColors.secondaryText,
      );

  static TextStyle tabLabel({required bool selected}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: textSm,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? core.AppColors.accent : core.AppColors.secondaryText,
      );

  static TextStyle searchInputProminent() =>
      core.AppTypography.body.copyWith(fontSize: textMd);

  static TextStyle searchInput() =>
      core.AppTypography.body.copyWith(fontSize: textBase);

  static TextStyle searchHint() => core.AppTypography.bodySecondary.copyWith(
        fontSize: textMd,
      );

  static TextStyle button() => core.AppTypography.button;

  static TextStyle appBarBrand() => core.AppTypography.h2;

  static TextStyle statusAccent() => core.AppTypography.link.copyWith(
        fontSize: textSm,
        fontWeight: FontWeight.w500,
      );

  static TextStyle suggestionGroup() => core.AppTypography.caption.copyWith(
        fontWeight: FontWeight.w600,
      );

  static TextStyle suggestionItem() =>
      core.AppTypography.body.copyWith(fontSize: textSm);

  static TextStyle suggestionCaption() => core.AppTypography.caption;
}
