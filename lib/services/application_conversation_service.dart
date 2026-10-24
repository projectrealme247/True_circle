import 'package:flutter/foundation.dart';

import '../models/application_conversation.dart';
import '../models/application_message.dart';
import '../models/host_conversation_notification.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import 'application_messages_supabase_service.dart';
import 'application_service.dart';
import 'listings_storage_service.dart';

/// Application messaging — Supabase is the source of truth when authenticated.
///
/// Tests and unauthenticated sessions use an in-memory store (not SharedPreferences).
class ApplicationConversationService extends ChangeNotifier {
  ApplicationConversationService._();

  static final ApplicationConversationService instance =
      ApplicationConversationService._();

  static const maxBodyLength = 4000;
  static const loadErrorMessage = 'Could not load messages. Try again.';
  static const markReadErrorMessage =
      'Could not update read status. Try again.';

  final Map<String, ApplicationConversation> _byApplicationId = {};
  final Map<String, ApplicationConversation> _localSource = {};
  bool _loaded = false;

  @visibleForTesting
  bool get isLoadedForTest => _loaded;

  @visibleForTesting
  void resetForTest({bool clearLocalSource = true}) {
    _byApplicationId.clear();
    _loaded = false;
    if (clearLocalSource) _localSource.clear();
  }

  /// Loads the messaging inbox. A failed remote read throws and does not
  /// clear the cache or lock `_loaded`.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (ApplicationMessagesSupabaseService.isReady) {
      final remote =
          await ApplicationMessagesSupabaseService.fetchAccessibleConversations();
      _byApplicationId
        ..clear()
        ..addEntries([
          for (final conversation in remote)
            if (conversation.applicationId.isNotEmpty)
              MapEntry(conversation.applicationId, conversation),
        ]);
      _loaded = true;
      return;
    }

    _byApplicationId
      ..clear()
      ..addEntries(_localSource.entries);
    _loaded = true;
  }

  ApplicationConversation? peek(String applicationId) {
    if (applicationId.isEmpty) return null;
    return _byApplicationId[applicationId];
  }

  int unreadCount({
    required String applicationId,
    required ApplicationParticipantRole role,
  }) {
    final conversation = _byApplicationId[applicationId];
    if (conversation == null) return 0;
    return conversation.unreadCountFor(role);
  }

  /// Total unread seeker messages across threads visible to this host.
  int hostUnreadMessageTotal({
    required String hostUserId,
    Set<String> ownedListingIds = const {},
  }) {
    var total = 0;
    for (final item in hostUnreadNotifications(
      hostUserId: hostUserId,
      ownedListingIds: ownedListingIds,
    )) {
      total += item.unreadCount;
    }
    return total;
  }

  /// One inbox row per conversation with unread seeker → host messages.
  List<HostConversationNotification> hostUnreadNotifications({
    required String hostUserId,
    Set<String> ownedListingIds = const {},
  }) {
    final items = <HostConversationNotification>[];
    for (final conversation in _byApplicationId.values) {
      if (!_isVisibleToHost(
        conversation,
        hostUserId: hostUserId,
        ownedListingIds: ownedListingIds,
      )) {
        continue;
      }

      final unread = _unreadApplicantMessages(conversation);
      if (unread.isEmpty) continue;

      final latest = unread.last;
      final appRow = applicationService.rowById(conversation.applicationId);
      items.add(
        HostConversationNotification(
          applicationId: conversation.applicationId,
          listingId: conversation.listingId.isNotEmpty
              ? conversation.listingId
              : (appRow?['listing_id']?.toString() ?? ''),
          applicantUserId: conversation.applicantUserId.isNotEmpty
              ? conversation.applicantUserId
              : (appRow?['user_id']?.toString() ??
                  appRow?['applicant_user_id']?.toString() ??
                  ''),
          hostUserId: conversation.hostUserId.isNotEmpty
              ? conversation.hostUserId
              : hostUserId,
          senderName: _senderNameFromApplication(appRow),
          listingTitle: '',
          messagePreview: latest.body,
          latestMessageId: latest.id,
          unreadCount: unread.length,
          latestAt: latest.createdAt,
          isNewConversation: conversation.hostLastReadAt == null,
        ),
      );
    }
    items.sort((a, b) => b.latestAt.compareTo(a.latestAt));
    return items;
  }

  /// Resolves listing titles for host inbox rows (async listing lookup).
  Future<List<HostConversationNotification>>
      hostUnreadNotificationsWithTitles({
    required String hostUserId,
    Set<String> ownedListingIds = const {},
  }) async {
    await ensureLoaded();
    await applicationService.ensureLoaded();
    final base = hostUnreadNotifications(
      hostUserId: hostUserId,
      ownedListingIds: ownedListingIds,
    );
    if (base.isEmpty) return base;

    final titles = <String, String>{};
    for (final item in base) {
      final id = item.listingId;
      if (id.isEmpty || titles.containsKey(id)) continue;
      final listing = await ListingsStorageService.getById(id);
      titles[id] = listing == null ? '' : ListingData.title(listing);
    }

    return [
      for (final item in base)
        HostConversationNotification(
          applicationId: item.applicationId,
          listingId: item.listingId,
          applicantUserId: item.applicantUserId,
          hostUserId: item.hostUserId,
          senderName: item.senderName,
          listingTitle: titles[item.listingId] ?? '',
          messagePreview: item.messagePreview,
          latestMessageId: item.latestMessageId,
          unreadCount: item.unreadCount,
          latestAt: item.latestAt,
          isNewConversation: item.isNewConversation,
        ),
    ];
  }

  bool _isVisibleToHost(
    ApplicationConversation conversation, {
    required String hostUserId,
    required Set<String> ownedListingIds,
  }) {
    if (hostUserId.isNotEmpty &&
        conversation.hostUserId.isNotEmpty &&
        conversation.hostUserId == hostUserId) {
      return true;
    }
    if (ownedListingIds.isNotEmpty &&
        conversation.listingId.isNotEmpty &&
        ownedListingIds.contains(conversation.listingId)) {
      return true;
    }
    return false;
  }

  List<ApplicationMessage> _unreadApplicantMessages(
    ApplicationConversation conversation,
  ) {
    final lastRead = conversation.hostLastReadAt;
    return [
      for (final message in conversation.messages)
        if (message.senderRole == ApplicationParticipantRole.applicant &&
            (lastRead == null || message.createdAt.isAfter(lastRead)))
          message,
    ];
  }

  static String _senderNameFromApplication(Map<String, dynamic>? row) {
    if (row == null) return 'Applicant';
    for (final key in [
      'full_name',
      'applicant_name',
      'seeker_name',
      'name',
    ]) {
      final value = ProfileData.text(row[key]);
      if (value.isNotEmpty) return value;
    }
    final profile = row['applicant_profile'];
    if (profile is Map) {
      final nested = ProfileData.text(profile['full_name'] ?? profile['name']);
      if (nested.isNotEmpty) return nested;
    }
    return 'Applicant';
  }

  static String hostUserIdFromListing(Map<String, dynamic>? listing) {
    if (listing == null) return '';
    for (final key in ['owner_user_id', 'landlord_id', 'user_id']) {
      final id = ProfileData.text(listing[key]);
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  /// Creates the conversation on first open. Identity is [applicationId].
  ///
  /// A failed authenticated remote read throws and does not invent an empty
  /// thread. Signed-out / local ids still create an empty conversation.
  Future<ApplicationConversation> ensureConversation({
    required String applicationId,
    String listingId = '',
    String applicantUserId = '',
    String hostUserId = '',
  }) async {
    if (applicationId.isEmpty) {
      throw ArgumentError.value(applicationId, 'applicationId', 'must not be empty');
    }
    await ensureLoaded();

    var resolvedListing = listingId;
    var resolvedApplicant = applicantUserId;
    var resolvedHost = hostUserId;

    final existingApp = applicationService.rowById(applicationId);
    if (existingApp != null) {
      if (resolvedListing.isEmpty) {
        resolvedListing = existingApp['listing_id']?.toString() ?? '';
      }
      if (resolvedApplicant.isEmpty) {
        resolvedApplicant = existingApp['user_id']?.toString() ??
            existingApp['applicant_user_id']?.toString() ??
            '';
      }
    }

    if (resolvedHost.isEmpty && resolvedListing.isNotEmpty) {
      final listing = await ListingsStorageService.getById(resolvedListing);
      resolvedHost = hostUserIdFromListing(listing);
    }

    final useRemote = ApplicationMessagesSupabaseService.isReady &&
        ApplicationMessagesSupabaseService.isRemoteId(applicationId);
    final remote = await ApplicationMessagesSupabaseService.fetchConversation(
      applicationId,
      listingId: resolvedListing,
      applicantUserId: resolvedApplicant,
      hostUserId: resolvedHost,
    );

    final existing = remote ?? _byApplicationId[applicationId];
    if (existing != null) {
      final merged = existing.copyWith(
        listingId:
            existing.listingId.isEmpty ? resolvedListing : existing.listingId,
        applicantUserId: existing.applicantUserId.isEmpty
            ? resolvedApplicant
            : existing.applicantUserId,
        hostUserId:
            existing.hostUserId.isEmpty ? resolvedHost : existing.hostUserId,
      );
      _byApplicationId[applicationId] = merged;
      _mirrorLocal(merged);
      notifyListeners();
      return merged;
    }

    if (useRemote) {
      // Authenticated UUID reads return a conversation or throw. Reaching here
      // means the remote path returned null unexpectedly.
      throw StateError(loadErrorMessage);
    }

    final created = ApplicationConversation(
      applicationId: applicationId,
      listingId: resolvedListing,
      applicantUserId: resolvedApplicant,
      hostUserId: resolvedHost,
    );
    _byApplicationId[applicationId] = created;
    _mirrorLocal(created);
    notifyListeners();
    return created;
  }

  Future<ApplicationMessage> sendMessage({
    required String applicationId,
    required String senderUserId,
    required ApplicationParticipantRole senderRole,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(body, 'body', 'must not be empty');
    }
    if (senderUserId.isEmpty) {
      throw ArgumentError.value(senderUserId, 'senderUserId', 'must not be empty');
    }

    // Status writes may already have succeeded. A failed thread read must not
    // block the subsequent insertMessage for authenticated UUID applications.
    ApplicationConversation conversation;
    try {
      conversation = await ensureConversation(applicationId: applicationId);
    } catch (_) {
      final useRemote = ApplicationMessagesSupabaseService.isReady &&
          ApplicationMessagesSupabaseService.isRemoteId(applicationId);
      if (!useRemote) rethrow;
      conversation = _byApplicationId[applicationId] ??
          ApplicationConversation(
            applicationId: applicationId,
            listingId: '',
            applicantUserId: '',
            hostUserId: '',
          );
      _byApplicationId[applicationId] = conversation;
    }

    final clipped = trimmed.length > maxBodyLength
        ? trimmed.substring(0, maxBodyLength)
        : trimmed;

    final ApplicationMessage message;
    if (ApplicationMessagesSupabaseService.isReady &&
        ApplicationMessagesSupabaseService.isRemoteId(applicationId)) {
      message = await ApplicationMessagesSupabaseService.insertMessage(
        applicationId: applicationId,
        senderUserId: senderUserId,
        senderRole: senderRole,
        body: clipped,
      );
    } else {
      message = ApplicationMessage(
        id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
        applicationId: applicationId,
        senderUserId: senderUserId,
        senderRole: senderRole,
        body: clipped,
        createdAt: DateTime.now(),
      );
    }

    final next = conversation.copyWith(
      messages: [...conversation.messages, message],
    );
    _byApplicationId[applicationId] = next;
    _mirrorLocal(next);
    notifyListeners();
    return message;
  }

  /// Advances the local unread cursor for demo/local ids, or after a successful
  /// remote mark-read. A failed remote mark-read throws and leaves unread intact.
  Future<void> markRead({
    required String applicationId,
    required ApplicationParticipantRole role,
  }) async {
    await ensureLoaded();
    final conversation = _byApplicationId[applicationId];
    if (conversation == null) return;

    final useRemote = ApplicationMessagesSupabaseService.isReady &&
        ApplicationMessagesSupabaseService.isRemoteId(applicationId);
    if (useRemote) {
      await ApplicationMessagesSupabaseService.markRead(applicationId);
    }

    final now = DateTime.now();
    final next = role == ApplicationParticipantRole.host
        ? conversation.copyWith(hostLastReadAt: now)
        : conversation.copyWith(applicantLastReadAt: now);
    _byApplicationId[applicationId] = next;
    _mirrorLocal(next);
    notifyListeners();
  }

  void _mirrorLocal(ApplicationConversation conversation) {
    if (ApplicationMessagesSupabaseService.isReady) return;
    _localSource[conversation.applicationId] = conversation;
  }
}

final applicationConversationService = ApplicationConversationService.instance;
