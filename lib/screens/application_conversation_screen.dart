import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' as core
    show AppColors, AppButtonStyles, AppTypography;
import '../models/applicant_application_status.dart';
import '../models/applicant_field_keys.dart';
import '../models/application_conversation.dart';
import '../models/application_message.dart';
import '../models/landlord_applicant_card_model.dart';
import '../models/listing_application.dart';
import '../services/application_conversation_service.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/listings_storage_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import '../widgets/seeker_applications/seeker_application_pane.dart';
import '../widgets/seeker_applications/seeker_application_queue_item.dart';

class ApplicationConversationRouteArgs {
  const ApplicationConversationRouteArgs({
    required this.listingId,
    required this.applicantUserId,
    required this.hostUserId,
    required this.viewerRole,
    this.listingTitle = '',
    this.peerName = '',
  });

  final String listingId;
  final String applicantUserId;
  final String hostUserId;
  final ApplicationParticipantRole viewerRole;
  final String listingTitle;
  final String peerName;
}

/// Application workspace with embedded conversation.
class ApplicationConversationScreen extends StatefulWidget {
  const ApplicationConversationScreen({
    super.key,
    required this.applicationId,
    this.args,
  });

  final String applicationId;
  final ApplicationConversationRouteArgs? args;

  static String locationFor(String applicationId) =>
      '/application/$applicationId/conversation';

  static String currentUserId() => AuthService.identityUserId();

  static Future<void> openFromHost(
    BuildContext context, {
    required LandlordApplicantCardModel applicant,
    String listingTitle = '',
  }) async {
    await openFromHostArgs(
      context,
      applicationId: applicant.applicationId,
      listingId: applicant.listingId,
      applicantUserId: applicant.applicantUserId,
      listingTitle: listingTitle,
      peerName: applicant.seekerName,
    );
  }

  static Future<void> openFromHostArgs(
    BuildContext context, {
    required String applicationId,
    required String listingId,
    required String applicantUserId,
    String listingTitle = '',
    String peerName = '',
  }) async {
    final hostUserId = currentUserId();
    await context.push(
      locationFor(applicationId),
      extra: ApplicationConversationRouteArgs(
        listingId: listingId,
        applicantUserId: applicantUserId,
        hostUserId: hostUserId,
        viewerRole: ApplicationParticipantRole.host,
        listingTitle: listingTitle,
        peerName: peerName,
      ),
    );
  }

  static Future<void> openFromSeeker(
    BuildContext context, {
    required ListingApplication application,
    required String listingTitle,
    String hostName = 'Host',
  }) async {
    final listing = await ListingsStorageService.getById(application.listingId);
    final hostUserId =
        ApplicationConversationService.hostUserIdFromListing(listing);
    final resolvedHostName = ListingData.hostName(listing ?? const {});
    if (!context.mounted) return;
    await context.push(
      locationFor(application.id),
      extra: ApplicationConversationRouteArgs(
        listingId: application.listingId,
        applicantUserId: application.userId,
        hostUserId: hostUserId,
        viewerRole: ApplicationParticipantRole.applicant,
        listingTitle: listingTitle,
        peerName: resolvedHostName.isEmpty ? hostName : resolvedHostName,
      ),
    );
  }

  @override
  State<ApplicationConversationScreen> createState() =>
      _ApplicationConversationScreenState();
}

