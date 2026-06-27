import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/applicant_trust_tier.dart';
import '../theme/app_typography.dart';
import '../theme/trust_tier_design.dart';
import '../utils/numeric_bounds.dart';
import 'trust_tier_badge.dart';

/// Discovery card overlay tokens — aligned with Trust Scale capsules.
abstract final class ListingCardOverlayTokens {
  static const matchText = Color(0xFF475569);
  static const border = Color(0xFFE2E8F0);
  static const frostedBgAlpha = 0.92;
}

/// Premium indigo signature for closed-loop "In Your Circle" relational markers.
abstract final class InYourCircleOverlayTokens {
  InYourCircleOverlayTokens._();

  static const background = Color(0xFFEEF2FF);
  static const text = Color(0xFF4338CA);
  static const border = Color(0xFFC7D2FE);
  static const borderWidth = 1.2;
  static const label = '⭕ In Your Circle';
  static const capsuleRadius = 100.0;

  static const labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: text,
    height: 1.2,
    letterSpacing: -0.1,
  );

  static const bannerLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: text,
    height: 1.2,
    letterSpacing: -0.1,
  );
}

/// Frosted image overlay shell for listing card badges.
class ListingCardOverlayBadge extends StatelessWidget {
  const ListingCardOverlayBadge({
    super.key,
    required this.child,
    this.frosted = true,
  });

  final Widget child;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    if (!frosted) return child;

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: child,
      ),
    );
  }
}

/// Top-right match percentage pill on discovery cards.
class ListingCardMatchOverlayBadge extends StatelessWidget {
  const ListingCardMatchOverlayBadge({
    super.key,
    required this.percentage,
    this.frosted = true,
  });

  final double percentage;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    return ListingCardOverlayBadge(
      frosted: frosted,
      child: Container(
        padding: TrustTierDesign.trustScaleCapsulePadding,
        decoration: BoxDecoration(
          color: TrustTierDesign.trustScaleCapsuleBg
              .withValues(alpha: ListingCardOverlayTokens.frostedBgAlpha),
          borderRadius:
              BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
          border: Border.all(color: ListingCardOverlayTokens.border),
        ),
        child: Text(
          '${NumericBounds.clampPercentInt(percentage)}% match',
          style: AppTypography.detail().copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: ListingCardOverlayTokens.matchText,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Trust Scale tier chip (🔵/🟢/🟡) for listing image overlays.
class ListingCardTrustTierOverlayBadge extends StatelessWidget {
  const ListingCardTrustTierOverlayBadge({super.key, required this.tier});

  final ApplicantTrustTier tier;

  @override
  Widget build(BuildContext context) {
    return ListingCardOverlayBadge(
      child: TrustTierBadge(tier: tier, compact: true),
    );
  }
}

/// Indigo relational chip — secure closed-loop network marker on listing images.
class ListingCardInCircleOverlayBadge extends StatelessWidget {
  const ListingCardInCircleOverlayBadge({super.key, this.frosted = true});

  final bool frosted;

  @override
  Widget build(BuildContext context) {
    return ListingCardOverlayBadge(
      frosted: frosted,
      child: Container(
        padding: TrustTierDesign.trustScaleCapsulePadding,
        decoration: BoxDecoration(
          color: InYourCircleOverlayTokens.background.withValues(
            alpha: frosted ? ListingCardOverlayTokens.frostedBgAlpha : 1,
          ),
          borderRadius:
              BorderRadius.circular(InYourCircleOverlayTokens.capsuleRadius),
          border: Border.all(
            color: InYourCircleOverlayTokens.border,
            width: InYourCircleOverlayTokens.borderWidth,
          ),
        ),
        child: Text(
          InYourCircleOverlayTokens.label,
          style: InYourCircleOverlayTokens.labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Neutral slate label chip (e.g. Pre-Arrival) matching Trust Scale shape.
class ListingCardLabelOverlayBadge extends StatelessWidget {
  const ListingCardLabelOverlayBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ListingCardOverlayBadge(
      child: Container(
        padding: TrustTierDesign.trustScaleCapsulePadding,
        decoration: BoxDecoration(
          color: TrustTierDesign.trustScaleCapsuleBg
              .withValues(alpha: ListingCardOverlayTokens.frostedBgAlpha),
          borderRadius:
              BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
          border: Border.all(color: ListingCardOverlayTokens.border),
        ),
        child: Text(
          label,
          style: TrustTierDesign.trustScaleLabelStyle(compact: true),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
