import '../models/applicant_application_status.dart';
import '../models/application_conversation.dart';
import '../models/listing_application.dart';
import '../services/application_conversation_service.dart';
import '../services/application_service.dart';

/// Seeker-facing application groups (column 1).
enum SeekerPipelineSection {
  inProgress,
  waitingForHost,
  rejected,
  archived,
}

extension SeekerPipelineSectionX on SeekerPipelineSection {
  String get label => switch (this) {
        SeekerPipelineSection.inProgress => '💬 In Progress',
        SeekerPipelineSection.waitingForHost => '⏳ Waiting for Host',
        SeekerPipelineSection.rejected => '❌ Rejected Applications',
        SeekerPipelineSection.archived => '📦 Archived',
      };

  bool get collapsedByDefault =>
      this == SeekerPipelineSection.rejected ||
      this == SeekerPipelineSection.archived;
}

class SeekerPipelineBuckets {
  const SeekerPipelineBuckets({
    required this.actionNeeded,
    required this.active,
    required this.waiting,
    required this.closed,
    required this.archived,
  });

  final List<ListingApplication> actionNeeded;
  final List<ListingApplication> active;
  final List<ListingApplication> waiting;
  final List<ListingApplication> closed;
  final List<ListingApplication> archived;

  List<ListingApplication> forSection(SeekerPipelineSection section) =>
      switch (section) {
        SeekerPipelineSection.inProgress => [
            ...actionNeeded,
            ...active,
          ],
        SeekerPipelineSection.waitingForHost => waiting,
        SeekerPipelineSection.rejected => closed,
        SeekerPipelineSection.archived => archived,
      };

  int countFor(SeekerPipelineSection section) => forSection(section).length;

  SeekerPipelineSection defaultSection() {
    if (actionNeeded.isNotEmpty || active.isNotEmpty) {
      return SeekerPipelineSection.inProgress;
    }
    if (waiting.isNotEmpty) return SeekerPipelineSection.waitingForHost;
    if (closed.isNotEmpty) return SeekerPipelineSection.rejected;
    if (archived.isNotEmpty) return SeekerPipelineSection.archived;
    return SeekerPipelineSection.inProgress;
  }
}

abstract final class SeekerApplicationPipeline {
  SeekerApplicationPipeline._();

  /// Whether a listing map represents a live marketplace listing.
  ///
  /// Active Explore rows are already `is_active = true`. A missing map means
  /// the listing is inactive/unavailable. An explicit `is_active: false` also
  /// counts as inactive (no schema change — field already on listings).
  static bool isListingActive(Map<String, dynamic>? listing) {
    if (listing == null) return false;
    final raw = listing['is_active'];
    if (raw is bool) return raw;
    if (raw == null) return true;
    final token = raw.toString().trim().toLowerCase();
    if (token.isEmpty) return true;
    return token != 'false' && token != '0';
  }

  static SeekerPipelineBuckets bucket(
    List<ListingApplication> applications, {
    bool Function(ListingApplication application)? isListingActiveFor,
  }) {
    final actionNeeded = <ListingApplication>[];
    final active = <ListingApplication>[];
    final waiting = <ListingApplication>[];
    final closed = <ListingApplication>[];
    final archived = <ListingApplication>[];

    for (final application in applications) {
      final listingActive = isListingActiveFor?.call(application) ?? true;
      if (!listingActive) {
        archived.add(application);
        continue;
      }

      if (isClosed(application)) {
        closed.add(application);
        continue;
      }

      if (_isInProgress(application)) {
        if (unreadCount(application) > 0) {
          actionNeeded.add(application);
        } else {
          active.add(application);
        }
        continue;
      }

      waiting.add(application);
    }

    return SeekerPipelineBuckets(
      actionNeeded: actionNeeded,
      active: active,
      waiting: waiting,
      closed: closed,
      archived: archived,
    );
  }

  static bool _isInProgress(ListingApplication application) {
    if (unreadCount(application) > 0) return true;
    if (hasConversationActivity(application)) return true;
    return switch (status(application)) {
      ApplicantApplicationStatus.viewingInvitationSent ||
      ApplicantApplicationStatus.viewingScheduled ||
      ApplicantApplicationStatus.accepted =>
        true,
      ApplicantApplicationStatus.pending ||
      ApplicantApplicationStatus.declined =>
        false,
    };
  }

