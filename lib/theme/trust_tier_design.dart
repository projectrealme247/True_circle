import 'package:flutter/material.dart';

import '../models/applicant_trust_tier.dart';
import '../utils/viewer_profile.dart';
import '../debug/agent_log.dart';

/// Premium trust-tier dot + pill color tokens.
abstract final class TrustTierDesign {
  static const justLandedDot = Color(0xFFEAB308);
  static const justLandedBg = Color(0xFFFEF9C3);
  static const justLandedText = Color(0xFF92400E);

  static const grandDot = Color(0xFF10B981);
  static const grandBg = Color(0xFFD1FAE5);
  static const grandText = Color(0xFF047857);

  static const soundDot = Color(0xFF2563EB);
  static const soundBg = Color(0xFFDBEAFE);
  static const soundText = Color(0xFF1D4ED8);

  static (Color dot, Color bg, Color text) colorsFor(ApplicantTrustTier tier) {
    return switch (tier) {
      ApplicantTrustTier.justLanded => (justLandedDot, justLandedBg, justLandedText),
      ApplicantTrustTier.grand => (grandDot, grandBg, grandText),
      ApplicantTrustTier.sound => (soundDot, soundBg, soundText),
    };
  }

  static ApplicantTrustTier fromTrustStage(TrustStage stage) {
    if (stage == TrustStage.idVerified) return ApplicantTrustTier.sound;
    if (stage == TrustStage.socialVerified) return ApplicantTrustTier.grand;
    return ApplicantTrustTier.justLanded;
  }

  static String labelFor(ApplicantTrustTier tier) => switch (tier) {
        ApplicantTrustTier.justLanded => 'Just Landed',
        ApplicantTrustTier.grand => 'Grand',
        ApplicantTrustTier.sound => 'Sound',
      };

  /// Universal soft-slate trust scale capsule — single source of truth.
  static const trustScaleCapsuleBg = Color(0xFFF1F5F9);
  static const trustScaleCapsuleText = Color(0xFF334155);
  static const trustScaleCapsuleRadius = 12.0;
  static const trustScaleCapsulePadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 4);

  static String emojiDotFor(ApplicantTrustTier tier) => switch (tier) {
        ApplicantTrustTier.sound => '🔵',
        ApplicantTrustTier.grand => '🟢',
        ApplicantTrustTier.justLanded => '🟡',
      };

  static String trustScaleEmojiLabel(ApplicantTrustTier tier) {
    final label = '${emojiDotFor(tier)} ${labelFor(tier)}';
    // #region agent log
    if (!_trustEmojiLabelLogged) {
      _trustEmojiLabelLogged = true;
      agentLog(
        location: 'trust_tier_design.dart:trustScaleEmojiLabel',
        message: 'Trust tier emoji label composed',
        hypothesisId: 'A',
        data: {
          'tier': tier.name,
          'label': label,
          'hasNonAscii': label.runes.any((r) => r > 127),
        },
      );
    }
    // #endregion
    return label;
  }

  static bool _trustEmojiLabelLogged = false;

  static TextStyle trustScaleLabelStyle({bool compact = false}) => TextStyle(
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w700,
        color: trustScaleCapsuleText,
        height: 1.2,
      );
}

/// Solid geometric dot for trust-tier badges.
class TrustTierDot extends StatelessWidget {
  const TrustTierDot({
    super.key,
    required this.tier,
    this.size = 8,
  });

  final ApplicantTrustTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = TrustTierDesign.colorsFor(tier).$1;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dot,
        shape: BoxShape.circle,
      ),
    );
  }
}
