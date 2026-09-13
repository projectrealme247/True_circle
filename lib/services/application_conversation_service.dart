import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/application_conversation.dart';
import '../models/application_message.dart';
import '../models/host_conversation_notification.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import 'application_service.dart';
import 'listings_storage_service.dart';

/// Local store — one conversation per application.
class ApplicationConversationService extends ChangeNotifier {
  ApplicationConversationService._();

  static final ApplicationConversationService instance =
      ApplicationConversationService._();

  static const _storageKey = 'circlekey_application_conversations';
  static const maxBodyLength = 4000;

  final Map<String, ApplicationConversation> _byApplicationId = {};
  bool _loaded = false;

  @visibleForTesting
  void resetForTest() {
    _byApplicationId.clear();
    _loaded = false;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final conversation = ApplicationConversation.fromMap(
              Map<String, dynamic>.from(item),
            );
            if (conversation.applicationId.isEmpty) continue;
            _byApplicationId[conversation.applicationId] = conversation;
          }
        }
      }
    } catch (_) {
      _byApplicationId.clear();
    }
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

    final existing = _byApplicationId[applicationId];
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
      if (merged.listingId != existing.listingId ||
          merged.applicantUserId != existing.applicantUserId ||
          merged.hostUserId != existing.hostUserId) {
        _byApplicationId[applicationId] = merged;
        await _persist();
        notifyListeners();
      }
      return _byApplicationId[applicationId]!;
    }

    final created = ApplicationConversation(
      applicationId: applicationId,
      listingId: resolvedListing,
      applicantUserId: resolvedApplicant,
      hostUserId: resolvedHost,
    );
    _byApplicationId[applicationId] = created;
    await _persist();
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

    final conversation = await ensureConversation(applicationId: applicationId);
    final clipped = trimmed.length > maxBodyLength
        ? trimmed.substring(0, maxBodyLength)
        : trimmed;

    final message = ApplicationMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      applicationId: applicationId,
      senderUserId: senderUserId,
      senderRole: senderRole,
      body: clipped,
      createdAt: DateTime.now(),
    );

    final next = conversation.copyWith(
      messages: [...conversation.messages, message],
    );
    _byApplicationId[applicationId] = next;
    await _persist();
    notifyListeners();
    return message;
  }

  Future<void> markRead({
    required String applicationId,
    required ApplicationParticipantRole role,
  }) async {
    await ensureLoaded();
    final conversation = _byApplicationId[applicationId];
    if (conversation == null) return;

    final now = DateTime.now();
    final next = role == ApplicationParticipantRole.host
        ? conversation.copyWith(hostLastReadAt: now)
        : conversation.copyWith(applicantLastReadAt: now);
    _byApplicationId[applicationId] = next;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final conversation in _byApplicationId.values) conversation.toMap(),
    ]);
    await prefs.setString(_storageKey, encoded);
  }
}

final applicationConversationService = ApplicationConversationService.instance;
