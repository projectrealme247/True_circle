import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/tenant_verification_credentials.dart';
import '../utils/trust_tier_tooltips.dart';
import '../utils/viewer_profile.dart';

/// Landlord-facing GDPR-minimized verification confidence panel.
class TenantVerificationConfidencePanel extends StatelessWidget {
  const TenantVerificationConfidencePanel({
    super.key,
    required this.session,
    this.tierTooltipForLabel = TrustTierTooltips.forBadgeLabel,
  });

  final Map<String, dynamic> session;
  final String? Function(String badgeLabel)? tierTooltipForLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      !TenantVerificationCredentials.containsSensitiveExposure(session),
      'Sensitive financial fields must not be passed to landlord verification UI.',
    );

    final credentials = TenantVerificationCredentials.fromSession(session);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: AppColors.accent.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TrueCircle Security & Trust Verification',
                    style: AppTypography.h3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: _TierBadgePill(
                label: credentials.tierLabel,
                textColor: Color(credentials.tierTextColor),
                backgroundColor: Color(credentials.tierBackgroundColor),
                tooltip: tierTooltipForLabel?.call(credentials.tierLabel),
              ),
            ),
            if (credentials.showTrackChecklist && credentials.track != null) ...[
              const SizedBox(height: 18),
              _TrackChecklist(track: credentials.track!),
            ] else if (credentials.trustStage.level >= TrustStage.socialVerified.level) ...[
              const SizedBox(height: 14),
              Text(
                'This seeker has completed TrueCircle identity verification. '
                'Track-specific credentials will appear once a verification path is on file.',
                style: AppTypography.caption.copyWith(height: 1.5),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text(
                'This seeker has not yet completed Grand or Sound tier verification. '
                'Consider prioritizing verified applicants for Entire Place and shared flat lets.',
                style: AppTypography.caption.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 18),
            const _ComplianceStamp(),
          ],
        ),
      ),
    );
  }
}

class _TierBadgePill extends StatelessWidget {
  const _TierBadgePill({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.tooltip,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -0.1,
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return pill;

    return Theme(
      data: Theme.of(context).copyWith(
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(
            color: Color(0xFF1C1E21),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          textStyle: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          waitDuration: Duration.zero,
          showDuration: Duration(seconds: 4),
        ),
      ),
      child: Tooltip(
        message: tooltip!,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: true,
        child: pill,
      ),
    );
  }
}

class _TrackChecklist extends StatelessWidget {
  const _TrackChecklist({required this.track});

  final TenantVerificationTrack track;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SuccessBadge(text: track.successBadge),
        const SizedBox(height: 12),
        Text(
          track.subtitle,
          style: AppTypography.caption.copyWith(
            fontSize: 13,
            height: 1.55,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 14),
        _NeutralStatusBadge(text: track.neutralStatusBadge),
        const SizedBox(height: 12),
        const _ChecklistRow(
          icon: Icons.check_circle_rounded,
          label: 'Cryptographic validation completed in Dublin',
        ),
        const _ChecklistRow(
          icon: Icons.check_circle_rounded,
          label: 'Raw documents and bank tokens destroyed post-verification',
        ),
        const _ChecklistRow(
          icon: Icons.check_circle_rounded,
          label: 'No salary figures or account numbers stored on TrueCircle',
        ),
      ],
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F5C52),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralStatusBadge extends StatelessWidget {
  const _NeutralStatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.secondaryText.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplianceStamp extends StatelessWidget {
  const _ComplianceStamp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              TenantVerificationCredentials.complianceStamp,
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                height: 1.55,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
