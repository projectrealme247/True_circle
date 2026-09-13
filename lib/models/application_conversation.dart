import 'application_message.dart';

enum ApplicationParticipantRole {
  applicant('applicant'),
  host('host');

  const ApplicationParticipantRole(this.storageToken);

  final String storageToken;

  static ApplicationParticipantRole parse(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'host' || 'landlord' => host,
      _ => applicant,
    };
  }
}

/// One conversation per listing application (listing + applicant + host).
class ApplicationConversation {
  const ApplicationConversation({
    required this.applicationId,
    required this.listingId,
    required this.applicantUserId,
    required this.hostUserId,
    this.applicantLastReadAt,
    this.hostLastReadAt,
    this.messages = const [],
  });

  /// Identity — same as the application id.
  final String applicationId;
  final String listingId;
  final String applicantUserId;
  final String hostUserId;
  final DateTime? applicantLastReadAt;
  final DateTime? hostLastReadAt;
  final List<ApplicationMessage> messages;

  DateTime? lastReadAtFor(ApplicationParticipantRole role) =>
      role == ApplicationParticipantRole.host
          ? hostLastReadAt
          : applicantLastReadAt;

  int unreadCountFor(ApplicationParticipantRole role) {
    final lastRead = lastReadAtFor(role);
    return messages.where((m) {
      if (m.senderRole == role) return false;
      if (lastRead == null) return true;
      return m.createdAt.isAfter(lastRead);
    }).length;
  }

  ApplicationConversation copyWith({
    String? listingId,
    String? applicantUserId,
    String? hostUserId,
    DateTime? applicantLastReadAt,
    DateTime? hostLastReadAt,
    List<ApplicationMessage>? messages,
    bool clearApplicantLastRead = false,
    bool clearHostLastRead = false,
  }) {
    return ApplicationConversation(
      applicationId: applicationId,
      listingId: listingId ?? this.listingId,
      applicantUserId: applicantUserId ?? this.applicantUserId,
      hostUserId: hostUserId ?? this.hostUserId,
      applicantLastReadAt: clearApplicantLastRead
          ? null
          : (applicantLastReadAt ?? this.applicantLastReadAt),
      hostLastReadAt:
          clearHostLastRead ? null : (hostLastReadAt ?? this.hostLastReadAt),
      messages: messages ?? this.messages,
    );
  }

  factory ApplicationConversation.fromMap(Map<String, dynamic> map) {
    final rawMessages = map['messages'];
    final messages = <ApplicationMessage>[
      if (rawMessages is List)
        for (final item in rawMessages)
          if (item is Map)
            ApplicationMessage.fromMap(Map<String, dynamic>.from(item)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ApplicationConversation(
      applicationId: map['application_id']?.toString() ??
          map['applicationId']?.toString() ??
          '',
      listingId:
          map['listing_id']?.toString() ?? map['listingId']?.toString() ?? '',
      applicantUserId: map['applicant_user_id']?.toString() ??
          map['applicantUserId']?.toString() ??
          '',
      hostUserId:
          map['host_user_id']?.toString() ?? map['hostUserId']?.toString() ?? '',
      applicantLastReadAt:
          DateTime.tryParse(map['applicant_last_read_at']?.toString() ?? ''),
      hostLastReadAt:
          DateTime.tryParse(map['host_last_read_at']?.toString() ?? ''),
      messages: messages,
    );
  }

  Map<String, dynamic> toMap() => {
        'application_id': applicationId,
        'listing_id': listingId,
        'applicant_user_id': applicantUserId,
        'host_user_id': hostUserId,
        if (applicantLastReadAt != null)
          'applicant_last_read_at': applicantLastReadAt!.toIso8601String(),
        if (hostLastReadAt != null)
          'host_last_read_at': hostLastReadAt!.toIso8601String(),
        'messages': [for (final m in messages) m.toMap()],
      };
}
