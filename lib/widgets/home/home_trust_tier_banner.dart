import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors;
import '../../models/applicant_trust_tier.dart';
import '../../theme/app_typography.dart';
import '../../theme/trust_tier_design.dart';
import '../../utils/viewer_profile.dart';
import '../trust_badge.dart';

/// Prominent trust-tier capsule shown below the space switcher on home explore.
class HomeTrustTierBanner extends StatelessWidget {
  const HomeTrustTierBanner({
    super.key,
    required this.viewer,
    this.onTap,
  });

  final ViewerProfile? viewer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stage = viewer?.trustStage ?? TrustStage.anonymous;
    final tier = TrustTierDesign.fromTrustStage(stage);
    final subtitle = _subtitleFor(stage, viewer);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                TrustBadge(
                  tier: tier,
                  showTooltip: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subtitle,
                    style: AppTypography.meta().copyWith(
                      color: AppColors.secondaryText,
                      height: 1.25,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondaryText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitleFor(TrustStage stage, ViewerProfile? viewer) {
    if (viewer != null &&
        TrustTierDesign.hasPreArrivalTrustUpgrade(
          baseStage: stage,
          hasVerifiedPreArrivalDocs: viewer.hasVerifiedPreArrivalDocs,
        )) {
      return 'Pre-arrival docs verified';
    }
    return switch (TrustTierDesign.fromTrustStage(stage)) {
      ApplicantTrustTier.grand => 'Verified identity + one reference',
      ApplicantTrustTier.sound => 'Community vouched & secured',
      ApplicantTrustTier.justLanded =>
        'Complete verification to boost your trust tier',
    };
  }
}