class _ApplicationConversationScreenState
    extends State<ApplicationConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  ApplicationConversation? _conversation;
  Map<String, dynamic>? _seekerListing;

  ApplicationParticipantRole get _role =>
      widget.args?.viewerRole ?? ApplicationParticipantRole.applicant;

  Map<String, dynamic>? get _applicationRow =>
      applicationService.rowById(widget.applicationId);

  String get _statusDisplay {
    final raw = _applicationRow?['status']?.toString() ?? '';
    final status = ApplicantApplicationStatus.parseOrDefault(raw);
    final token = raw.trim().toLowerCase();
    if (token == 'withdrawn') return '❌ Withdrawn';
    if (token == 'closed') return '❌ Closed';
    return switch (status) {
      ApplicantApplicationStatus.pending => '⏳ Pending',
      ApplicantApplicationStatus.viewingInvitationSent =>
        '📨 Viewing Invitation Sent',
      ApplicantApplicationStatus.viewingScheduled => '📅 Viewing Scheduled',
      ApplicantApplicationStatus.accepted => '✅ Accepted',
      ApplicantApplicationStatus.declined => '❌ Declined',
    };
  }

  String get _pitchOrFallback {
    final row = _applicationRow;
    final payload = row?['payload'];
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      for (final key in const [
        ApplicantFieldKeys.pitchNarrative,
        ApplicantFieldKeys.personalIntroduction,
        ApplicantFieldKeys.bio,
        ApplicantFieldKeys.aboutMe,
      ]) {
        final value = ProfileData.text(map[key]);
        if (value.isNotEmpty) return value;
      }
    }
    final created = DateTime.tryParse(row?['created_at']?.toString() ?? '');
    if (created == null) return 'Applied on this listing.';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Applied on ${months[created.month - 1]} ${created.day}';
  }

  @override
  void initState() {
    super.initState();
    applicationConversationService.addListener(_onStoreChanged);
    if (_role != ApplicationParticipantRole.applicant) {
      _bootstrap();
    } else {
      _loadSeekerListing();
    }
  }

  Future<void> _loadSeekerListing() async {
    final listingId = widget.args?.listingId ?? '';
    if (listingId.isEmpty) return;
    final listing = await ListingsStorageService.getById(listingId);
    if (!mounted || listing == null) return;
    setState(() => _seekerListing = listing);
  }

  @override
  void dispose() {
    applicationConversationService.removeListener(_onStoreChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    final next = applicationConversationService.peek(widget.applicationId);
    if (!mounted || next == null) return;
    setState(() => _conversation = next);
  }

  Future<void> _bootstrap() async {
    final args = widget.args;
    final conversation =
        await applicationConversationService.ensureConversation(
      applicationId: widget.applicationId,
      listingId: args?.listingId ?? '',
      applicantUserId: args?.applicantUserId ?? '',
      hostUserId: args?.hostUserId ?? '',
    );
    await applicationConversationService.markRead(
      applicationId: widget.applicationId,
      role: _role,
    );
    if (!mounted) return;
    setState(() {
      _conversation = applicationConversationService.peek(widget.applicationId) ??
          conversation;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final body = _controller.text;
    if (body.trim().isEmpty || _sending) return;

    final senderId = ApplicationConversationScreen.currentUserId();
    if (senderId.isEmpty) return;

    setState(() => _sending = true);
    try {
      await applicationConversationService.sendMessage(
        applicationId: widget.applicationId,
        senderUserId: senderId,
        senderRole: _role,
        body: body,
      );
      await applicationConversationService.markRead(
        applicationId: widget.applicationId,
        role: _role,
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

  SeekerApplicationQueueItem? _seekerQueueItem() {
    final row = _applicationRow;
    if (row == null) return null;
    final application = ListingApplication.fromMap(row);
    final listingTitle = widget.args?.listingTitle ?? '';
    final hostName = widget.args?.peerName.isNotEmpty == true
        ? widget.args!.peerName
        : 'Host';
    return SeekerApplicationQueueItem.fromApplication(
      application: application,
      propertyTitle: listingTitle.isNotEmpty ? listingTitle : 'Application',
      hostName: hostName,
      hostUserId: widget.args?.hostUserId ?? '',
      listing: _seekerListing,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_role == ApplicationParticipantRole.applicant) {
      final listingTitle = widget.args?.listingTitle ?? '';
      final identityTitle =
          listingTitle.isNotEmpty ? listingTitle : 'Application';
      return Scaffold(
        backgroundColor: HomeMarketplaceTheme.canvas,
        appBar: AppBar(
          title: Text(
            identityTitle,
            style: AppTypography.appBarBrand(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SeekerApplicationPane(item: _seekerQueueItem()),
      );
    }

    final peer = widget.args?.peerName.isNotEmpty == true
        ? widget.args!.peerName
        : (_role == ApplicationParticipantRole.host ? 'Applicant' : 'Host');
    final listingTitle = widget.args?.listingTitle ?? '';
    final messages = _conversation?.messages ?? const <ApplicationMessage>[];
    final identityTitle =
        listingTitle.isNotEmpty ? listingTitle : 'Application';
    final hostLine = _role == ApplicationParticipantRole.host
        ? 'Applicant: $peer'
        : 'Host: $peer';

    return Scaffold(
      backgroundColor: HomeMarketplaceTheme.canvas,
      appBar: AppBar(
        title: Text(
          identityTitle,
          style: AppTypography.appBarBrand(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: core.AppColors.accent),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hostLine,
                        style: AppTypography.detail().copyWith(
                          color: HomeMarketplaceTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: $_statusDisplay',
                        style: core.AppTypography.withEmojiFallback(
                          AppTypography.detail().copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_role == ApplicationParticipantRole.applicant) ...[
                        const SizedBox(height: 14),
                        Text(
                          'YOUR APPLICATION',
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
                            border: Border.all(
                              color: HomeMarketplaceTheme.border,
                            ),
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
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'CONVERSATION',
                        style: AppTypography.sectionMeta().copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HomeMarketplaceTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HomeMarketplaceTheme.border),
                      ),
                      child: messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No messages yet.\n\nSend the first message to start the conversation.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.detail().copyWith(
                                    color: HomeMarketplaceTheme.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final mine = message.senderRole == _role;
                                return _MessageBubble(
                                  message: message,
                                  mine: mine,
                                );
                              },
                            ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            maxLength:
                                ApplicationConversationService.maxBodyLength,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Write a message',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _sending ? null : _send,
                          style: core.AppButtonStyles.primaryFilled,
                          child: const Text('Send'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
  });

  final ApplicationMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mine ? core.AppColors.accent : HomeMarketplaceTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: mine
                  ? null
                  : Border.all(color: HomeMarketplaceTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: mine
                          ? Colors.white
                          : HomeMarketplaceTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.8)
                          : HomeMarketplaceTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]}, $hour:$minute';
  }
}
