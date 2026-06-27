import 'package:flutter/material.dart';

import '../models/applicant_trust_tier.dart';
import '../theme/trust_tier_design.dart';

/// Trust Scale badge — soft-slate capsule + emoji dot for every surface.
class TrustTierBadge extends StatelessWidget {
  const TrustTierBadge({
    super.key,
    required this.tier,
    this.compact = false,
    this.tooltip,
  });

  final ApplicantTrustTier tier;
  final bool compact;
  final String? tooltip;

  static String labelFor(ApplicantTrustTier tier) =>
      TrustTierDesign.labelFor(tier);

  static String emojiDotFor(ApplicantTrustTier tier) =>
      TrustTierDesign.emojiDotFor(tier);

  static String emojiLabelFor(ApplicantTrustTier tier) =>
      TrustTierDesign.trustScaleEmojiLabel(tier);

  static String tooltipFor(ApplicantTrustTier tier) => switch (tier) {
        ApplicantTrustTier.justLanded =>
          'Just Landed tier requires:\n'
          'Verified arrival intent signal\n'
          'Pre-arrival housing circle profile\n'
          'Funding capacity token on file',
        ApplicantTrustTier.grand =>
          'Grand tier requires:\n'
          'Active .ac.ie institutional domain check\n'
          'Identity and document hash verification\n'
          'On-campus student status confirmation',
        ApplicantTrustTier.sound =>
          'Sound tier requires:\n'
          'Gov API identity match token\n'
          'Income verified >3.5x rent target\n'
          'Fully vouched by community references',
      };

  @override
  Widget build(BuildContext context) {
    final message = tooltip ?? tooltipFor(tier);

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 350),
      preferBelow: false,
      child: Container(
        padding: TrustTierDesign.trustScaleCapsulePadding,
        decoration: BoxDecoration(
          color: TrustTierDesign.trustScaleCapsuleBg,
          borderRadius:
              BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
        ),
        child: Text(
          TrustTierDesign.trustScaleEmojiLabel(tier),
          style: TrustTierDesign.trustScaleLabelStyle(compact: compact),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
  static List<TrustVerificationTokenItem> forTier(ApplicantTrustTier tier) =>
      switch (tier) {
        ApplicantTrustTier.sound => const [
            TrustVerificationTokenItem(
              emoji: '🪪',
              title: 'ID Verification',
              subtitle: 'Matched via Gov API Check',
            ),
            TrustVerificationTokenItem(
              emoji: '💰',
              title: 'Financial Income Target',
              subtitle: 'Verified (>3.5x Rent Match)',
            ),
            TrustVerificationTokenItem(
              emoji: '🔐',
              title: 'Employment Status',
              subtitle: 'Cryptographically Sealed',
            ),
            TrustVerificationTokenItem(
              emoji: '🤝',
              title: 'Peer Reference',
              subtitle: 'Vouch Token Active',
            ),
          ],
        ApplicantTrustTier.grand => const [
            TrustVerificationTokenItem(
              emoji: '🎓',
              title: 'University Domain',
              subtitle: 'Institutional .ac.ie OTP Verified',
            ),
            TrustVerificationTokenItem(
              emoji: '🪪',
              title: 'Identity Verification',
              subtitle: 'Document Hash Matched',
            ),
            TrustVerificationTokenItem(
              emoji: '📚',
              title: 'Enrollment Status',
              subtitle: 'Active On-Campus Token',
            ),
          ],
        ApplicantTrustTier.justLanded => const [
            TrustVerificationTokenItem(
              emoji: '✈️',
              title: 'Arrival Intent',
              subtitle: 'Signal Verified',
            ),
            TrustVerificationTokenItem(
              emoji: '💰',
              title: 'Funding Capacity',
              subtitle: 'Token on File',
            ),
            TrustVerificationTokenItem(
              emoji: '🌍',
              title: 'Pre-Arrival Profile',
              subtitle: 'Established',
            ),
          ],
      };
}
