import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/applicant_application_status.dart';
import '../../models/application_conversation.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../services/application_conversation_service.dart';
import '../../services/listing_contact_service.dart';
import 'affordability_multiplier_chip.dart';
import 'landlord_dashboard_theme.dart';
import 'landlord_decision_summary_panel.dart';
import 'landlord_embedded_conversation.dart';
import 'landlord_trust_tier_pill.dart';

/// Split two-column pipeline: applicant preview feed + passport workspace.
class LandlordPipelineWorkspace extends StatelessWidget {
  const LandlordPipelineWorkspace({
    super.key,
    required this.applicants,
    required this.selectedId,
    required this.onSelect,
    required this.onInvite,
    required this.onArchive,
    this.actionLoadingId,
    this.onOptimizeListing,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final List<LandlordApplicantCardModel> applicants;
  final String? selectedId;
  final ValueChanged<LandlordApplicantCardModel> onSelect;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final VoidCallback? onOptimizeListing;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  LandlordApplicantCardModel? get _selected {
    if (selectedId == null) return applicants.isNotEmpty ? applicants.first : null;
    return applicants.cast<LandlordApplicantCardModel?>().firstWhere(
          (a) => a!.applicationId == selectedId,
          orElse: () => applicants.isNotEmpty ? applicants.first : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (applicants.isEmpty) {
      return _EmptyPipeline(onOptimizeListing: onOptimizeListing);
    }

    final selected = _selected!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 220,
                child: _ApplicantPreviewFeed(
                  applicants: applicants,
                  selectedId: selected.applicationId,
                  onSelect: onSelect,
                  horizontal: true,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ApplicantPassport(
                  applicant: selected,
                  onInvite: onInvite,
                  onArchive: onArchive,
                  actionLoadingId: actionLoadingId,
                  hostPhoneE164: hostPhoneE164,
                  hostPrefersWhatsapp: hostPrefersWhatsapp,
                  listingTitle: listingTitle,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 380,
              child: _ApplicantPreviewFeed(
                applicants: applicants,
                selectedId: selected.applicationId,
                onSelect: onSelect,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _ApplicantPassport(
                applicant: selected,
                onInvite: onInvite,
                onArchive: onArchive,
                actionLoadingId: actionLoadingId,
                hostPhoneE164: hostPhoneE164,
                hostPrefersWhatsapp: hostPrefersWhatsapp,
                listingTitle: listingTitle,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApplicantPreviewFeed extends StatelessWidget {
  const _ApplicantPreviewFeed({
    required this.applicants,
    required this.selectedId,
    required this.onSelect,
    this.horizontal = false,
  });

  final List<LandlordApplicantCardModel> applicants;
  final String selectedId;
  final ValueChanged<LandlordApplicantCardModel> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: applicants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final row = applicants[index];
          return SizedBox(
            width: 300,
            child: _PreviewCard(
              applicant: row,
              selected: row.applicationId == selectedId,
              onTap: () => onSelect(row),
            ),
          );
        },
      );
    }

    return _verticalFeedWithScrollFade(
      ListView.separated(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        itemCount: applicants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final row = applicants[index];
          return _PreviewCard(
            applicant: row,
            selected: row.applicationId == selectedId,
            onTap: () => onSelect(row),
          );
        },
      ),
    );
  }

  Widget _verticalFeedWithScrollFade(Widget list) {
    return Stack(
      children: [
        list,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 40,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.applicant,
    required this.selected,
    required this.onTap,
  });

  final LandlordApplicantCardModel applicant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: LandlordDashboardTheme.cardDecoration(selected: selected),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      applicant.seekerName,
                      style: LandlordDashboardTheme.sectionTitle(size: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: applicationConversationService,
                    builder: (context, _) {
                      final unread =
                          applicationConversationService.unreadCount(
                        applicationId: applicant.applicationId,
                        role: ApplicationParticipantRole.host,
                      );
                      if (unread <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: LandlordDashboardTheme.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${applicant.matchPercent}% Match',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LandlordDashboardTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AffordabilityMultiplierChip(
                multiplier: applicant.affordabilityMultiplier,
                fullWidth: true,
                compact: true,
              ),
              if (applicant.budgetLabel != null ||
                  applicant.commuteLabel != null ||
                  applicant.moveInLabel != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (applicant.budgetLabel != null)
                      _ApplicantMetaChip(label: applicant.budgetLabel!),
                    if (applicant.commuteLabel != null)
                      _ApplicantMetaChip(label: applicant.commuteLabel!),
                    if (applicant.moveInLabel != null)
                      _ApplicantMetaChip(label: applicant.moveInLabel!),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              LandlordTrustTierPill(
                isVerified: applicant.isVerifiedUser,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantPassport extends StatelessWidget {
  const _ApplicantPassport({
    required this.applicant,
    required this.onInvite,
    required this.onArchive,
    this.actionLoadingId,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final LandlordApplicantCardModel applicant;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  bool get _contactUnlocked =>
      applicant.status == ApplicantApplicationStatus.viewingScheduled ||
      applicant.status == ApplicantApplicationStatus.accepted;

  Future<void> _openWhatsAppHandoff(BuildContext context) async {
    final phone = hostPhoneE164 ?? '';
    final uri = ListingContactService.whatsAppHandoffUri(
      phoneE164: phone,
      listingTitle: listingTitle,
      applicantName: applicant.seekerName,
    );
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a phone number with WhatsApp enabled in your profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri));
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continue on WhatsApp'),
        content: const Text(
          'WhatsApp link copied. TrueCircle does not monitor external messages.\n\n'
          'Open WhatsApp and paste the link, or use your usual chat app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = actionLoadingId == applicant.applicationId;

    return Container(
      decoration: LandlordDashboardTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          applicant.seekerName,
                          style: LandlordDashboardTheme.sectionTitle(size: 26),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusBadge(label: applicant.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Decision summary',
                    style: LandlordDashboardTheme.cardSubtext().copyWith(
                      fontSize: 12,
                      color: LandlordDashboardTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LandlordDecisionSummaryPanel(applicant: applicant),
                  LandlordEmbeddedConversation(
                    key: ValueKey(applicant.applicationId),
                    applicant: applicant,
                  ),
                  if (_contactUnlocked && hostPrefersWhatsapp) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact milestone reached',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You can coordinate the viewing off-platform. '
                            'TrueCircle does not monitor external messages.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF15803D),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => _openWhatsAppHandoff(context),
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('Copy WhatsApp link'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: LandlordDashboardTheme.border),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton(
                  onPressed: loading ||
                          applicant.status != ApplicantApplicationStatus.pending
                      ? null
                      : () => onInvite(applicant),
                  style: FilledButton.styleFrom(
                    backgroundColor: LandlordDashboardTheme.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(128, 40),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Invite viewing'),
                ),
                OutlinedButton(
                  onPressed: loading
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offer flow coming soon.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: const Text('Offer'),
                ),
                OutlinedButton(
                  onPressed: loading ? null : () => onArchive(applicant),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LandlordDashboardTheme.textSecondary,
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantMetaChip extends StatelessWidget {
  const _ApplicantMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: LandlordDashboardTheme.textSecondary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.canvas,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: LandlordDashboardTheme.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyPipeline extends StatelessWidget {
  const _EmptyPipeline({this.onOptimizeListing});

  final VoidCallback? onOptimizeListing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: LandlordDashboardTheme.cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: LandlordDashboardTheme.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No matches in this cohort yet',
            style: LandlordDashboardTheme.sectionTitle(size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tune your listing preferences or check another trust tier tab.',
            style: LandlordDashboardTheme.cardSubtext(),
            textAlign: TextAlign.center,
          ),
          if (onOptimizeListing != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: onOptimizeListing,
              child: const Text('Optimize listing'),
            ),
          ],
        ],
      ),
    );
  }
}