  static bool hasConversationActivity(ListingApplication application) {
    final messages = applicationConversationService
            .peek(application.id)
            ?.messages ??
        const [];
    return messages.isNotEmpty;
  }

  static ApplicantApplicationStatus status(ListingApplication application) {
    return ApplicantApplicationStatus.parseOrDefault(
      applicationService.rowById(application.id)?['status']?.toString(),
    );
  }

  static String statusRaw(ListingApplication application) =>
      applicationService.rowById(application.id)?['status']?.toString() ?? '';

  static bool isClosed(ListingApplication application) {
    final raw = statusRaw(application).trim().toLowerCase();
    if (raw == 'withdrawn' || raw == 'closed') return true;
    return status(application) == ApplicantApplicationStatus.declined;
  }

  static String statusDisplay(ListingApplication application) =>
      workspaceStatusDisplay(application);

  static String workspaceStatusDisplay(
    ListingApplication application, {
    bool listingIsActive = true,
  }) {
    if (!listingIsActive) return '📦 Archived';

    if (isClosed(application)) {
      final token = statusRaw(application).trim().toLowerCase();
      if (token == 'withdrawn') return '❌ Rejected';
      return '❌ Rejected';
    }

    return switch (status(application)) {
      ApplicantApplicationStatus.viewingInvitationSent =>
        '📨 Viewing Invitation Sent',
      ApplicantApplicationStatus.viewingScheduled => '📅 Viewing Scheduled',
      ApplicantApplicationStatus.accepted => '✅ Accepted',
      ApplicantApplicationStatus.declined => '❌ Rejected',
      ApplicantApplicationStatus.pending when unreadCount(application) > 0 =>
        '💬 In Progress',
      ApplicantApplicationStatus.pending
          when hasConversationActivity(application) =>
        '💬 In Progress',
      ApplicantApplicationStatus.pending => '⏳ Waiting for Host',
    };
  }

  static bool isConversationUnlocked(ListingApplication application) {
    if (hasConversationActivity(application)) return true;
    return switch (status(application)) {
      ApplicantApplicationStatus.viewingInvitationSent ||
      ApplicantApplicationStatus.viewingScheduled ||
      ApplicantApplicationStatus.accepted =>
        true,
      ApplicantApplicationStatus.pending ||
      ApplicantApplicationStatus.declined =>
        false,
    };
  }

  /// Listing-detail CTA when an application already exists for this seeker.
  /// Returns `null` when the seeker has not applied yet.
  static String? listingDetailStateLabel({
    required String listingId,
    required String userId,
  }) {
    final row = applicationService.rowForListingUser(
      listingId: listingId,
      userId: userId,
    );
    if (row == null) return null;
    final application = ListingApplication.fromMap(row);
    if (isClosed(application)) return 'Application Closed';
    return switch (status(application)) {
      ApplicantApplicationStatus.viewingInvitationSent =>
        'Viewing Invitation Sent',
      ApplicantApplicationStatus.viewingScheduled => 'Viewing Scheduled',
      ApplicantApplicationStatus.accepted => 'Accepted',
      ApplicantApplicationStatus.declined => 'Application Closed',
      ApplicantApplicationStatus.pending
          when hasConversationActivity(application) ||
              unreadCount(application) > 0 =>
        'In Progress',
      ApplicantApplicationStatus.pending => 'Story Sent — Awaiting Host',
    };
  }

  static String formatAppliedDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  static String activityPreview(ListingApplication application) {
    final messages = applicationConversationService
            .peek(application.id)
            ?.messages ??
        const [];
    if (messages.isEmpty) return '';
    final last = messages.last;
    if (last.senderRole == ApplicationParticipantRole.host) {
      var body = last.body.trim();
      if (body.length > 60) body = '${body.substring(0, 57).trim()}…';
      return body.isEmpty ? 'Host replied' : body;
    }
    return 'You replied';
  }

  static bool lastMessageFromHost(ListingApplication application) {
    final messages = applicationConversationService
            .peek(application.id)
            ?.messages ??
        const [];
    if (messages.isEmpty) return false;
    return messages.last.senderRole == ApplicationParticipantRole.host;
  }

  static int unreadCount(ListingApplication application) {
    return applicationConversationService.unreadCount(
      applicationId: application.id,
      role: ApplicationParticipantRole.applicant,
    );
  }
}
