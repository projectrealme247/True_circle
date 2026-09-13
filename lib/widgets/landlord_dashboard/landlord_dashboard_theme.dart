import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/landlord_recommendation_state.dart';

/// Executive landlord workspace — warm paper, colourful decision cues, coral for actions.
abstract final class LandlordDashboardTheme {
  static const canvas = Color(0xFFF3F0EB);
  static const surface = Color(0xFFFFFCF9);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E0D8);
  static const borderStrong = Color(0xFFD4CCC0);
  static const textPrimary = Color(0xFF1A1917);
  static const textSecondary = Color(0xFF5C574F);
  static const textMuted = Color(0xFF8A847A);
  static const accent = AppColors.accent;
  static const selectionFill = Color(0xFFF0EBE4);
  static const ink = Color(0xFF1A1917);
  static const commuteTint = Color(0xFFF1F5F9);
  static const soundTint = Color(0xFF0F766E);
  static const grandTint = Color(0xFF2563EB);
  static const justLandedTint = Color(0xFF7C3AED);

  /// Soft matchmaking palette (Duolingo warmth, Linear polish).
  static const readyInk = Color(0xFF0F6B5C);
  static const readyFill = Color(0xFFDFF5EF);
  static const timingInk = Color(0xFF9A5B12);
  static const timingFill = Color(0xFFFFF0D6);
  static const affordInk = Color(0xFF8A4A16);
  static const affordFill = Color(0xFFFFE8D4);
  static const guarantorInk = Color(0xFF5B4A9A);
  static const guarantorFill = Color(0xFFEDE8FF);
  static const reviewInk = Color(0xFF3D5A80);
  static const reviewFill = Color(0xFFE4EEF8);
  static const declineInk = Color(0xFF8B3A3A);
  static const declineFill = Color(0xFFFCE8E6);

  static const signalGood = Color(0xFF0F6B5C);
  static const signalGoodFill = Color(0xFFE6F6F1);
  static const signalWarn = Color(0xFF9A5B12);
  static const signalWarnFill = Color(0xFFFFF0D6);
  static const signalBad = Color(0xFF8B3A3A);
  static const signalBadFill = Color(0xFFFCE8E6);

  /// Warm avatar washes for applicant summaries.
  static const avatarPalettes = <(Color bg, Color fg)>[
    (Color(0xFFFFE4E1), Color(0xFF8B3A3A)),
    (Color(0xFFE4F0FF), Color(0xFF3D5A80)),
    (Color(0xFFE8F6EE), Color(0xFF0F6B5C)),
    (Color(0xFFFFF0D6), Color(0xFF9A5B12)),
    (Color(0xFFEDE8FF), Color(0xFF5B4A9A)),
    (Color(0xFFFFE8D4), Color(0xFF8A4A16)),
  ];

  static (Color bg, Color fg) avatarColorsFor(String name) {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return avatarPalettes[hash % avatarPalettes.length];
  }

  static TextStyle railEyebrow() => const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: textMuted,
      );

  static TextStyle personName({double size = 17}) => TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.2,
        color: textPrimary,
      );

  static TextStyle decisionName({double size = 32}) => TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
        color: textPrimary,
      );

  static TextStyle sectionTitle({double size = 22}) => TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.45,
        height: 1.2,
      );

  static TextStyle cardValue({double size = 28}) => TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.6,
        height: 1.1,
      );

  static TextStyle cardLabel() => const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.05,
        height: 1.25,
      );

  static TextStyle cardSubtext() => const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textMuted,
        height: 1.4,
      );

  static RecommendationVisual recommendationVisual(
    LandlordRecommendationState state,
  ) =>
      switch (state) {
        LandlordRecommendationState.inviteReady => const RecommendationVisual(
            fg: readyInk,
            bg: readyFill,
          ),
        LandlordRecommendationState.timingConflict => const RecommendationVisual(
            fg: timingInk,
            bg: timingFill,
          ),
        LandlordRecommendationState.affordabilityReview =>
          const RecommendationVisual(fg: affordInk, bg: affordFill),
        LandlordRecommendationState.guarantorReview => const RecommendationVisual(
            fg: guarantorInk,
            bg: guarantorFill,
          ),
        LandlordRecommendationState.review => const RecommendationVisual(
            fg: reviewInk,
            bg: reviewFill,
          ),
        LandlordRecommendationState.notSuitable => const RecommendationVisual(
            fg: declineInk,
            bg: declineFill,
          ),
      };

  /// @deprecated Prefer [recommendationVisual].
  static (Color fg, Color bg, IconData icon) recommendationStyle(
    LandlordRecommendationState state,
  ) {
    final v = recommendationVisual(state);
    return (v.fg, v.bg, Icons.circle);
  }

  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
        color: surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? ink.withValues(alpha: 0.28) : border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1917).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      );
}

class RecommendationVisual {
  const RecommendationVisual({required this.fg, required this.bg});
  final Color fg;
  final Color bg;
}
