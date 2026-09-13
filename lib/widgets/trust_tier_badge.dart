import 'package:flutter/material.dart';

import '../models/applicant_trust_tier.dart';
import '../theme/trust_tier_design.dart';
import 'trust_badge.dart';

export 'trust_badge.dart' show TrustBadge;

/// Compatibility badge — shows ✅ Verified User only when [isVerified] is true.
/// Does not use [ApplicantTrustTier] / trust_stage as a badge trigger.
class TrustTierBadge extends StatelessWidget {
  const TrustTierBadge({
    super.key,
    required this.tier,
    this.isVerified = false,
    this.compact = false,
    this.tooltip,
  });

  final ApplicantTrustTier tier;
  /// Contact-unlock predicate — required to show the badge.
  final bool isVerified;
  final bool compact;
  final String? tooltip;

  static String labelFor(ApplicantTrustTier tier, {bool isVerified = false}) =>
      isVerified
          ? ApplicantTrustTier.verifiedUserLabel
          : 'Verification pending';

  static String emojiDotFor(ApplicantTrustTier tier, {bool isVerified = false}) =>
      isVerified ? '✅' : '·';

  static String emojiLabelFor(ApplicantTrustTier tier, {bool isVerified = false}) =>
      labelFor(tier, isVerified: isVerified);

  static String tooltipFor(ApplicantTrustTier tier, {bool isVerified = false}) =>
      isVerified ? TrustBadge.tooltipMessage : 'Verification pending';

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    const bg = TrustTierDesign.trustScaleCapsuleBg;
    const text = TrustTierDesign.trustScaleCapsuleText;
    final badge = Container(
      padding: TrustTierDesign.trustScaleCapsulePadding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
      ),
      child: Text(
        ApplicantTrustTier.verifiedUserLabel,
        style: TrustTierDesign.trustScaleLabelStyle(
          compact: compact,
          color: text,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return badge;

    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 350),
      preferBelow: false,
      child: badge,
    );
  }
}

/// GDPR-safe cryptographic verification tokens — no raw document exposure.
class TrustVerificationTokenItem {
  const TrustVerificationTokenItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
}

abstract final class TrustVerificationTokens {
  static List<TrustVerificationTokenItem> forVerifiedUser() => const [
        TrustVerificationTokenItem(
          emoji: '✅',
          title: 'Verified User',
          subtitle: 'Verification complete',
        ),
      ];

  static List<TrustVerificationTokenItem> forTier(
    ApplicantTrustTier tier, {
    bool isVerified = false,
  }) {
    if (!isVerified) return const [];
    return forVerifiedUser();
  }
}
