import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/application_conversation.dart';
import 'package:true_circle/services/application_conversation_service.dart';
import 'package:true_circle/services/application_messages_supabase_service.dart';
import 'package:true_circle/services/application_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remoteId = '6ab066eb-2750-42ce-a5c1-dee8cdf2b28c';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    applicationConversationService.resetForTest();
    applicationService.resetForTest();
    ApplicationMessagesSupabaseService.resetDebugHooks();
  });

  tearDown(ApplicationMessagesSupabaseService.resetDebugHooks);

  test('failed inbox load does not lock an empty cache', () async {
    ApplicationMessagesSupabaseService.debugIsReadyOverride = true;
    ApplicationMessagesSupabaseService.debugFetchAccessibleConversations =
        () async => throw StateError('offline');

    await expectLater(
      applicationConversationService.ensureLoaded(),
      throwsA(isA<StateError>()),
    );
    expect(applicationConversationService.isLoadedForTest, isFalse);
    expect(applicationConversationService.peek(remoteId), isNull);
  });

  test('failed thread load does not invent an empty conversation', () async {
    ApplicationMessagesSupabaseService.debugIsReadyOverride = true;
    ApplicationMessagesSupabaseService.debugFetchAccessibleConversations =
        () async => const [];
    ApplicationMessagesSupabaseService.debugFetchConversation =
        (
          applicationId, {
          String listingId = '',
          String applicantUserId = '',
          String hostUserId = '',
        }) async =>
            throw StateError('offline');

    await expectLater(
      applicationConversationService.ensureConversation(applicationId: remoteId),
      throwsA(isA<StateError>()),
    );
    expect(applicationConversationService.peek(remoteId), isNull);
  });

  test('failed remote mark-read leaves unread intact', () async {
    ApplicationMessagesSupabaseService.debugIsReadyOverride = false;
    await applicationConversationService.ensureConversation(
      applicationId: remoteId,
      listingId: 'listing-1',
      applicantUserId: 'seeker-1',
      hostUserId: 'host-1',
    );
    await applicationConversationService.sendMessage(
      applicationId: remoteId,
      senderUserId: 'seeker-1',
      senderRole: ApplicationParticipantRole.applicant,
      body: 'Hello host',
    );
    final seeded = applicationConversationService.peek(remoteId)!;

    ApplicationMessagesSupabaseService.debugIsReadyOverride = true;
    ApplicationMessagesSupabaseService.debugFetchAccessibleConversations =
        () async => [seeded];
    ApplicationMessagesSupabaseService.debugMarkRead =
        (_) async => throw StateError('offline');

    applicationConversationService.resetForTest(clearLocalSource: false);
    await applicationConversationService.ensureLoaded();

    expect(
      applicationConversationService.unreadCount(
        applicationId: remoteId,
        role: ApplicationParticipantRole.host,
      ),
      1,
    );

    await expectLater(
      applicationConversationService.markRead(
        applicationId: remoteId,
        role: ApplicationParticipantRole.host,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      applicationConversationService.unreadCount(
        applicationId: remoteId,
        role: ApplicationParticipantRole.host,
      ),
      1,
    );
  });

  test('local mark-read still clears unread when Supabase is not ready', () async {
    await applicationConversationService.ensureConversation(
      applicationId: 'app-1',
      listingId: 'listing-1',
      applicantUserId: 'seeker-1',
      hostUserId: 'host-1',
    );
    await applicationConversationService.sendMessage(
      applicationId: 'app-1',
      senderUserId: 'seeker-1',
      senderRole: ApplicationParticipantRole.applicant,
      body: 'Hello host',
    );

    await applicationConversationService.markRead(
      applicationId: 'app-1',
      role: ApplicationParticipantRole.host,
    );
    expect(
      applicationConversationService.unreadCount(
        applicationId: 'app-1',
        role: ApplicationParticipantRole.host,
      ),
      0,
    );
  });
}
