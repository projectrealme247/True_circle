import '../models/applicant_application_status.dart';
import '../models/application_conversation.dart';
import '../services/application_conversation_service.dart';
import '../services/application_service.dart';
import '../services/applicant_management_supabase_service.dart';
import '../services/applicant_status_transition_service.dart';
import '../services/listing_applications_supabase_service.dart';
import '../utils/viewing_invitation.dart';

/// Remote status updates for signed-in UUID applications.
///
/// Local updates remain for offline/demo sessions and non-UUID application ids.
abstract final class ApplicationLifecycleService {
  ApplicationLifecycleService._();

  static Future<Map<String, dynamic>> updateStatus({
    required String applicationId,
    required ApplicantApplicationStatus nextStatus,
    ApplicantApplicationStatus? currentStatus,
    Map<String, dynamic>? extras,
  }) async {
    await applicationService.ensureLoaded();
    final localRow = applicationService.rowById(applicationId);
    final resolvedCurrent = currentStatus ??
        (localRow == null
            ? null
            : ApplicantApplicationStatus.parseOrDefault(
                localRow['status']?.toString(),
              ));

    if (resolvedCurrent != null) {
      final transitionError = ApplicantStatusTransitionService.validateTransition(
        from: resolvedCurrent,
        to: nextStatus,
      );
      if (transitionError != null) {
        throw ApplicantManagementException(
          transitionError,
          code: ApplicantManagementErrorCode.invalidTransition,
        );
      }
    }

    final useRemote = ListingApplicationsSupabaseService.isReady &&
        ListingApplicationsSupabaseService.isRemoteId(applicationId);

    if (useRemote) {
      final remote =
          await ApplicantManagementSupabaseService.updateApplicationStatus(
        applicationId: applicationId,
        nextStatus: nextStatus,
        currentStatus: resolvedCurrent,
        extras: extras,
      );
      return applicationService.cacheRemoteRow(remote);
    }

    if (localRow != null) {
      await applicationService.updateApplicationStatus(
        applicationId: applicationId,
        nextStatus: nextStatus,
        extras: extras,
      );
      return applicationService.rowById(applicationId) ?? localRow;
    }

    throw ApplicantManagementException(
      'Application not found.',
      code: ApplicantManagementErrorCode.notFound,
    );
  }

  static Future<void> _ensureThreadAndHostMessage({
    required String applicationId,
    required String hostUserId,
    required Map<String, dynamic> row,
    required String body,
  }) async {
    final listingId = row['listing_id']?.toString() ?? '';
    final applicantUserId = row['user_id']?.toString() ??
        row['applicant_user_id']?.toString() ??
        '';
    try {
      await applicationConversationService.ensureConversation(
        applicationId: applicationId,
        listingId: listingId,
        applicantUserId: applicantUserId,
        hostUserId: hostUserId,
      );
    } catch (_) {
      // Status is already saved. Timeline send must still proceed.
    }
    if (hostUserId.isEmpty) return;
    await applicationConversationService.sendMessage(
      applicationId: applicationId,
      senderUserId: hostUserId,
      senderRole: ApplicationParticipantRole.host,
      body: body,
    );
  }

  static Future<Map<String, dynamic>> sendViewingInvitation({
    required String applicationId,
    required String hostUserId,
    required ViewingInvitation invitation,
    ApplicantApplicationStatus? currentStatus,
  }) async {
    final row = await updateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.viewingInvitationSent,
      currentStatus: currentStatus,
      extras: invitation.toRowFields(),
    );

    await _ensureThreadAndHostMessage(
      applicationId: applicationId,
      hostUserId: hostUserId,
      row: row,
      body: ViewingInvitation.sentTimelineBody,
    );

    return row;
  }

  static Future<Map<String, dynamic>> rescheduleViewing({
    required String applicationId,
    required String hostUserId,
    required ViewingInvitation invitation,
    required ApplicantApplicationStatus currentStatus,
  }) async {
    final row = await updateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.viewingInvitationSent,
      currentStatus: currentStatus,
      extras: invitation.toRowFields(),
    );

    await _ensureThreadAndHostMessage(
      applicationId: applicationId,
      hostUserId: hostUserId,
      row: row,
      body: ViewingInvitation.updatedTimelineBody,
    );

    return row;
  }

  static Future<Map<String, dynamic>> cancelViewing({
    required String applicationId,
    required String hostUserId,
    required ApplicantApplicationStatus currentStatus,
  }) async {
    final row = await updateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.pending,
      currentStatus: currentStatus,
      extras: ViewingInvitation.clearRowFields(),
    );

    await _ensureThreadAndHostMessage(
      applicationId: applicationId,
      hostUserId: hostUserId,
      row: row,
      body: ViewingInvitation.cancelledTimelineBody,
    );

    return row;
  }

  static Future<Map<String, dynamic>> acceptViewingInvitation({
    required String applicationId,
    required String applicantUserId,
    ApplicantApplicationStatus? currentStatus,
  }) async {
    final row = await updateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.viewingScheduled,
      currentStatus: currentStatus,
    );

    if (applicantUserId.isNotEmpty) {
      await applicationConversationService.sendMessage(
        applicationId: applicationId,
        senderUserId: applicantUserId,
        senderRole: ApplicationParticipantRole.applicant,
        body: ViewingInvitation.acceptedTimelineBody,
      );
    }

    return row;
  }

  static Future<Map<String, dynamic>> declineApplicant({
    required String applicationId,
    ApplicantApplicationStatus? currentStatus,
  }) {
    return updateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.declined,
      currentStatus: currentStatus,
    );
  }
}
