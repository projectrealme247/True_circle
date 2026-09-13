import '../../models/applicant_application_status.dart';
import '../../models/landlord_applicant_card_model.dart';

/// Landlord applicant queue sections for viewing lifecycle management.
enum LandlordQueueSection {
  inProgress,
  viewingInvitations,
  viewingsScheduled,
  accepted,
  rejected,
}

extension LandlordQueueSectionX on LandlordQueueSection {
  String get label => switch (this) {
        LandlordQueueSection.inProgress => '💬 In Progress',
        LandlordQueueSection.viewingInvitations => '📨 Viewing Invitations',
        LandlordQueueSection.viewingsScheduled => '📅 Viewings Scheduled',
        LandlordQueueSection.accepted => '✅ Accepted',
        LandlordQueueSection.rejected => '❌ Rejected',
      };

  static LandlordQueueSection forStatus(ApplicantApplicationStatus status) {
    return switch (status) {
      ApplicantApplicationStatus.pending => LandlordQueueSection.inProgress,
      ApplicantApplicationStatus.viewingInvitationSent =>
        LandlordQueueSection.viewingInvitations,
      ApplicantApplicationStatus.viewingScheduled =>
        LandlordQueueSection.viewingsScheduled,
      ApplicantApplicationStatus.accepted => LandlordQueueSection.accepted,
      ApplicantApplicationStatus.declined => LandlordQueueSection.rejected,
    };
  }
}

class LandlordQueueBuckets {
  const LandlordQueueBuckets({
    required this.inProgress,
    required this.viewingInvitations,
    required this.viewingsScheduled,
    required this.accepted,
    required this.rejected,
  });

  final List<LandlordApplicantCardModel> inProgress;
  final List<LandlordApplicantCardModel> viewingInvitations;
  final List<LandlordApplicantCardModel> viewingsScheduled;
  final List<LandlordApplicantCardModel> accepted;
  final List<LandlordApplicantCardModel> rejected;

  List<LandlordApplicantCardModel> forSection(LandlordQueueSection section) =>
      switch (section) {
        LandlordQueueSection.inProgress => inProgress,
        LandlordQueueSection.viewingInvitations => viewingInvitations,
        LandlordQueueSection.viewingsScheduled => viewingsScheduled,
        LandlordQueueSection.accepted => accepted,
        LandlordQueueSection.rejected => rejected,
      };

  static LandlordQueueBuckets from(List<LandlordApplicantCardModel> applicants) {
    final inProgress = <LandlordApplicantCardModel>[];
    final invitations = <LandlordApplicantCardModel>[];
    final scheduled = <LandlordApplicantCardModel>[];
    final accepted = <LandlordApplicantCardModel>[];
    final rejected = <LandlordApplicantCardModel>[];

    for (final applicant in applicants) {
      switch (applicant.status) {
        case ApplicantApplicationStatus.pending:
          inProgress.add(applicant);
        case ApplicantApplicationStatus.viewingInvitationSent:
          invitations.add(applicant);
        case ApplicantApplicationStatus.viewingScheduled:
          scheduled.add(applicant);
        case ApplicantApplicationStatus.accepted:
          accepted.add(applicant);
        case ApplicantApplicationStatus.declined:
          rejected.add(applicant);
      }
    }

    return LandlordQueueBuckets(
      inProgress: inProgress,
      viewingInvitations: invitations,
      viewingsScheduled: scheduled,
      accepted: accepted,
      rejected: rejected,
    );
  }

  /// Next applicant after rejecting [rejectedId], preferring active sections.
  LandlordApplicantCardModel? nextAfterReject(String rejectedId) {
    for (final section in const [
      LandlordQueueSection.inProgress,
      LandlordQueueSection.viewingInvitations,
      LandlordQueueSection.viewingsScheduled,
      LandlordQueueSection.accepted,
      LandlordQueueSection.rejected,
    ]) {
      for (final applicant in forSection(section)) {
        if (applicant.applicationId != rejectedId) return applicant;
      }
    }
    return null;
  }
}
