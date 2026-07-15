import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/applicant_trust_tier.dart';
import '../theme/trust_tier_design.dart';
import '../utils/viewer_profile.dart';

/// Single source of truth for Just Landed / Grand / Sound trust badge pills.
class TrustBadge extends StatelessWidget {
  const TrustBadge({
    super.key,
    required this.tier,
    this.compact = false,
    this.tooltip,
    this.labelSuffix = '',
    this.selected = false,
    this.onTap,
    this.showTooltip = true,
    this.outlined = false,
  });

  final ApplicantTrustTier tier;
  final bool compact;
  final String? tooltip;
  final String labelSuffix;
  final bool selected;
  final VoidCallback? onTap;
  final bool showTooltip;
  final bool outlined;

  factory TrustBadge.fromTrustStage(
    TrustStage stage, {
    Key? key,
    bool compact = false,
    String? tooltip,
    String labelSuffix = '',
    bool selected = false,
    VoidCallback? onTap,
    bool showTooltip = true,
    bool outlined = false,
  }) {
    return TrustBadge(
      key: key,
      tier: TrustTierDesign.fromTrustStage(stage),
      compact: compact,
      tooltip: tooltip,
      labelSuffix: labelSuffix,
      selected: selected,
      onTap: onTap,
      showTooltip: showTooltip,
      outlined: outlined,
    );
  }

  factory TrustBadge.fromHostTrustStage(
    int hostTrustStage, {
    Key? key,
    bool compact = true,
    String labelSuffix = ' host',
  }) {
    return TrustBadge(
      key: key,
      tier: tierFromHostTrustStage(hostTrustStage),
      compact: compact,
      labelSuffix: labelSuffix,
    );
  }

  static ApplicantTrustTier tierFromHostTrustStage(int hostTrustStage) =>
      switch (hostTrustStage) {
        3 => ApplicantTrustTier.sound,
        2 => ApplicantTrustTier.grand,
        _ => ApplicantTrustTier.justLanded,
      };

  static String labelFor(ApplicantTrustTier tier) =>
      TrustTierDesign.labelFor(tier);

  static String emojiLabelFor(ApplicantTrustTier tier) =>
      TrustTierDesign.trustScaleEmojiLabel(tier);

  static String tooltipFor(ApplicantTrustTier tier) => switch (tier) {
        ApplicantTrustTier.justLanded =>
          'Just Landed tier requires:\n'
          'Verified arrival intent signal\n'
          'Pre-arrival housing circle profile\n'
          'Funding capacity token on file',
        ApplicantTrustTier.grand =>
          'Grand tier requires:\n'
          'Active .ac.ie institutional domain check\n'
          'Identity and document hash verification\n'
          'On-campus student status confirmation',
        ApplicantTrustTier.sound =>
          'Sound tier requires:\n'
          'Gov API identity match token\n'
          'Income verified >3.5x rent target\n'
          'Fully vouched by community references',
      };

  String get _label =>
      '${TrustTierDesign.trustScaleEmojiLabel(tier)}$labelSuffix';

  @override
  Widget build(BuildContext context) {
    const bg = TrustTierDesign.trustScaleCapsuleBg;
    const text = TrustTierDesign.trustScaleCapsuleText;
    final badge = Container(
      padding: TrustTierDesign.trustScaleCapsulePadding,
      decoration: BoxDecoration(
        color: outlined ? AppColors.surface : bg,
        borderRadius:
            BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
        border: outlined
            ? Border.all(color: text.withValues(alpha: 0.35), width: 1)
            : (selected
                ? Border.all(color: text.withValues(alpha: 0.45), width: 1.2)
                : null),
      ),
      child: Text(
        _label,
        style: TrustTierDesign.trustScaleLabelStyle(
          compact: compact,
          color: text,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: onTap != null ? TextAlign.center : null,
      ),
    );

    Widget child = badge;
    if (onTap != null) {
      child = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(TrustTierDesign.trustScaleCapsuleRadius),
          child: badge,
        ),
      );
    }

    final message = tooltip ?? tooltipFor(tier);
    if (!showTooltip) return child;

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 350),
      preferBelow: false,
      child: child,
    );
  }
}
