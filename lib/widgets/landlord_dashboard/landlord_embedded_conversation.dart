import 'package:flutter/material.dart';

import '../../models/application_conversation.dart';
import '../../models/application_message.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../services/application_conversation_service.dart';
import '../../services/auth_service.dart';
import 'landlord_dashboard_theme.dart';

/// Compact in-panel thread. Story lives in the applicant header, not here.
class LandlordEmbeddedConversation extends StatefulWidget {
  const LandlordEmbeddedConversation({
    super.key,
    required this.applicant,
    this.composerFocusNode,
  });

  final LandlordApplicantCardModel applicant;
  final FocusNode? composerFocusNode;

  @override
  State<LandlordEmbeddedConversation> createState() =>
      _LandlordEmbeddedConversationState();
}

class _LandlordEmbeddedConversationState
    extends State<LandlordEmbeddedConversation> {
  late final TextEditingController _controller;
  bool _sending = false;

  String get _applicationId => widget.applicant.applicationId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    applicationConversationService.addListener(_onStoreChanged);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant LandlordEmbeddedConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applicant.applicationId != widget.applicant.applicationId) {
      _controller.clear();
      _bootstrap();
    }
  }

  @override
  void dispose() {
    applicationConversationService.removeListener(_onStoreChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await applicationConversationService.ensureConversation(
      applicationId: _applicationId,
      listingId: widget.applicant.listingId,
      applicantUserId: widget.applicant.applicantUserId,
      hostUserId: AuthService.identityUserId(),
    );
    await applicationConversationService.markRead(
      applicationId: _applicationId,
      role: ApplicationParticipantRole.host,
    );
  }

  Future<void> _send() async {
    final body = _controller.text;
    if (body.trim().isEmpty || _sending) return;
    final senderId = AuthService.identityUserId();
    if (senderId.isEmpty) return;

    setState(() => _sending = true);
    try {
      await applicationConversationService.sendMessage(
        applicationId: _applicationId,
        senderUserId: senderId,
        senderRole: ApplicationParticipantRole.host,
        body: body,
      );
      await applicationConversationService.markRead(
        applicationId: _applicationId,
        role: ApplicationParticipantRole.host,
      );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation =
        applicationConversationService.peek(_applicationId);
    final messages = conversation?.messages ?? const <ApplicationMessage>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Conversation',
          style: LandlordDashboardTheme.railEyebrow().copyWith(
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      'No messages yet.\nSend the first message to start the conversation.',
                      textAlign: TextAlign.center,
                      style: LandlordDashboardTheme.cardSubtext().copyWith(
                        fontSize: 14,
                        height: 1.45,
                        color: LandlordDashboardTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _HostThreadBubble(
                      body: message.body,
                      mine: message.senderRole ==
                          ApplicationParticipantRole.host,
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                focusNode: widget.composerFocusNode,
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                maxLength: ApplicationConversationService.maxBodyLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: LandlordDashboardTheme.borderStrong,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: LandlordDashboardTheme.border,
                    ),
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: LandlordDashboardTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HostThreadBubble extends StatelessWidget {
  const _HostThreadBubble({
    required this.body,
    required this.mine,
  });

  final String body;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mine
                  ? LandlordDashboardTheme.accent
                  : LandlordDashboardTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: mine
                  ? null
                  : Border.all(color: LandlordDashboardTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Text(
                body,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  height: 1.35,
                  color: mine
                      ? Colors.white
                      : LandlordDashboardTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
