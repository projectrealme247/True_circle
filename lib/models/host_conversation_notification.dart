/// One host inbox row for unread seeker messages on an application thread.
///
/// Deduped by [applicationId] — multiple unread messages collapse to the
/// latest preview so the same message never appears twice.
class HostConversationNotification {
  const HostConversationNotification({
    required this.applicationId,
    required this.listingId,
    required this.applicantUserId,
    required this.hostUserId,
    required this.senderName,
    required this.listingTitle,
    required this.messagePreview,
    required this.latestMessageId,
    required this.unreadCount,
    required this.latestAt,
    required this.isNewConversation,
  });

  final String applicationId;
  final String listingId;
  final String applicantUserId;
  final String hostUserId;
  final String senderName;
  final String listingTitle;
  final String messagePreview;
  final String latestMessageId;
  final int unreadCount;
  final DateTime latestAt;

  /// True when the host has never opened the thread (new seeker conversation).
  final bool isNewConversation;
}
