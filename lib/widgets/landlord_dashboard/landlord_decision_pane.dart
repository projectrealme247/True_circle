import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/applicant_application_status.dart';
import '../../models/application_conversation.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../services/application_conversation_service.dart';
import '../../services/listing_contact_service.dart';
import 'landlord_dashboard_theme.dart';
import 'landlord_decision_summary_panel.dart';
import 'landlord_embedded_conversation.dart';
import 'landlord_trust_tier_pill.dart';

/// Column 3 — applicant workspace + embedded conversation.
class LandlordDecisionPane extends StatelessWidget {
  const LandlordDecisionPane({
    super.key,
    required this.applicant,
    required this.onInvite,
    required this.onReschedule,
    required this.onCancelViewing,
    required this.onArchive,
    this.actionLoadingId,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final LandlordApplicantCardModel? applicant;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onReschedule;
  final ValueChanged<LandlordApplicantCardModel> onCancelViewing;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: LandlordDashboardTheme.surfaceRaised,
      ),
      child: applicant == null
          ? const _EmptyDecision()
          : _DecisionBody(
              applicant: applicant!,
              onInvite: onInvite,
              onReschedule: onReschedule,
              onCancelViewing: onCancelViewing,
              onArchive: onArchive,
              actionLoadingId: actionLoadingId,
              hostPhoneE164: hostPhoneE164,
              hostPrefersWhatsapp: hostPrefersWhatsapp,
              listingTitle: listingTitle,
            ),
    );
  }
}

class _EmptyDecision extends StatelessWidget {
  const _EmptyDecision();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Pick someone from the queue.',
          textAlign: TextAlign.center,
          style: LandlordDashboardTheme.cardSubtext().copyWith(
            fontSize: 15,
            color: LandlordDashboardTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DecisionBody extends StatefulWidget {
  const _DecisionBody({
    required this.applicant,
    required this.onInvite,
    required this.onReschedule,
    required this.onCancelViewing,
    required this.onArchive,
    this.actionLoadingId,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final LandlordApplicantCardModel applicant;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onReschedule;
  final ValueChanged<LandlordApplicantCardModel> onCancelViewing;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  @override
  State<_DecisionBody> createState() => _DecisionBodyState();
}

class _DecisionBodyState extends State<_DecisionBody> {
  final _composerFocus = FocusNode();

  LandlordApplicantCardModel get applicant => widget.applicant;

  bool get _contactUnlocked =>
      applicant.status == ApplicantApplicationStatus.viewingScheduled ||
      applicant.status == ApplicantApplicationStatus.accepted;

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  void _focusComposer() {
    _composerFocus.requestFocus();
  }

  Future<void> _openWhatsAppHandoff(BuildContext context) async {
    final phone = widget.hostPhoneE164 ?? '';
    final uri = ListingContactService.whatsAppHandoffUri(
      phoneE164: phone,
      listingTitle: widget.listingTitle,
      applicantName: applicant.seekerName,
    );
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a phone number with WhatsApp enabled in your profile.',
          ),
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
          'WhatsApp link copied. TrueCircle does not monitor external messages.',
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
    final loading = widget.actionLoadingId == applicant.applicationId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                applicant.seekerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: LandlordDashboardTheme.decisionName(size: 28),
              ),
              const SizedBox(height: 8),
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
                    style: LandlordDashboardTheme.cardSubtext().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LandlordDecisionSummaryPanel(applicant: applicant),
              const SizedBox(height: 12),
              _ApplicationBlock(text: applicant.bioPitch),
              if (_contactUnlocked && widget.hostPrefersWhatsapp) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openWhatsAppHandoff(context),
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: const Text('Copy WhatsApp link'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: LandlordDashboardTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: LandlordDashboardTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LandlordDashboardTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: LandlordEmbeddedConversation(
                  key: ValueKey(applicant.applicationId),
                  applicant: applicant,
                  composerFocusNode: _composerFocus,
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: const BoxDecoration(
            color: LandlordDashboardTheme.surface,
            border: Border(
              top: BorderSide(color: LandlordDashboardTheme.border),
            ),
          ),
          child: _ActionBar(
            applicant: applicant,
            loading: loading,
            onInvite: () => widget.onInvite(applicant),
            onReschedule: () => widget.onReschedule(applicant),
            onCancelViewing: () => widget.onCancelViewing(applicant),
            onArchive: () => widget.onArchive(applicant),
            onMessage: _focusComposer,
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.applicant,
    required this.loading,
    required this.onInvite,
    required this.onReschedule,
    required this.onCancelViewing,
    required this.onArchive,
    required this.onMessage,
  });

  final LandlordApplicantCardModel applicant;
  final bool loading;
  final VoidCallback onInvite;
  final VoidCallback onReschedule;
  final VoidCallback onCancelViewing;
  final VoidCallback onArchive;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final status = applicant.status;
    if (status == ApplicantApplicationStatus.declined) {
      return const Text(
        'Application rejected — read only.',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          color: LandlordDashboardTheme.textMuted,
        ),
      );
    }

    final showInvite = status == ApplicantApplicationStatus.pending;
    final showViewingControls =
        status == ApplicantApplicationStatus.viewingInvitationSent ||
            status == ApplicantApplicationStatus.viewingScheduled;
    final showReject = status != ApplicantApplicationStatus.accepted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (showInvite)
                FilledButton(
                  onPressed: loading ? null : onInvite,
                  style: FilledButton.styleFrom(
                    backgroundColor: LandlordDashboardTheme.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Invite Viewing'),
                ),
              if (showViewingControls) ...[
                FilledButton(
                  onPressed: loading ? null : onReschedule,
                  style: FilledButton.styleFrom(
                    backgroundColor: LandlordDashboardTheme.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Reschedule Viewing'),
                ),
                OutlinedButton(
                  onPressed: loading ? null : onCancelViewing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LandlordDashboardTheme.textPrimary,
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(
                      color: LandlordDashboardTheme.borderStrong,
                    ),
                  ),
                  child: const Text('Cancel Viewing'),
                ),
              ],
              ListenableBuilder(
                listenable: applicationConversationService,
                builder: (context, _) {
                  final unread = applicationConversationService.unreadCount(
                    applicationId: applicant.applicationId,
                    role: ApplicationParticipantRole.host,
                  );
                  return OutlinedButton(
                    onPressed: loading ? null : onMessage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LandlordDashboardTheme.textPrimary,
                      minimumSize: const Size(0, 40),
                      side: const BorderSide(
                        color: LandlordDashboardTheme.borderStrong,
                      ),
                    ),
                    child: Text(
                      unread > 0 ? 'Message ($unread)' : 'Message',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (showReject)
          TextButton(
            onPressed: loading ? null : onArchive,
            style: TextButton.styleFrom(
              foregroundColor: LandlordDashboardTheme.textMuted,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Reject'),
          ),
      ],
    );
  }
}

class _ApplicationBlock extends StatefulWidget {
  const _ApplicationBlock({required this.text});

  final String text;

  @override
  State<_ApplicationBlock> createState() => _ApplicationBlockState();
}

class _ApplicationBlockState extends State<_ApplicationBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Application',
          style: LandlordDashboardTheme.railEyebrow().copyWith(
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: LandlordDashboardTheme.canvas,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LandlordDashboardTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: _expanded ? 12 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: LandlordDashboardTheme.personName(size: 16).copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    letterSpacing: -0.2,
                  ),
                ),
                if (text.length > 160)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      foregroundColor: LandlordDashboardTheme.textSecondary,
                    ),
                    child: Text(_expanded ? 'Show less' : 'Show more'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
