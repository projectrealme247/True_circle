import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' as core
    show AppColors, AppButtonStyles;
import '../../models/application_conversation.dart';
import '../../models/application_message.dart';
import '../../services/application_conversation_service.dart';
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/viewing_invitation.dart';

/// Embedded application thread + composer (column 3, below property context).
class SeekerEmbeddedConversation extends StatelessWidget {
  const SeekerEmbeddedConversation({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.messageController,
    required this.sending,
    required this.onSend,
    this.unlocked = true,
  });

  final List<ApplicationMessage> messages;
  final ScrollController scrollController;
  final TextEditingController messageController;
  final bool sending;
  final VoidCallback onSend;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Text(
            'CONVERSATION',
            style: AppTypography.sectionMeta().copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HomeMarketplaceTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HomeMarketplaceTheme.border),
              ),
              child: !unlocked || messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          unlocked
                              ? 'No messages yet.'
                              : 'Waiting for the host to message you or send a viewing invitation.',
                          textAlign: TextAlign.center,
                          style: AppTypography.detail().copyWith(
                            color: HomeMarketplaceTheme.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final mine = message.senderRole ==
                            ApplicationParticipantRole.applicant;
                        final isTimeline =
                            ViewingInvitation.isViewingTimelineMessage(
                          message.body,
                        );
                        return _MessageBubble(
                          message: message,
                          mine: mine,
                          timeline: isTimeline,
                        );
                      },
                    ),
            ),
          ),
        ),
        if (unlocked) const Divider(height: 1),
        if (unlocked)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: ApplicationConversationService.maxBodyLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: sending ? null : onSend,
                    style: core.AppButtonStyles.primaryFilled,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.timeline = false,
  });

  final ApplicationMessage message;
  final bool mine;
  final bool timeline;

  @override
  Widget build(BuildContext context) {
    if (timeline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              ViewingInvitation.timelineDisplayBody(message.body),
              textAlign: TextAlign.center,
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }

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
