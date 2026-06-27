import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors, AppShadows;
import '../../core/widgets/app_button.dart';
import '../../models/applicant_application_status.dart';
import '../../models/applicant_trust_tier.dart';
import '../../models/independent_places_applicant_stream.dart';
import '../../theme/app_typography.dart';
import '../../utils/landlord_dashboard_helpers.dart';
import 'landlord_empty_stream_state.dart';
import 'landlord_unlock_wave_tile.dart';
import '../trust_tier_badge.dart';

class IndependentPlacesStreamView extends StatelessWidget {
  const IndependentPlacesStreamView({
    super.key,
    required this.stream,
    required this.listing,
    required this.archivedIds,
    required this.visibleLimit,
    required this.onUnlock,
    required this.onInvite,
    required this.onArchive,
    required this.onOptimizeListing,
    this.unlockLoading = false,
    this.actionLoadingId,
  });

  final IndependentPlacesApplicantStream stream;
  final Map<String, dynamic> listing;
  final Set<String> archivedIds;
  final int visibleLimit;
  final VoidCallback onUnlock;
  final Future<void> Function(IndependentPlacesApplicantRow row) onInvite;
  final void Function(IndependentPlacesApplicantRow row) onArchive;
  final VoidCallback onOptimizeListing;
  final bool unlockLoading;
  final String? actionLoadingId;

  @override
  Widget build(BuildContext context) {
    final active = stream.flattenedApplicants
        .where((r) => !archivedIds.contains(r.applicationId))
        .toList();

    if (active.isEmpty) {
      return LandlordEmptyStreamState(
        listing: listing,
        onOptimizeListing: onOptimizeListing,
      );
    }

    final visible = active.take(visibleLimit).toList();
    final remaining = active.length - visible.length;
    ApplicantTrustTier? lastTier;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: visible.length + (remaining > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return LandlordUnlockWaveTile(
            remainingCount: remaining,
            onUnlock: onUnlock,
            isLoading: unlockLoading,
          );
        }

        final row = visible[index];
        final showHeader = row.trustTier != lastTier;
        lastTier = row.trustTier;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) _TrustTierHeader(tier: row.trustTier),
            IndependentPlacesApplicantCard(
              row: row,
              onInvite: () => onInvite(row),
              onArchive: () => onArchive(row),
              isLoading: actionLoadingId == row.applicationId,
            ),
          ],
        );
      },
    );
  }
}

class _TrustTierHeader extends StatelessWidget {
  const _TrustTierHeader({required this.tier});

  final ApplicantTrustTier tier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TrustTierBadge(
        tier: tier,
        compact: true,
      ),
    );
  }
}

class IndependentPlacesApplicantCard extends StatelessWidget {
  const IndependentPlacesApplicantCard({
    super.key,
    required this.row,
    required this.onInvite,
    required this.onArchive,
    this.isLoading = false,
  });

  final IndependentPlacesApplicantRow row;
  final VoidCallback onInvite;
  final VoidCallback onArchive;
  final bool isLoading;

  bool get _dualVerified =>
      row.employmentVerified && row.corporateDocumentVerified;

  bool get _zeroDayVariance => row.timelineVarianceDays == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dualVerified
              ? const Color(LandlordDashboardTokens.emeraldHighlight)
              : AppColors.divider,
          width: _dualVerified ? 2 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.seekerName,
                        style: AppTypography.cardTitle(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${row.trustTier.displayToken} · ${row.compatibilityScore}% fit',
                        style: AppTypography.meta(),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: row.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_dualVerified)
                  const _SignalChip(
                    label: 'Dual verified',
                    icon: Icons.verified_user,
                    color: Color(LandlordDashboardTokens.emeraldHighlight),
                  ),
                if (row.moveInTimelineMatch)
                  const _SignalChip(
                    label: 'Move-in aligned',
                    icon: Icons.event_available_outlined,
                  ),
                if (row.leaseTermMatch)
                  const _SignalChip(
                    label: 'Lease term match',
                    icon: Icons.description_outlined,
                  ),
                if (_zeroDayVariance)
                  const _SignalChip(
                    label: '0-Day Timeline Variance',
                    icon: Icons.bolt,
                    bold: true,
                    color: AppColors.accent,
                  ),
              ],
            ),
            if (row.timelineVarianceDays != null && !_zeroDayVariance) ...[
              const SizedBox(height: 8),
              Text(
                'Timeline variance: ${row.timelineVarianceDays} days',
                style: AppTypography.meta().copyWith(fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Invite match',
                    size: AppButtonSize.small,
                    icon: Icons.send_rounded,
                    onPressed: isLoading ? null : onInvite,
                    isLoading: isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Archive',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.outline,
                    icon: Icons.inventory_2_outlined,
                    onPressed: isLoading ? null : onArchive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ApplicantApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ApplicantApplicationStatus.pending => 'Pending',
      ApplicantApplicationStatus.viewingScheduled => 'Viewing set',
      ApplicantApplicationStatus.accepted => 'Accepted',
      ApplicantApplicationStatus.declined => 'Declined',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.label,
    required this.icon,
    this.bold = false,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
