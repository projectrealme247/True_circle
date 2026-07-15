import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/applicant_trust_tier.dart';
import '../../trust_badge.dart';

/// Interactive trust-tier primer for landlord onboarding — copy syncs with the
/// app Trust Scale and adapts to independent vs shared hosting track.
class LandlordTrustEcosystemOverview extends StatefulWidget {
  const LandlordTrustEcosystemOverview({
    super.key,
    required this.isSharedSpace,
  });

  final bool isSharedSpace;

  @override
  State<LandlordTrustEcosystemOverview> createState() =>
      _LandlordTrustEcosystemOverviewState();
}

class _LandlordTrustEcosystemOverviewState
    extends State<LandlordTrustEcosystemOverview> {
  ApplicantTrustTier _selected = ApplicantTrustTier.justLanded;

  static const _entirePlacePurpose =
      'Our Purpose: Connecting you with verified seekers to ensure absolute '
      'trust and tenancy security.';

  static const _sharedSpacePurpose =
      'Our Purpose: Matching renters based on lifestyle compatibility and trust '
      'to protect your house harmony.';

  static const _entirePlaceDescriptions = {
    ApplicantTrustTier.justLanded:
        'Inbound Seeker: Newly arriving community members. Identity checked, '
        'verified, and ready to sign independent long-term or short-term leases.',
    ApplicantTrustTier.grand:
        'Verified Intent: High-intent profiles with pre-checked reference '
        'documents, proof of employment or university enrolment, and '
        'authenticated socials.',
    ApplicantTrustTier.sound:
        'Vouched & Secured: Premier applicants who have earned explicit '
        'character recommendations and historical verifications within our '
        'local trusted loop.',
  };

  static const _sharedSpaceDescriptions = {
    ApplicantTrustTier.justLanded:
        'Casual / Inbound: New community arrivals looking for flatshares. '
        'Identity-checked and exploring shared lifestyle matches.',
    ApplicantTrustTier.grand:
        'Verified Intent: Co-living seekers with verified student/professional '
        'status, clear lifestyle habit profiles, and authenticated backgrounds.',
    ApplicantTrustTier.sound:
        'Vouched & Secured: Highly recommended housemates backed by peer '
        'testimonials and community vouches from their previous shared living '
        'arrangements.',
  };

  static const _tierOrder = [
    ApplicantTrustTier.justLanded,
    ApplicantTrustTier.grand,
    ApplicantTrustTier.sound,
  ];

  String get _purpose =>
      widget.isSharedSpace ? _sharedSpacePurpose : _entirePlacePurpose;

  String _description(ApplicantTrustTier tier) => widget.isSharedSpace
      ? _sharedSpaceDescriptions[tier]!
      : _entirePlaceDescriptions[tier]!;

  @override
  Widget build(BuildContext context) {
    final contentKey = ValueKey('${widget.isSharedSpace}_$_selected');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🛡️ True Circle Trust Ecosystem',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            height: 1.3,
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: AppTypography.emojiFontFallback,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Trust & Lifestyle Compatibility',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            height: 1.35,
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: AppTypography.emojiFontFallback,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < _tierOrder.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: TrustBadge(
                  tier: _tierOrder[i],
                  compact: true,
                  selected: _selected == _tierOrder[i],
                  showTooltip: false,
                  onTap: () => setState(() => _selected = _tierOrder[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Container(
            key: contentKey,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _purpose,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.45,
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.emojiFontFallback,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _description(_selected),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                    height: 1.5,
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.emojiFontFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
