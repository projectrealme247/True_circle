import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/trust_service.dart';
import '../theme/trust_tier_design.dart';

/// Seeker-facing verified-user chip — ✅ Verified User when contact unlock is met.
class TrustBadge extends StatelessWidget {
  const TrustBadge({
    super.key,
    required this.isVerified,
    this.compact = false,
    this.tooltip,
    this.selected = false,
    this.onTap,
    this.showTooltip = true,
    this.outlined = false,
  });

  static const label = '✅ Verified User';
  static const tooltipMessage = 'This profile has completed verification.';

  final bool isVerified;
  final bool compact;
  final String? tooltip;
  final bool selected;
  final VoidCallback? onTap;
  final bool showTooltip;
  final bool outlined;

  /// Host listings must not show Verified User from seeker/host trust stamps.
  factory TrustBadge.fromHostTrustStage(
    int hostTrustStage, {
    Key? key,
    bool compact = true,
    bool hostVerifiedBadge = false,
  }) {
    return TrustBadge(
      key: key,
      isVerified: false,
      compact: compact,
    );
  }

  /// Session-based badge — same criteria as [TrustService.canContact].
  factory TrustBadge.fromSession(
    Map<String, dynamic>? session, {
    Key? key,
    bool compact = false,
    String? tooltip,
    bool selected = false,
    VoidCallback? onTap,
    bool showTooltip = true,
    bool outlined = false,
  }) {
    return TrustBadge(
      key: key,
      isVerified: TrustService.meetsContactVerification(session),
      compact: compact,
      tooltip: tooltip,
      selected: selected,
      onTap: onTap,
      showTooltip: showTooltip,
      outlined: outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

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
        label,
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

    if (!showTooltip) return child;

    return Tooltip(
      message: tooltip ?? tooltipMessage,
      waitDuration: const Duration(milliseconds: 350),
      preferBelow: false,
      child: child,
    );
  }
}
