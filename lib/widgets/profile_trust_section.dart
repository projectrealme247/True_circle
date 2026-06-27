import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../services/trust_service.dart';
import '../theme/trust_tier_design.dart';
import '../utils/viewer_profile.dart';
import 'profile_invite_code_section.dart';
import 'trust_tier_badge.dart';
import 'verification_gateway_bottom_sheet.dart';

/// Trust stage summary for the user profile screen.
class ProfileTrustSection extends StatelessWidget {
  const ProfileTrustSection({
    super.key,
    required this.session,
    this.actionColor = _ProfileTrustPalette.coral,
    this.tierTooltipForLabel,
  });

  final Map<String, dynamic> session;
  final Color actionColor;
  final String? Function(String badgeLabel)? tierTooltipForLabel;

  @override
  Widget build(BuildContext context) {
    final stage = TrustService.currentStage();
    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;
    final preArrival = TrustService.preArrivalContactReady();
    final canContact = TrustService.canContact();

    final badgeTooltip = _resolveBadgeTooltip(
      stage: stage,
      tooltipForLabel: tierTooltipForLabel,
    );
    final subtitle = _resolveSubtitle(
      stage: stage,
      preArrival: preArrival,
      lightTrust: lightTrust,
      canContact: canContact,
      session: session,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TrustTierBadge(
              tier: TrustTierDesign.fromTrustStage(stage),
              tooltip: badgeTooltip,
            ),
            const Spacer(),
            Text(
              '${stage.multiplier}× listing boost',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
        ],
        if (_showVerifyCta(stage: stage, preArrival: preArrival, lightTrust: lightTrust)) ...[
          const SizedBox(height: 12),
          _VerifyCtaRow(
            stage: stage,
            lightTrust: lightTrust,
            preArrival: preArrival,
            actionColor: actionColor,
          ),
        ],
        if (stage.level >= TrustStage.idVerified.level && lightTrust) ...[
          const SizedBox(height: 16),
          const ProfileInviteCodeSection(),
        ],
      ],
    );
  }

  static String? _resolveBadgeTooltip({
    required TrustStage stage,
    String? Function(String badgeLabel)? tooltipForLabel,
  }) {
    final tier = TrustTierDesign.fromTrustStage(stage);
    final label = TrustTierDesign.labelFor(tier);
    return tooltipForLabel?.call(label) ?? TrustTierBadge.tooltipFor(tier);
  }

  static String _resolveSubtitle({
    required TrustStage stage,
    required bool preArrival,
    required bool lightTrust,
    required bool canContact,
    required Map<String, dynamic> session,
  }) {
    if (stage == TrustStage.idVerified && lightTrust) {
      final email = session['verified_university_email']?.toString();
      if (email != null && email.isNotEmpty) {
        return 'Verified via $email · Contact hosts unlocked · Full 1.0× ranking';
      }
      return 'Contact hosts unlocked · Full 1.0× ranking on your listings';
    }
    if (preArrival && lightTrust) {
      return 'Contact hosts unlocked · Pre-Arrival badge on listings (0.9×). '
          'Verify college email after arrival for Community Verified.';
    }
    if (session['employment_verified'] == true &&
        session['verification_track']?.toString() == 'Corporate Track') {
      return 'Corporate verification complete · Grand tier · 0.9× listing boost';
    }
    if (session['financial_verified'] == true &&
        session['verification_track']?.toString() == 'Open Banking Track') {
      final bank = session['open_banking_institution']?.toString();
      if (bank != null && bank.isNotEmpty) {
        return 'Verified via $bank · Grand tier · 0.9× listing boost';
      }
      return 'Open Banking verification complete · Grand tier · 0.9× listing boost';
    }
    if (stage == TrustStage.socialVerified && lightTrust) {
      final invite = session['invite_code_verified'] == true;
      final letter = session['onboarding_letter_verified'] == true;
      if (invite && !letter) {
        return 'Invite accepted — upload your offer letter to contact hosts.';
      }
      if (!invite && letter) {
        return 'Offer letter uploaded — add an invite code to contact hosts.';
      }
      return 'Stage 2 complete · Verify to contact hosts (college email or pre-arrival path).';
    }
    if (stage == TrustStage.socialVerified) {
      final company = session['linkedin_company']?.toString().trim();
      final title = session['linkedin_title']?.toString().trim();
      if (company != null && company.isNotEmpty && title != null && title.isNotEmpty) {
        return '$title at $company · Complete ID verification to contact hosts.';
      }
      return 'Complete ID verification to contact hosts.';
    }
    if (stage == TrustStage.casual) {
      return 'Stage 1 · Browse freely · Social verification unlocks higher ranking.';
    }
    if (!canContact) {
      return 'Browse freely · Verification required before contacting hosts.';
    }
    return '';
  }

  static bool _showVerifyCta({
    required TrustStage stage,
    required bool preArrival,
    required bool lightTrust,
  }) {
    if (stage.level >= TrustStage.idVerified.level) return false;
    if (preArrival && lightTrust) {
      return true; // nudge to upgrade to uni email
    }
    return true;
  }
}

class _VerifyCtaRow extends StatelessWidget {
  const _VerifyCtaRow({
    required this.stage,
    required this.lightTrust,
    required this.preArrival,
    required this.actionColor,
  });

  final TrustStage stage;
  final bool lightTrust;
  final bool preArrival;
  final Color actionColor;

  @override
  Widget build(BuildContext context) {
    if (stage.level >= TrustStage.idVerified.level) {
      return const SizedBox.shrink();
    }

    if (preArrival && lightTrust) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/verify/id/university-email'),
        icon: const Icon(Icons.school_outlined, size: 18),
        label: const Text('Upgrade with college email'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF008A05),
          side: const BorderSide(color: Color(0xFF008A05)),
        ),
      );
    }

    if (stage.level < TrustStage.socialVerified.level) {
      return FilledButton.icon(
        onPressed: () => VerificationGatewayBottomSheet.show(context),
        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
        label: const Text('Upgrade to Grand'),
        style: FilledButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    if (lightTrust) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => context.push('/verify/id/university-email'),
            child: const Text('College email'),
          ),
          OutlinedButton(
            onPressed: () => context.push('/verify/pre-arrival'),
            child: const Text('Pre-arrival path'),
          ),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: () => context.push('/verify/id'),
      icon: const Icon(Icons.verified_user_outlined, size: 18),
      label: const Text('Start ID verification'),
      style: FilledButton.styleFrom(
        backgroundColor: actionColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

abstract final class _ProfileTrustPalette {
  static const coral = Color(0xFFFF5A5F);
}
