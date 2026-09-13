import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../trust_badge.dart';

/// Landlord onboarding primer — Verified User only (no trust tiers).
class LandlordTrustEcosystemOverview extends StatelessWidget {
  const LandlordTrustEcosystemOverview({
    super.key,
    required this.isSharedSpace,
  });

  final bool isSharedSpace;

  String get _purpose => isSharedSpace
      ? 'Our Purpose: Matching renters based on lifestyle compatibility and '
          'verification to protect your house harmony.'
      : 'Our Purpose: Connecting you with verified seekers to ensure absolute '
          'tenancy security.';

  String get _body => isSharedSpace
      ? 'Seekers who complete verification appear as ✅ Verified User. '
          'Focus on lifestyle fit, household rhythm, and clear communication — '
          'not legacy trust-tier labels.'
      : 'Seekers who complete verification appear as ✅ Verified User. '
          'Use affordability, timing, and property fit to decide who to invite.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🛡️ Verification for hosts',
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
          'Verified User status',
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
        const Align(
          alignment: Alignment.centerLeft,
          child: TrustBadge(isVerified: true, compact: true, showTooltip: false),
        ),
        const SizedBox(height: 12),
        Container(
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
                _body,
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
      ],
    );
  }
}
