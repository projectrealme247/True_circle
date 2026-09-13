import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' as core show AppTypography;
import '../../models/applicant_application_status.dart';
import '../../models/application_conversation.dart';
import '../../services/application_conversation_service.dart';
import '../../services/application_lifecycle_service.dart';
import '../../services/application_service.dart';
import '../../services/applicant_management_supabase_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/application_pitch_text.dart';
import '../../utils/seeker_application_pipeline.dart';
import '../../utils/viewing_invitation.dart';
import 'seeker_application_queue_item.dart';
import 'seeker_embedded_conversation.dart';

/// Column 3 — property context, application pitch, and embedded conversation.
class SeekerApplicationPane extends StatefulWidget {
  const SeekerApplicationPane({
    super.key,
    this.item,
  });

  final SeekerApplicationQueueItem? item;

  @override
  State<SeekerApplicationPane> createState() => _SeekerApplicationPaneState();
}

class _SeekerApplicationPaneState extends State<SeekerApplicationPane> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _sending = false;
  bool _accepting = false;
  ApplicationConversation? _conversation;
  String? _bootstrappedId;

  SeekerApplicationQueueItem? get item => widget.item;

  @override
  void initState() {
    super.initState();
    applicationConversationService.addListener(_onStoreChanged);
    _bootstrapIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SeekerApplicationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.applicationId != widget.item?.applicationId) {
      _controller.clear();
      _bootstrapIfNeeded();
    }
  }

  @override
  void dispose() {
    applicationConversationService.removeListener(_onStoreChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final id = item?.applicationId;
    if (!mounted || id == null) return;
    final next = applicationConversationService.peek(id);
    if (next != null) setState(() => _conversation = next);
  }

  Future<void> _bootstrapIfNeeded() async {
    final current = item;
    if (current == null) {
      setState(() {
        _conversation = null;
        _loading = false;
        _bootstrappedId = null;
      });
      return;
    }

    if (_bootstrappedId == current.applicationId && _conversation != null) {
      return;
    }

    setState(() => _loading = true);
    await applicationConversationService.ensureLoaded();
    final conversation =
        applicationConversationService.peek(current.applicationId);
    if (conversation != null) {
      await applicationConversationService.markRead(
        applicationId: current.applicationId,
        role: ApplicationParticipantRole.applicant,
      );
    }
    if (!mounted || item?.applicationId != current.applicationId) return;
    setState(() {
      _conversation =
          applicationConversationService.peek(current.applicationId) ??
              conversation;
      _loading = false;
      _bootstrappedId = current.applicationId;
    });
  }

  Future<void> _send() async {
    final current = item;
    if (current == null) return;
    if (!SeekerApplicationPipeline.isConversationUnlocked(current.application)) {
      return;
    }
    final body = _controller.text;
    if (body.trim().isEmpty || _sending) return;

    final senderId = AuthService.identityUserId();
    if (senderId.isEmpty) return;

    setState(() => _sending = true);
    try {
      await applicationConversationService.sendMessage(
        applicationId: current.applicationId,
        senderUserId: senderId,
        senderRole: ApplicationParticipantRole.applicant,
        body: body,
      );
      await applicationConversationService.markRead(
        applicationId: current.applicationId,
        role: ApplicationParticipantRole.applicant,
      );
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _acceptViewing() async {
    final current = item;
    if (current == null || _accepting) return;
    final status = SeekerApplicationPipeline.status(current.application);
    if (status != ApplicantApplicationStatus.viewingInvitationSent) return;

    setState(() => _accepting = true);
    try {
      await ApplicationLifecycleService.acceptViewingInvitation(
        applicationId: current.applicationId,
        applicantUserId: AuthService.identityUserId(),
        currentStatus: status,
      );
      if (!mounted) return;
      setState(() {});
    } on ApplicantManagementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  String get _pitchOrFallback {
    final row = applicationService.rowById(item!.applicationId);
    final pitch = ApplicationPitchText.fromApplicationRow(row);
    if (pitch.isNotEmpty) {
      return ApplicationPitchText.displayOrFallback(pitch: pitch, fallback: '');
    }
    final created = DateTime.tryParse(row?['created_at']?.toString() ?? '');
    if (created == null) return 'Applied on this listing.';
    return 'Applied on ${SeekerApplicationPipeline.formatAppliedDate(created)}';
  }

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return Container(
        color: HomeMarketplaceTheme.canvas,
        child: Center(
          child: Text(
            'Select an application from the queue.',
            style: AppTypography.detail().copyWith(
              color: HomeMarketplaceTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    final current = item!;
    final messages = _conversation?.messages ?? const [];
    final unlocked =
        SeekerApplicationPipeline.isConversationUnlocked(current.application);
    final row = applicationService.rowById(current.applicationId);
    final invitation = ViewingInvitation.fromRow(row);
    final status = SeekerApplicationPipeline.status(current.application);
    final showInvitation = invitation != null &&
        (status == ApplicantApplicationStatus.viewingInvitationSent ||
            status == ApplicantApplicationStatus.viewingScheduled);

    return Container(
      color: HomeMarketplaceTheme.canvas,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: HomeMarketplaceTheme.primary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: _PropertySummarySection(item: current),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Application',
                        style: AppTypography.sectionMeta().copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: HomeMarketplaceTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HomeMarketplaceTheme.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Text(
                            _pitchOrFallback,
                            style: AppTypography.detail().copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (showInvitation) ...[
                        const SizedBox(height: 16),
                        _ViewingInvitationCard(
                          invitation: invitation,
                          awaitingAccept: status ==
                              ApplicantApplicationStatus.viewingInvitationSent,
                          accepting: _accepting,
                          onAccept: _acceptViewing,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SeekerEmbeddedConversation(
                    messages: messages,
                    scrollController: _scrollController,
                    messageController: _controller,
                    sending: _sending,
                    unlocked: unlocked,
                    onSend: _send,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ViewingInvitationCard extends StatelessWidget {
  const _ViewingInvitationCard({
    required this.invitation,
    required this.awaitingAccept,
    required this.accepting,
    required this.onAccept,
  });

  final ViewingInvitation invitation;
  final bool awaitingAccept;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              awaitingAccept
                  ? '📨 Viewing Invitation'
                  : '📅 Viewing Scheduled',
              style: core.AppTypography.withEmojiFallback(
                AppTypography.sectionMeta().copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Date: ${invitation.dateLabel}', style: AppTypography.detail()),
            const SizedBox(height: 4),
            Text('Time: ${invitation.timeLabel}', style: AppTypography.detail()),
            const SizedBox(height: 4),
            Text(
              'Location: ${invitation.location}',
              style: AppTypography.detail().copyWith(height: 1.35),
            ),
            if (awaitingAccept) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: accepting ? null : onAccept,
                  child: accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept Viewing'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                '✅ Viewing Accepted',
                style: core.AppTypography.withEmojiFallback(
                  AppTypography.detail().copyWith(
                    fontWeight: FontWeight.w700,
                    color: HomeMarketplaceTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PropertySummarySection extends StatelessWidget {
  const _PropertySummarySection({required this.item});

  final SeekerApplicationQueueItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.propertyTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.sectionTitle().copyWith(fontSize: 20),
        ),
        if (item.locationLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '📍 ${item.locationLabel}',
            style: AppTypography.detail().copyWith(
              color: HomeMarketplaceTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
        if (item.rentLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '💰 ${item.rentLabel}',
            style: AppTypography.detail().copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
        if (item.propertyKindLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.propertyKindLabel,
            style: core.AppTypography.withEmojiFallback(
              AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: HomeMarketplaceTheme.accentSurface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HomeMarketplaceTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Text(
              item.statusLabel,
              style: core.AppTypography.withEmojiFallback(
                AppTypography.detail().copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
