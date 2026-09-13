import 'package:flutter/material.dart';



import '../models/applicant_trust_tier.dart';

import '../core/theme/app_theme.dart' show AppColors, AppTypography;

/// Premium trust-tier labels + neutral badge capsule tokens.
abstract final class TrustTierDesign {

  /// Neutral badge palette — single style for every tier surface.

  static const trustScaleCapsuleBg = AppColors.surface2;

  static const trustScaleCapsuleText = AppColors.secondaryText;

  static const trustScaleCapsuleRadius = 20.0;

  static const trustScaleCapsulePadding =

      EdgeInsets.symmetric(horizontal: 11, vertical: 5);

  static String labelFor(ApplicantTrustTier tier) => switch (tier) {

        ApplicantTrustTier.justLanded => 'Just Landed',

        ApplicantTrustTier.grand => 'Grand',

        ApplicantTrustTier.sound => 'Sound',

      };



  static String emojiPrefixFor(ApplicantTrustTier tier) => switch (tier) {

        ApplicantTrustTier.justLanded => '🌱',

        ApplicantTrustTier.grand => '☘️',

        ApplicantTrustTier.sound => '💎',

      };



  static String emojiDotFor(ApplicantTrustTier tier) => emojiPrefixFor(tier);



  static String trustScaleEmojiLabel(ApplicantTrustTier tier) =>

      '${emojiPrefixFor(tier)} ${labelFor(tier)}';



  static TextStyle trustScaleLabelStyle({

    bool compact = false,

    Color? color,

  }) =>

      TextStyle(

        fontSize: compact ? 12 : 13,

        fontWeight: FontWeight.w600,

        color: color ?? trustScaleCapsuleText,

        height: 1.2,

        fontFamily: AppTypography.fontFamily,

        fontFamilyFallback: AppTypography.emojiFontFallback,

      );

}



/// Solid geometric dot for trust-tier badges — neutral tone for all tiers.

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

    return Container(

      width: size,

      height: size,

      decoration: const BoxDecoration(

        color: TrustTierDesign.trustScaleCapsuleText,

        shape: BoxShape.circle,

      ),

    );

  }

}


