import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/application_conversation.dart';
import 'package:true_circle/services/application_conversation_service.dart';
import 'package:true_circle/services/application_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    applicationConversationService.resetForTest();
    applicationService.resetForTest();
  });

  group('ApplicationConversationService', () {
    test('one application maps to a single conversation', () async {
      final first = await applicationConversationService.ensureConversation(
        applicationId: 'app-1',
        listingId: 'listing-1',
        applicantUserId: 'seeker-1',
        hostUserId: 'host-1',
      );
      final second = await applicationConversationService.ensureConversation(
        applicationId: 'app-1',
        listingId: 'listing-1',
        applicantUserId: 'seeker-1',
        hostUserId: 'host-1',
      );

      expect(first.applicationId, 'app-1');
      expect(first.applicationId, second.applicationId);
      expect(
        applicationConversationService.peek('app-1')?.applicationId,
        'app-1',
      );
    });

    test('send is unread for the other participant until markRead', () async {
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

      expect(
        applicationConversationService.unreadCount(
          applicationId: 'app-1',
          role: ApplicationParticipantRole.host,
        ),
        1,
      );
      expect(
        applicationConversationService.unreadCount(
          applicationId: 'app-1',
          role: ApplicationParticipantRole.applicant,
        ),
        0,
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

    test('rejects blank message bodies', () async {
      await applicationConversationService.ensureConversation(
        applicationId: 'app-1',
      );
      expect(
        () => applicationConversationService.sendMessage(
          applicationId: 'app-1',
          senderUserId: 'seeker-1',
          senderRole: ApplicationParticipantRole.applicant,
          body: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('persists messages across reload', () async {
      await applicationConversationService.ensureConversation(
        applicationId: 'app-1',
        listingId: 'listing-1',
        applicantUserId: 'seeker-1',
        hostUserId: 'host-1',
      );
      await applicationConversationService.sendMessage(
        applicationId: 'app-1',
        senderUserId: 'host-1',
        senderRole: ApplicationParticipantRole.host,
        body: 'Viewing at 6pm',
      );

      applicationConversationService.resetForTest();
      await applicationConversationService.ensureLoaded();

      final conversation = applicationConversationService.peek('app-1');
      expect(conversation, isNotNull);
      expect(conversation!.messages, hasLength(1));
      expect(conversation.messages.first.body, 'Viewing at 6pm');
      expect(conversation.listingId, 'listing-1');
    });

    test('host inbox aggregates unread seeker messages per conversation', () async {
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
        body: 'First',
      );
      await applicationConversationService.sendMessage(
        applicationId: 'app-1',
        senderUserId: 'seeker-1',
        senderRole: ApplicationParticipantRole.applicant,
        body: 'Second',
      );
      await applicationConversationService.sendMessage(
        applicationId: 'app-1',
        senderUserId: 'host-1',
        senderRole: ApplicationParticipantRole.host,
        body: 'Host reply ignored for inbox',
      );

      final items = applicationConversationService.hostUnreadNotifications(
        hostUserId: 'host-1',
      );
      expect(items, hasLength(1));
      expect(items.single.applicationId, 'app-1');
      expect(items.single.unreadCount, 2);
      expect(items.single.messagePreview, 'Second');
      expect(items.single.isNewConversation, isTrue);
      expect(
        applicationConversationService.hostUnreadMessageTotal(
          hostUserId: 'host-1',
        ),
        2,
      );

      await applicationConversationService.markRead(
        applicationId: 'app-1',
        role: ApplicationParticipantRole.host,
      );
      expect(
        applicationConversationService.hostUnreadNotifications(
          hostUserId: 'host-1',
        ),
        isEmpty,
      );
    });

    test('host inbox can resolve by owned listing when host id missing', () async {
      await applicationConversationService.ensureConversation(
        applicationId: 'app-2',
        listingId: 'listing-owned',
        applicantUserId: 'seeker-2',
        hostUserId: '',
      );
      await applicationConversationService.sendMessage(
        applicationId: 'app-2',
        senderUserId: 'seeker-2',
        senderRole: ApplicationParticipantRole.applicant,
        body: 'Hello',
      );

      expect(
        applicationConversationService.hostUnreadNotifications(
          hostUserId: 'host-x',
        ),
        isEmpty,
      );
      final items = applicationConversationService.hostUnreadNotifications(
        hostUserId: 'host-x',
        ownedListingIds: {'listing-owned'},
      );
      expect(items, hasLength(1));
      expect(items.single.messagePreview, 'Hello');
    });
  });
}
