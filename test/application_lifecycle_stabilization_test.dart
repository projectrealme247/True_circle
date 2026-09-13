import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/models/applicant_application_status.dart';
import 'package:true_circle/models/application_conversation.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/application_conversation_service.dart';
import 'package:true_circle/services/application_lifecycle_service.dart';
import 'package:true_circle/services/application_service.dart';
import 'package:true_circle/services/user_session_store.dart';
import 'package:true_circle/utils/seeker_application_pipeline.dart';
import 'package:true_circle/utils/viewing_invitation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'seeker-1';
  const hostId = 'host-1';
  const listingId = 'listing-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    applicationService.resetForTest();
    applicationConversationService.resetForTest();
    UserSessionStore.current = {
      'supabase_user_id': userId,
      'full_name': 'Seeker One',
    };
  });

  Future<String> createApplication() async {
    final row = await applicationService.submitWithDetails(
      listingId: listingId,
      session: UserSessionStore.current!,
      space: MarketplaceSpace.fullRental,
      compatibilityScore: 80,
    );
    return row['id']!.toString();
  }

  test('listing detail shows Story Sent after apply and blocks second submit',
      () async {
    final first = await applicationService.submitWithDetails(
      listingId: listingId,
      session: UserSessionStore.current!,
      space: MarketplaceSpace.fullRental,
      compatibilityScore: 70,
    );
    final second = await applicationService.submitWithDetails(
      listingId: listingId,
      session: {
        ...UserSessionStore.current!,
        'personal_introduction': 'Should not overwrite',
      },
      space: MarketplaceSpace.fullRental,
      compatibilityScore: 99,
    );

    expect(second['id'], first['id']);
    expect(applicationService.getUserApplications(userId), hasLength(1));
    expect(
      SeekerApplicationPipeline.listingDetailStateLabel(
        listingId: listingId,
        userId: userId,
      ),
      'Story Sent — Awaiting Host',
    );
  });

  test('lifecycle invitation → accept persists after reload', () async {
    final applicationId = await createApplication();

    await ApplicationLifecycleService.sendViewingInvitation(
      applicationId: applicationId,
      hostUserId: hostId,
      invitation: const ViewingInvitation(
        dateLabel: '12 Sep 2026',
        timeLabel: '18:00',
        location: 'Main entrance, Cookstown Road',
      ),
    );

    expect(
      applicationService.rowById(applicationId)?['status'],
      ApplicantApplicationStatus.viewingInvitationSent.storageToken,
    );
    expect(
      SeekerApplicationPipeline.listingDetailStateLabel(
        listingId: listingId,
        userId: userId,
      ),
      'Viewing Invitation Sent',
    );

    final invitationMessage =
        applicationConversationService.peek(applicationId)!.messages.first.body;
    expect(invitationMessage, ViewingInvitation.sentTimelineBody);

    await ApplicationLifecycleService.acceptViewingInvitation(
      applicationId: applicationId,
      applicantUserId: userId,
    );

    expect(
      applicationService.rowById(applicationId)?['status'],
      ApplicantApplicationStatus.viewingScheduled.storageToken,
    );

    // Simulate restart — wipe memory and reload from SharedPreferences.
    applicationService.resetForTest();
    applicationConversationService.resetForTest();
    await applicationService.ensureLoaded();
    await applicationConversationService.ensureLoaded();

    expect(
      applicationService.rowById(applicationId)?['status'],
      ApplicantApplicationStatus.viewingScheduled.storageToken,
    );
    expect(
      applicationService.rowById(applicationId)?['viewing_date'],
      '12 Sep 2026',
    );
    expect(
      SeekerApplicationPipeline.listingDetailStateLabel(
        listingId: listingId,
        userId: userId,
      ),
      'Viewing Scheduled',
    );
    expect(
      applicationConversationService.peek(applicationId)!.messages.first.body,
      ViewingInvitation.sentTimelineBody,
    );
  });

  test('reject persists as Application Closed on listing detail', () async {
    final applicationId = await createApplication();
    await ApplicationLifecycleService.declineApplicant(
      applicationId: applicationId,
    );

    applicationService.resetForTest();
    await applicationService.ensureLoaded();

    expect(
      applicationService.rowById(applicationId)?['status'],
      ApplicantApplicationStatus.declined.storageToken,
    );
    expect(
      SeekerApplicationPipeline.listingDetailStateLabel(
        listingId: listingId,
        userId: userId,
      ),
      'Application Closed',
    );
  });

  test('host message moves listing detail to In Progress', () async {
    final applicationId = await createApplication();
    await applicationConversationService.ensureConversation(
      applicationId: applicationId,
      listingId: listingId,
      applicantUserId: userId,
      hostUserId: hostId,
    );
    await applicationConversationService.sendMessage(
      applicationId: applicationId,
      senderUserId: hostId,
      senderRole: ApplicationParticipantRole.host,
      body: 'Hi',
    );

    expect(
      SeekerApplicationPipeline.listingDetailStateLabel(
        listingId: listingId,
        userId: userId,
      ),
      'In Progress',
    );
  });
}
