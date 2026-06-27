import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart' show AppColors;
import '../config/market/market_config.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_match_engine.dart';
import '../utils/polymorphic_identity.dart';
import '../theme/trust_tier_design.dart';
import '../utils/trust_tier_tooltips.dart';
import '../utils/viewer_profile.dart';
import '../widgets/listing_card_overlay_badge.dart';
import '../widgets/trust_tier_badge.dart';

/// Full-width trust row shown at the top of the card body, right below
/// the image. Contains the trust badge on the left and match score on
/// the right.
class ListingTrustRow extends StatelessWidget {
  const ListingTrustRow({
    super.key,
    required this.match,
    this.listing,
  });

  final ListingMatchResult match;
  final Map<String, dynamic>? listing;

  @override
  Widget build(BuildContext context) {
    if (match.inCircle) {
      return _CircleBanner(match: match, listing: listing);
    }

    final professionalHost = listing != null &&
        PolymorphicIdentity.showVerifiedProfessionalHostBadge(listing!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          if (professionalHost)
            const _ProfessionalHostPill()
          else
            _TrustPill(
              trustStage: match.trustStage,
              preArrivalBadge: match.preArrivalBadge,
            ),
          const Spacer(),
          if (match.percentage > 0) _ScorePill(percentage: match.percentage),
        ],
      ),
    );
  }
}

/// "In Your Circle" banner — premium indigo relational marker, full-width.
class _ProfessionalHostPill extends StatelessWidget {
  const _ProfessionalHostPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBCE8DB)),
      ),
      child: const Text(
        PolymorphicIdentity.verifiedProfessionalHostLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F3D36),
        ),
      ),
    );
  }
}

class _CircleBanner extends StatelessWidget {
  const _CircleBanner({required this.match, this.listing});

  final ListingMatchResult match;
  final Map<String, dynamic>? listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: InYourCircleOverlayTokens.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: InYourCircleOverlayTokens.border,
          width: InYourCircleOverlayTokens.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              InYourCircleOverlayTokens.label,
              style: InYourCircleOverlayTokens.bannerLabelStyle,
            ),
          ),
          if (listing != null &&
              PolymorphicIdentity.showVerifiedProfessionalHostBadge(listing!))
            const _ProfessionalHostPill()
          else
            _TrustPill(
              trustStage: match.trustStage,
              preArrivalBadge: match.preArrivalBadge,
            ),
          if (match.percentage > 0) ...[
            const SizedBox(width: 8),
            _ScorePill(percentage: match.percentage),
          ],
        ],
      ),
    );
  }
}

/// Colored pill showing trust stage (e.g., "Verified Pro").
class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.trustStage,
    this.preArrivalBadge = false,
  });

  final TrustStage trustStage;
  final bool preArrivalBadge;

  @override
  Widget build(BuildContext context) {
    if (preArrivalBadge) {
      return ListingCardLabelOverlayBadge(label: 'Pre-Arrival');
    }

    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;

    if (lightTrust && trustStage != TrustStage.anonymous) {
      final tier = TrustTierDesign.fromTrustStage(trustStage);
      return TrustTierBadge(
        tier: tier,
        tooltip: TrustTierTooltips.forTrustStage(trustStage),
      );
    }

    final (icon, label, color, bgColor, tooltip) =
        switch (trustStage) {
      TrustStage.idVerified => (
          Icons.verified_user_rounded,
          'ID Verified',
          HomeMarketplaceTheme.trustIdVerified,
          const Color(0xFFDCFCE7),
          null as String?,
        ),
      TrustStage.socialVerified => (
          Icons.workspace_premium_rounded,
          'Verified Pro',
          HomeMarketplaceTheme.trustSocialVerified,
          AppColors.trustMutedSurface,
          null,
        ),
      TrustStage.casual => (
          Icons.person_outline_rounded,
          'Casual',
          HomeMarketplaceTheme.textSecondary,
          const Color(0xFFF3F4F6),
          null,
        ),
      TrustStage.anonymous => (
          Icons.help_outline_rounded,
          'Unverified',
          HomeMarketplaceTheme.textMuted,
          HomeMarketplaceTheme.trustAnonymous,
          null,
        ),
    };

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null || tooltip.isEmpty) return pill;

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      child: pill,
    );
  }
}

/// Match percentage score pill.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final pct = percentage.round();

    return Container(
      padding: TrustTierDesign.trustScaleCapsulePadding,
      decoration: BoxDecoration(
        color: TrustTierDesign.trustScaleCapsuleBg,
        borderRadius:
            BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
        border: Border.all(color: ListingCardOverlayTokens.border),
      ),
      child: Text(
        '$pct% match',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ListingCardOverlayTokens.matchText,
          letterSpacing: -0.1,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Single-line match reason at the bottom of the card. Muted, concise.
class ListingMatchReasonLine extends StatelessWidget {
  const ListingMatchReasonLine({
    super.key,
    required this.reasons,
    this.highlighted = false,
  });

  final List<String> reasons;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();

    final text = reasons
        .take(3)
        .map((r) => r
            .replaceFirst(RegExp(r'^[^\w]*'), '')
            .replaceFirst('Matches search: ', ''))
        .join(' · ');

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: highlighted
          ? AppTypography.meta().copyWith(
              color: HomeMarketplaceTheme.primary,
              fontWeight: FontWeight.w600,
            )
          : AppTypography.meta(),
    );
  }
}

// ── Legacy exports (kept so existing imports don't break) ─────────

/// @deprecated Use [ListingTrustRow] instead.
class ListingMatchBanner extends StatelessWidget {
  const ListingMatchBanner({super.key, required this.match});
  final ListingMatchResult match;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// @deprecated Use [ListingTrustRow] instead.
class ListingTrustBadge extends StatelessWidget {
  const ListingTrustBadge({super.key, required this.match});
  final ListingMatchResult match;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// @deprecated Use [ListingMatchReasonLine] instead.
class ListingMatchReasonsLine extends StatelessWidget {
  const ListingMatchReasonsLine({super.key, required this.reasons});
  final List<String> reasons;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
