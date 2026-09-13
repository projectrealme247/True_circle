import 'application_conversation.dart';

/// Plain-text message on an application conversation.
class ApplicationMessage {
  const ApplicationMessage({
    required this.id,
    required this.applicationId,
    required this.senderUserId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String applicationId;
  final String senderUserId;
  final ApplicationParticipantRole senderRole;
  final String body;
  final DateTime createdAt;

  factory ApplicationMessage.fromMap(Map<String, dynamic> map) {
    return ApplicationMessage(
      id: map['id']?.toString() ?? '',
      applicationId: map['application_id']?.toString() ??
          map['applicationId']?.toString() ??
          '',
      senderUserId: map['sender_user_id']?.toString() ??
          map['senderUserId']?.toString() ??
          '',
      senderRole: ApplicationParticipantRole.parse(map['sender_role']?.toString()),
      body: map['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'application_id': applicationId,
        'sender_user_id': senderUserId,
        'sender_role': senderRole.storageToken,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}
