import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_marketplace_theme.dart';

/// Inter-based type scale — modern product UI with teal accent.
abstract final class AppTypography {
  static const gray500 = Color(0xFF64748B);

  static const double textXs = 12;
  static const double textSm = 14;
  static const double textBase = 15;
  static const double textMd = 16;
  static const double textLg = 18;
  static const double textXl = 20;
  static const double text2xl = 24;
  static const double text3xl = 30;
  static const double text4xl = 36;

  static TextTheme interTextTheme(TextTheme base) =>
      GoogleFonts.interTextTheme(base);

  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double height = 1.35,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Hero headline (product statement).
  static TextStyle heroTitle() => _inter(
        fontSize: text4xl,
        fontWeight: FontWeight.w700,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.15,
        letterSpacing: -0.6,
      );

  /// Hero supporting line — text-lg.
  static TextStyle heroSubtitle() => _inter(
        fontSize: textLg,
        fontWeight: FontWeight.w400,
        color: gray500,
        height: 1.55,
      );

  /// Smaller display titles (empty states, etc.).
  static TextStyle displayTitle({double size = text3xl}) => _inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.25,
        letterSpacing: -0.4,
      );

  /// Supporting line under display titles.
  static TextStyle displaySubtitle() => _inter(
        fontSize: textBase,
        fontWeight: FontWeight.w400,
        color: gray500,
        height: 1.5,
      );

  /// Section headings (e.g. Marketplace).
  static TextStyle sectionTitle() => _inter(
        fontSize: textXl,
        fontWeight: FontWeight.w600,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.3,
        letterSpacing: -0.2,
      );

  /// Section meta / counts.
  static TextStyle sectionMeta() => detail();

  /// Listing card title — medium weight, soft.
  static TextStyle cardTitle() => _inter(
        fontSize: textSm,
        fontWeight: FontWeight.w500,
        color: HomeMarketplaceTheme.textSecondary,
        height: 1.35,
        letterSpacing: -0.1,
      );

  /// Listing price — bold hero emphasis.
  static TextStyle cardPrice() => _inter(
        fontSize: textMd,
        fontWeight: FontWeight.w700,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.25,
        letterSpacing: -0.2,
      );

  /// Location, host, match reasons — text-sm gray-500.
  static TextStyle detail() => _inter(
        fontSize: textSm,
        fontWeight: FontWeight.w400,
        color: gray500,
        height: 1.4,
      );

  /// Small metadata (match overlay, compact labels).
  static TextStyle meta() => _inter(
        fontSize: textXs,
        fontWeight: FontWeight.w400,
        color: gray500,
        height: 1.35,
      );

  /// Property / food / occupant tags — text-xs.
  static TextStyle tag({Color? color}) => _inter(
        fontSize: textXs,
        fontWeight: FontWeight.w500,
        color: color ?? gray500,
        height: 1.2,
      );

  /// Tower tab labels inside the search block.
  static TextStyle searchTabLabel({required bool selected}) => _inter(
        fontSize: textLg,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? Colors.white : HomeMarketplaceTheme.textSecondary,
        height: 1.2,
      );

  /// Compact tabs (legacy / secondary use).
  static TextStyle tabLabel({required bool selected}) => _inter(
        fontSize: textSm,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected
            ? HomeMarketplaceTheme.primary
            : HomeMarketplaceTheme.textSecondary,
        height: 1.2,
      );

  /// Prominent search field text.
  static TextStyle searchInputProminent() => _inter(
        fontSize: textMd,
        fontWeight: FontWeight.w400,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.3,
      );

  /// Search field input.
  static TextStyle searchInput() => _inter(
        fontSize: textBase,
        fontWeight: FontWeight.w400,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.3,
      );

  static TextStyle searchHint() => _inter(
        fontSize: textMd,
        fontWeight: FontWeight.w400,
        color: HomeMarketplaceTheme.textMuted,
        height: 1.3,
      );

  /// Primary buttons.
  static TextStyle button() => _inter(
        fontSize: textBase,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.2,
      );

  /// App bar brand.
  static TextStyle appBarBrand() => _inter(
        fontSize: textLg,
        fontWeight: FontWeight.w600,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.2,
        letterSpacing: -0.2,
      );

  /// Status / accent line (signed-in banner).
  static TextStyle statusAccent() => _inter(
        fontSize: textSm,
        fontWeight: FontWeight.w500,
        color: HomeMarketplaceTheme.primary,
        height: 1.35,
      );

  /// Dropdown group labels.
  static TextStyle suggestionGroup() => _inter(
        fontSize: textXs,
        fontWeight: FontWeight.w600,
        color: HomeMarketplaceTheme.primary,
        height: 1.2,
        letterSpacing: 0.1,
      );

  static TextStyle suggestionItem() => _inter(
        fontSize: textSm,
        fontWeight: FontWeight.w500,
        color: HomeMarketplaceTheme.textPrimary,
        height: 1.3,
      );

  static TextStyle suggestionCaption() => _inter(
        fontSize: textXs,
        fontWeight: FontWeight.w500,
        color: HomeMarketplaceTheme.textMuted,
        height: 1.2,
        letterSpacing: 0.15,
      );
}
