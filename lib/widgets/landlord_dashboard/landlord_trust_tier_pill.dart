import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/applicant_trust_tier.dart';

/// Landlord verification chip — ✅ Verified User when verified, otherwise empty.
class LandlordTrustTierPill extends StatelessWidget {
  const LandlordTrustTierPill({
    super.key,
    required this.isVerified,
    this.compact = false,
  });

  final bool isVerified;
  final bool compact;

  /// Legacy factory — does not use trust_tier for badge visibility.
  factory LandlordTrustTierPill.fromTier(
    ApplicantTrustTier tier, {
    Key? key,
    bool compact = false,
    bool? contactVerified,
  }) {
    return LandlordTrustTierPill(
      key: key,
      isVerified: contactVerified ?? false,
      compact: compact,
    );
  }

  static const _bg = Color(0xFFE8F6EE);
  static const _fg = Color(0xFF1B6B4A);
  static const _border = Color(0xFFB8E4CB);

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Text(
        ApplicantTrustTier.verifiedUserLabel,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.emojiFontFallback,
          fontSize: compact ? 12.5 : 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          color: _fg,
          height: 1.1,
        ),
      ),
    );
  }
}
