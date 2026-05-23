import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_match_engine.dart';
import '../utils/viewer_profile.dart';

/// Full-width trust row shown at the top of the card body, right below
/// the image. Contains the trust badge on the left and match score on
/// the right.
class ListingTrustRow extends StatelessWidget {
  const ListingTrustRow({super.key, required this.match});

  final ListingMatchResult match;

  @override
  Widget build(BuildContext context) {
    if (match.inCircle) return _CircleBanner(match: match);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _TrustPill(trustStage: match.trustStage),
          const Spacer(),
          if (match.percentage > 0) _ScorePill(percentage: match.percentage),
        ],
      ),
    );
  }
}

/// "In Your Circle" banner -- blue-tinted, full-width, prominent.
class _CircleBanner extends StatelessWidget {
  const _CircleBanner({required this.match});

  final ListingMatchResult match;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_rounded, size: 18, color: Color(0xFF0EA5E9)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'In Your Circle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0EA5E9),
                letterSpacing: -0.1,
              ),
            ),
          ),
          _TrustPill(trustStage: match.trustStage),
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
  const _TrustPill({required this.trustStage});

  final TrustStage trustStage;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, bgColor) = switch (trustStage) {
      TrustStage.idVerified => (
          Icons.verified_user_rounded,
          'ID Verified',
          const Color(0xFF008A05),
          const Color(0xFFDCFCE7),
        ),
      TrustStage.socialVerified => (
          Icons.workspace_premium_rounded,
          'Verified Pro',
          const Color(0xFF7C3AED),
          const Color(0xFFF3E8FF),
        ),
      TrustStage.casual => (
          Icons.person_outline_rounded,
          'Casual',
          const Color(0xFF717171),
          const Color(0xFFF3F4F6),
        ),
      TrustStage.anonymous => (
          Icons.help_outline_rounded,
          'Unverified',
          const Color(0xFFB0B0B0),
          const Color(0xFFF7F7F7),
        ),
    };

    return Container(
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
  }
}

/// Match percentage score pill.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final pct = percentage.round();
    final color = pct >= 70
        ? const Color(0xFF008A05)
        : pct >= 50
            ? HomeMarketplaceTheme.textPrimary
            : HomeMarketplaceTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.2,
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
