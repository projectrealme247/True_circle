import '../models/applicant_application_status.dart';

/// Validates host status transitions before Supabase mutations.
abstract final class ApplicantStatusTransitionService {
  static const _allowedTransitions = {
    ApplicantApplicationStatus.pending: {
      ApplicantApplicationStatus.viewingInvitationSent,
      ApplicantApplicationStatus.accepted,
      ApplicantApplicationStatus.declined,
    },
    ApplicantApplicationStatus.viewingInvitationSent: {
      ApplicantApplicationStatus.viewingScheduled,
      ApplicantApplicationStatus.pending,
      ApplicantApplicationStatus.declined,
    },
    ApplicantApplicationStatus.viewingScheduled: {
      ApplicantApplicationStatus.viewingInvitationSent,
      ApplicantApplicationStatus.accepted,
      ApplicantApplicationStatus.pending,
      ApplicantApplicationStatus.declined,
    },
    ApplicantApplicationStatus.accepted: <ApplicantApplicationStatus>{},
    ApplicantApplicationStatus.declined: <ApplicantApplicationStatus>{},
  };

  static bool canTransition({
    required ApplicantApplicationStatus from,
    required ApplicantApplicationStatus to,
  }) {
    if (from == to) return true;
    return _allowedTransitions[from]?.contains(to) ?? false;
  }

  static String? validateTransition({
    required ApplicantApplicationStatus from,
    required ApplicantApplicationStatus to,
  }) {
    if (from == to) return null;
    if (canTransition(from: from, to: to)) return null;
    return 'Cannot move an application from "${from.storageToken}" '
        'to "${to.storageToken}".';
  }
}
