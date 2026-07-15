import 'package:flutter/material.dart';

import '../models/applicant_trust_tier.dart';
import 'trust_badge.dart';

export 'trust_badge.dart' show TrustBadge;

/// @deprecated Use [TrustBadge] directly.
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

  static String labelFor(ApplicantTrustTier tier) => TrustBadge.labelFor(tier);

  static String emojiDotFor(ApplicantTrustTier tier) =>
      TrustBadge.emojiLabelFor(tier).split(' ').first;

  static String emojiLabelFor(ApplicantTrustTier tier) =>
      TrustBadge.emojiLabelFor(tier);

  static String tooltipFor(ApplicantTrustTier tier) =>
      TrustBadge.tooltipFor(tier);

  @override
  Widget build(BuildContext context) {
    return TrustBadge(
      tier: tier,
      compact: compact,
      tooltip: tooltip,
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
