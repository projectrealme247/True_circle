import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors, AppShadows;
import '../../core/widgets/app_button.dart';
import '../../models/applicant_application_status.dart';
import '../../models/applicant_trust_tier.dart';
import '../../models/shared_living_applicant_stream.dart';
import '../../theme/app_typography.dart';
import '../../utils/landlord_dashboard_helpers.dart';
import 'landlord_empty_stream_state.dart';
import 'landlord_unlock_wave_tile.dart';
import 'lifestyle_match_score_ring.dart';

class SharedLivingStreamView extends StatelessWidget {
  const SharedLivingStreamView({
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

  final SharedLivingApplicantStream stream;
  final Map<String, dynamic> listing;
  final Set<String> archivedIds;
  final int visibleLimit;
  final VoidCallback onUnlock;
  final Future<void> Function(SharedLivingApplicantRow row) onInvite;
  final void Function(SharedLivingApplicantRow row) onArchive;
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
        return SharedLivingApplicantCard(
          row: row,
          onInvite: () => onInvite(row),
          onArchive: () => onArchive(row),
          isLoading: actionLoadingId == row.applicationId,
        );
      },
    );
  }
}

class SharedLivingApplicantCard extends StatelessWidget {
  const SharedLivingApplicantCard({
    super.key,
    required this.row,
    required this.onInvite,
    required this.onArchive,
    this.isLoading = false,
  });

  final SharedLivingApplicantRow row;
  final VoidCallback onInvite;
  final VoidCallback onArchive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MatchScoreWithCommuteChip(
                  percent: row.overallMatchScore ?? row.lifestyleMatchScorePercent,
                  transitDurationSeconds: row.verifiedTransitDurationSeconds,
                  ringSize: 64,
                  stackChip: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.seekerName,
                        style: AppTypography.cardTitle().copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${row.decision?.isVerifiedUser == true ? ApplicantTrustTier.verifiedUserLabel : 'Verification pending'} · Lifestyle match',
                        style: AppTypography.meta(),
                      ),
                      if (row.kitchenCultureAligned) ...[
                        const SizedBox(height: 6),
                        const _SignalChip(
                          label: 'Kitchen culture aligned',
                          icon: Icons.restaurant_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(status: row.status),
              ],
            ),
            const SizedBox(height: 14),
            _OverlappingLanguageChips(
              languages: row.seekerLanguages,
              nativeLanguages: row.languageAlignmentOverlap,
            ),
            if (row.customBioPitch.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(LandlordDashboardTokens.magazineQuoteBg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  '“${row.customBioPitch}”',
                  style: AppTypography.detail().copyWith(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Invite match',
                    size: AppButtonSize.small,
                    icon: Icons.favorite_outline,
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
                    icon: Icons.archive_outlined,
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

class _OverlappingLanguageChips extends StatelessWidget {
  const _OverlappingLanguageChips({
    required this.languages,
    required this.nativeLanguages,
  });

  final List<String> languages;
  final List<String> nativeLanguages;

  @override
  Widget build(BuildContext context) {
    if (languages.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < languages.length; i++)
            Positioned(
              left: i * 22.0,
              child: _LanguageChip(
                label: languages[i],
                showStar: nativeLanguages
                    .map((l) => l.toLowerCase())
                    .contains(languages[i].toLowerCase()),
                highlighted: i == 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.showStar,
    required this.highlighted,
  });

  final String label;
  final bool showStar;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? AppColors.accent
              : const Color(LandlordDashboardTokens.unselectedGrey)
                  .withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStar) ...[
            Icon(
              Icons.star_rounded,
              size: 12,
              color: highlighted ? Colors.white : AppColors.accent,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlighted ? Colors.white : AppColors.primaryText,
            ),
          ),
        ],
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
      ApplicantApplicationStatus.viewingInvitationSent => 'Invitation sent',
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
  const _SignalChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(LandlordDashboardTokens.emeraldHighlight)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(LandlordDashboardTokens.emeraldHighlight)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(LandlordDashboardTokens.emeraldHighlight),
            ),
          ),
        ],
      ),
    );
  }
}
