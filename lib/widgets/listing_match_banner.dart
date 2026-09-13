import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../theme/trust_tier_design.dart';
import '../utils/listing_match_engine.dart';
import '../widgets/listing_card_overlay_badge.dart';

/// Full-width row below the listing image — match score only.
/// Host trust / Verified Pro / ID Verified pills are removed (no host
/// verification programme; seeker Verified User is not stamped on listings).
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
    if (match.percentage <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Spacer(),
          _ScorePill(percentage: match.percentage),
        ],
      ),
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
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .join(' · ');
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.detail().copyWith(
          fontSize: 12,
          height: 1.35,
          color: highlighted
              ? HomeMarketplaceTheme.textSecondary
              : HomeMarketplaceTheme.textMuted,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
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
