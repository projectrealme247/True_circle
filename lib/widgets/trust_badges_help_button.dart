import 'package:flutter/material.dart';

import '../models/applicant_trust_tier.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/trust_tier_tooltips.dart';
import 'trust_badge.dart';

/// Compact help affordance for host trust badges on listing cards.
class TrustBadgesHelpButton extends StatelessWidget {
  const TrustBadgesHelpButton({super.key});

  static Future<void> showExplainer(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const _TrustBadgesHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'What do trust badges mean?',
      onPressed: () => showExplainer(context),
      icon: const Icon(Icons.help_outline_rounded, size: 18),
      color: HomeMarketplaceTheme.textSecondary,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TrustBadgesHelpDialog extends StatelessWidget {
  const _TrustBadgesHelpDialog();

  static const _tiers = [
    ApplicantTrustTier.sound,
    ApplicantTrustTier.grand,
    ApplicantTrustTier.justLanded,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'What do trust badges mean?',
        style: AppTypography.sectionTitle().copyWith(
          fontWeight: FontWeight.w700,
          color: HomeMarketplaceTheme.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Host trust badges show how verified a listing publisher is. '
            'They sit below match chips and never replace match quality.',
            style: AppTypography.detail().copyWith(
              color: HomeMarketplaceTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (final tier in _tiers) ...[
            _TrustTierHelpRow(tier: tier),
            if (tier != ApplicantTrustTier.justLanded) const SizedBox(height: 12),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _TrustTierHelpRow extends StatelessWidget {
  const _TrustTierHelpRow({required this.tier});

  final ApplicantTrustTier tier;

  @override
  Widget build(BuildContext context) {
    final body = switch (tier) {
      ApplicantTrustTier.justLanded => TrustTierTooltips.justLanded,
      ApplicantTrustTier.grand => TrustTierTooltips.grand,
      ApplicantTrustTier.sound => TrustTierTooltips.sound,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrustBadge(
          tier: tier,
          compact: true,
          labelSuffix: ' Host',
          showTooltip: false,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            body,
            style: AppTypography.detail().copyWith(
              fontSize: 13,
              height: 1.35,
              color: HomeMarketplaceTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
