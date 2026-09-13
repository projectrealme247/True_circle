import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/applicant_application_status.dart';
import '../../models/application_conversation.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../services/application_conversation_service.dart';
import '../../utils/landlord_queue_buckets.dart';
import 'landlord_dashboard_theme.dart';
import 'landlord_decision_summary_panel.dart';
import 'landlord_trust_tier_pill.dart';

/// Column 2 — applicant queue grouped by viewing lifecycle.
class LandlordApplicantQueue extends StatelessWidget {
  const LandlordApplicantQueue({
    super.key,
    required this.applicants,
    required this.selectedId,
    required this.onSelect,
  });

  final List<LandlordApplicantCardModel> applicants;
  final String? selectedId;
  final ValueChanged<LandlordApplicantCardModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final buckets = LandlordQueueBuckets.from(applicants);

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: LandlordDashboardTheme.surface,
        border: Border(
          right: BorderSide(color: LandlordDashboardTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text(
                  'Queue',
                  style: LandlordDashboardTheme.railEyebrow(),
                ),
                const Spacer(),
                Text(
                  '${applicants.length}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: LandlordDashboardTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: applicants.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No applicants yet.',
                        textAlign: TextAlign.center,
                        style: AppTypography.withEmojiFallback(
                          const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            height: 1.4,
                            color: LandlordDashboardTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                    children: [
                      for (final section in LandlordQueueSection.values)
                        if (buckets.forSection(section).isNotEmpty) ...[
                          _SectionHeader(
                            label: section.label,
                            count: buckets.forSection(section).length,
                          ),
                          for (final applicant in buckets.forSection(section))
                            _QueueRow(
                              applicant: applicant,
                              selected: applicant.applicationId == selectedId,
                              onTap: () => onSelect(applicant),
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.withEmojiFallback(
                const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: LandlordDashboardTheme.textMuted,
                ),
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: LandlordDashboardTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.applicant,
    required this.selected,
    required this.onTap,
  });

  final LandlordApplicantCardModel applicant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? LandlordDashboardTheme.selectionFill
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: selected
                      ? LandlordDashboardTheme.ink
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicant.seekerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LandlordDashboardTheme.personName(size: 14).copyWith(
                          color: applicant.status ==
                                  ApplicantApplicationStatus.declined
                              ? LandlordDashboardTheme.textMuted
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LandlordTrustTierPill(
                            isVerified: applicant.isVerifiedUser,
                            compact: true,
                          ),
                          Text(
                            applicant.statusLabel,
                            style: LandlordDashboardTheme.cardSubtext(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LandlordApplicantSummaryFacts.queueHint(applicant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.withEmojiFallback(
                          LandlordDashboardTheme.cardSubtext().copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListenableBuilder(
                  listenable: applicationConversationService,
                  builder: (context, _) {
                    final unread = applicationConversationService.unreadCount(
                      applicationId: applicant.applicationId,
                      role: ApplicationParticipantRole.host,
                    );
                    if (unread <= 0) return const SizedBox.shrink();
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        color: LandlordDashboardTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
