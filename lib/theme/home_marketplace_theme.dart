import 'package:flutter/material.dart';

/// CircleKey marketplace design: warm neutrals, sky blue + orange accent
/// for trust and community, generous spacing, clean typography.
abstract final class HomeMarketplaceTheme {
  static const canvas = Color(0xFFF7F8F8);
  static const surface = Color(0xFFFFFFFF);
  static const searchSurface = Color(0xFFF0F2F2);
  static const border = Color(0xFFD9E0E0);
  static const borderStrong = Color(0xFFAAB8B8);

  static const primary = Color(0xFF0EA5E9);
  static const primaryHover = Color(0xFF0284C7);
  static const primarySurface = Color(0xFFE0F2FE);

  static const accent = Color(0xFFF97316);
  static const accentHover = Color(0xFFEA580C);
  static const accentSurface = Color(0xFFFFF7ED);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const gray500 = Color(0xFF64748B);

  static const cta = accent;

  static const cardRadius = 16.0;

  static const listingCardImageAspectRatio = 4 / 3;

  static List<BoxShadow> get cardShadowRest => const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cardShadowHover => const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 20,
          offset: Offset(0, 8),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get searchShadowSm => const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 6,
          offset: Offset(0, 1),
          spreadRadius: 0,
        ),
      ];

  static const searchBlockMaxWidth = 896.0;
  static const searchBlockRadius = 16.0;

  static ListingTagTone tagToneFor(String propertyType) => switch (propertyType) {
        'Buy' => ListingTagTone.buy,
        'Share' => ListingTagTone.share,
        _ => ListingTagTone.rent,
      };

  // ── Trust stripe colors ────────────────────────────────────────

  static const trustCircle = Color(0xFF0EA5E9);
  static const trustIdVerified = Color(0xFF008A05);
  static const trustSocialVerified = Color(0xFF7C3AED);
  static const trustCasual = Color(0xFFDDDDDD);
  static const trustAnonymous = Color(0xFFE8E8E8);
}

/// Soft tag colors — not used for tabs, buttons, or card chrome.
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
    surface: Color(0xFFECFDF5),
    border: Color(0xFFBCE8DB),
    text: Color(0xFF0D7A70),
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
