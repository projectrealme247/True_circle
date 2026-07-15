import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Legacy token layer — maps to [AppColors] for existing screens.
abstract final class HomeMarketplaceTheme {
  static const canvas = AppColors.background;
  static const surface = AppColors.surface;
  static const searchSurface = AppColors.background;
  static const border = AppColors.divider;
  static const borderStrong = AppColors.disabled;

  static const primary = AppColors.accent;
  static const primaryHover = AppColors.accentDark;
  static const primarySurface = AppColors.background;

  static const accent = AppColors.accent;
  static const accentHover = AppColors.accentDark;
  static const accentSurface = AppColors.accentLight;

  static const textPrimary = AppColors.primaryText;
  static const textSecondary = AppColors.secondaryText;
  static const textMuted = AppColors.secondaryText;
  static const gray500 = AppColors.secondaryText;

  static const cta = primary;
  static const onPrimary = AppColors.surface;

  static const cardRadius = AppRadius.lg;

  static const listingCardImageAspectRatio = 4 / 3;

  static List<BoxShadow> get cardShadowRest => AppShadows.card;

  static List<BoxShadow> get cardShadowHover => AppShadows.elevated;

  static List<BoxShadow> get searchShadowSm => AppShadows.card;

  static const searchBlockMaxWidth = 896.0;
  static const searchBlockRadius = AppRadius.lg;

  static const heroHeadline = 'Find people and places that fit.';
  static const heroSubheadline = 'Matched by lifestyle, timing and trust.';

  /// Legacy alias — homepage hero uses [heroSubheadline].
  static const brandTagline = heroSubheadline;

  static BoxDecoration cardDecoration({bool elevated = true}) =>
      AppTheme.cardDecoration(elevated: elevated);

  static ListingTagTone tagToneFor(String propertyType) =>
      switch (propertyType) {
        'Buy' => ListingTagTone.buy,
        'Share' => ListingTagTone.share,
        _ => ListingTagTone.rent,
      };

  static const trustCircle = AppColors.accent;
  static const trustIdVerified = AppColors.success;
  static const trustSocialVerified = AppColors.trustMuted;
  static const trustCasual = AppColors.divider;
  static const trustAnonymous = AppColors.background;
}

final class ListingTagTone {
  const ListingTagTone({
    required this.surface,
    required this.border,
    required this.text,
  });

  final Color surface;
  final Color border;
  final Color text;

  static const rent = ListingTagTone(
    surface: Color(0xFFE6F7F5),
    border: Color(0xFFBCE8DB),
    text: Color(0xFF008A7A),
  );

  static const buy = ListingTagTone(
    surface: Color(0xFFF6F5F8),
    border: Color(0xFFE8E4EC),
    text: Color(0xFF6B6574),
  );

  static const share = ListingTagTone(
    surface: Color(0xFFFAF7F4),
    border: Color(0xFFEAE4DE),
    text: Color(0xFF7A6F66),
  );
}
