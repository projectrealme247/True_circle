import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/application_conversation.dart';
import '../models/application_message.dart';
import 'auth_service.dart';

/// Remote read/write for `application_messages` and thread last-read cursors.
abstract final class ApplicationMessagesSupabaseService {
  static const messagesTable = 'application_messages';
  static const applicationsTable = 'listing_applications';
  static const markReadRpc = 'mark_application_thread_read';

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @visibleForTesting
  static bool? debugIsReadyOverride;

  @visibleForTesting
  static Future<List<ApplicationConversation>> Function()?
      debugFetchAccessibleConversations;

  @visibleForTesting
  static Future<ApplicationConversation?> Function(
    String applicationId, {
    String listingId,
    String applicantUserId,
    String hostUserId,
  })? debugFetchConversation;

  @visibleForTesting
  static Future<void> Function(String applicationId)? debugMarkRead;

  @visibleForTesting
  static void resetDebugHooks() {
    debugIsReadyOverride = null;
    debugFetchAccessibleConversations = null;
    debugFetchConversation = null;
    debugMarkRead = null;
  }

  static bool get isReady {
    final override = debugIsReadyOverride;
    if (override != null) return override;
    try {
      return Supabase.instance.isInitialized && AuthService.isAuthenticated;
    } catch (_) {
      return false;
    }
  }

  static bool isRemoteId(String applicationId) =>
      _uuidPattern.hasMatch(applicationId.trim());

  /// Inbox for the signed-in user. Throws when the remote read fails.
  /// Signed-out / demo sessions (`!isReady`) return an empty list.
  static Future<List<ApplicationConversation>> fetchAccessibleConversations() async {
    final override = debugFetchAccessibleConversations;
    if (override != null) return override();
    if (!isReady) return const [];

    final appRows = await AuthService.client
        .from(applicationsTable)
        .select(
          'id, listing_id, applicant_user_id, applicant_last_read_at, host_last_read_at',
        );
    final messageRows = await AuthService.client
        .from(messagesTable)
        .select()
        .order('created_at');

    final messagesByApp = <String, List<ApplicationMessage>>{};
    if (messageRows is List) {
      for (final item in messageRows) {
        if (item is! Map) continue;
        final message = ApplicationMessage.fromMap(Map<String, dynamic>.from(item));
        if (message.applicationId.isEmpty) continue;
        messagesByApp
            .putIfAbsent(message.applicationId, () => [])
            .add(message);
      }
    }

    if (appRows is! List) {
      throw StateError('Unexpected applications response.');
    }
    return [
      for (final item in appRows)
        if (item is Map)
          _conversationFromApplicationRow(
            Map<String, dynamic>.from(item),
            messagesByApp,
          ),
    ];
  }

  /// Single thread. Returns null when Supabase is not ready or the id is local.
  /// Throws when an authenticated remote read fails.
  static Future<ApplicationConversation?> fetchConversation(
    String applicationId, {
    String listingId = '',
    String applicantUserId = '',
    String hostUserId = '',
  }) async {
    final override = debugFetchConversation;
    if (override != null) {
      return override(
        applicationId,
        listingId: listingId,
        applicantUserId: applicantUserId,
        hostUserId: hostUserId,
      );
    }
    if (!isReady || !isRemoteId(applicationId)) return null;

    final appRow = await AuthService.client
        .from(applicationsTable)
        .select(
          'id, listing_id, applicant_user_id, applicant_last_read_at, host_last_read_at',
        )
        .eq('id', applicationId)
        .maybeSingle();

    final messageRows = await AuthService.client
        .from(messagesTable)
        .select()
        .eq('application_id', applicationId)
        .order('created_at');

    final messages = <ApplicationMessage>[
      if (messageRows is List)
        for (final item in messageRows)
          if (item is Map)
            ApplicationMessage.fromMap(Map<String, dynamic>.from(item)),
    ];

    if (appRow == null) {
      return ApplicationConversation(
        applicationId: applicationId,
        listingId: listingId,
        applicantUserId: applicantUserId,
        hostUserId: hostUserId,
        messages: messages,
      );
    }

    final row = Map<String, dynamic>.from(appRow);
    return ApplicationConversation(
      applicationId: applicationId,
      listingId: listingId.isNotEmpty
          ? listingId
          : (row['listing_id']?.toString() ?? ''),
      applicantUserId: applicantUserId.isNotEmpty
          ? applicantUserId
          : (row['applicant_user_id']?.toString() ?? ''),
      hostUserId: hostUserId,
      applicantLastReadAt:
          DateTime.tryParse(row['applicant_last_read_at']?.toString() ?? ''),
      hostLastReadAt:
          DateTime.tryParse(row['host_last_read_at']?.toString() ?? ''),
      messages: messages,
    );
  }

  static Future<ApplicationMessage> insertMessage({
    required String applicationId,
    required String senderUserId,
    required ApplicationParticipantRole senderRole,
    required String body,
  }) async {
    final response = await AuthService.client
        .from(messagesTable)
        .insert({
          'application_id': applicationId,
          'sender_user_id': senderUserId,
          'sender_role': senderRole.storageToken,
          'body': body,
        })
        .select()
        .single();
    return ApplicationMessage.fromMap(Map<String, dynamic>.from(response));
  }

  /// Updates the remote read cursor. No-op when offline or the id is local.
  /// Throws when an authenticated remote mark-read fails.
  static Future<void> markRead(String applicationId) async {
    final override = debugMarkRead;
    if (override != null) return override(applicationId);
    if (!isReady || !isRemoteId(applicationId)) return;

    await AuthService.client.rpc(
      markReadRpc,
      params: {'p_application_id': applicationId},
    );
  }

  static ApplicationConversation _conversationFromApplicationRow(
    Map<String, dynamic> row,
    Map<String, List<ApplicationMessage>> messagesByApp,
  ) {
    final id = row['id']?.toString() ?? '';
    final messages = [...(messagesByApp[id] ?? const <ApplicationMessage>[])]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ApplicationConversation(
      applicationId: id,
      listingId: row['listing_id']?.toString() ?? '',
      applicantUserId: row['applicant_user_id']?.toString() ?? '',
      hostUserId: '',
      applicantLastReadAt:
          DateTime.tryParse(row['applicant_last_read_at']?.toString() ?? ''),
      hostLastReadAt:
          DateTime.tryParse(row['host_last_read_at']?.toString() ?? ''),
      messages: messages,
    );
  }
}
