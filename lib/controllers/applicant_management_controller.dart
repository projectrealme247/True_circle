import 'package:flutter/foundation.dart';

import '../models/applicant_application_status.dart';
import '../models/high_signal_match.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/listing_applicant_dashboard.dart';
import '../models/shared_living_applicant_stream.dart';
import '../services/applicant_dashboard_payload_builder.dart';
import '../services/applicant_management_supabase_service.dart';
import '../services/applicant_status_transition_service.dart';
import '../services/applicant_stream_payload_builder.dart';

export '../services/applicant_management_supabase_service.dart'
    show
        ApplicantManagementErrorCode,
        ApplicantManagementException;

/// Injectable fetch/update hooks for tests and alternate backends.
typedef ApplicantDashboardFetchFn = Future<ListingApplicantDashboard> Function(
  String listingId,
);

typedef ApplicantStatusUpdateFn = Future<Map<String, dynamic>> Function({
  required String applicationId,
  required ApplicantApplicationStatus nextStatus,
  ApplicantApplicationStatus? currentStatus,
});

typedef IndependentPlacesStreamFetchFn =
    Future<IndependentPlacesApplicantStream> Function(String listingId);

typedef SharedLivingStreamFetchFn = Future<SharedLivingApplicantStream> Function(
  String listingId,
);

/// Phase C Step 3 — applicant fetch engine + status mutation facade.
abstract final class ApplicantManagementController {
  /// Independent-places stream: trust-tier blocks sorted by move-in + lease fit.
  static Future<IndependentPlacesApplicantStream> getIndependentPlaceApplicants(
    String listingId, {
    IndependentPlacesStreamFetchFn? fetchOverride,
  }) {
    return (fetchOverride ??
            ApplicantManagementSupabaseService.getIndependentPlaceApplicants)(
      listingId,
    );
  }

  /// Shared-living stream: trust-tier blocks sorted by lifestyle match %.
  static Future<SharedLivingApplicantStream> getSharedLivingApplicants(
    String listingId, {
    SharedLivingStreamFetchFn? fetchOverride,
  }) {
    return (fetchOverride ??
            ApplicantManagementSupabaseService.getSharedLivingApplicants)(
      listingId,
    );
  }

  /// Loads inbound seekers for a listing and returns a sorted dashboard model.
  static Future<ListingApplicantDashboard> fetchApplicantsForListing(
    String listingId, {
    ApplicantDashboardFetchFn? fetchOverride,
  }) {
    return (fetchOverride ?? ApplicantManagementSupabaseService.fetchApplicantsForListing)(
      listingId,
    );
  }

  /// Schedules a viewing with an inbound seeker.
  static Future<Map<String, dynamic>> scheduleViewing({
    required String applicationId,
    ApplicantApplicationStatus? currentStatus,
    ApplicantStatusUpdateFn? updateOverride,
  }) {
    return _mutateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.viewingInvitationSent,
      currentStatus: currentStatus,
      updateOverride: updateOverride,
    );
  }

  /// Accepts an inbound seeker application.
  static Future<Map<String, dynamic>> acceptApplicant({
    required String applicationId,
    ApplicantApplicationStatus? currentStatus,
    ApplicantStatusUpdateFn? updateOverride,
  }) {
    return _mutateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.accepted,
      currentStatus: currentStatus,
      updateOverride: updateOverride,
    );
  }

  /// Declines an inbound seeker application.
  static Future<Map<String, dynamic>> declineApplicant({
    required String applicationId,
    ApplicantApplicationStatus? currentStatus,
    ApplicantStatusUpdateFn? updateOverride,
  }) {
    return _mutateStatus(
      applicationId: applicationId,
      nextStatus: ApplicantApplicationStatus.declined,
      currentStatus: currentStatus,
      updateOverride: updateOverride,
    );
  }

  /// Generic status mutation with transition-matrix guardrails.
  static Future<Map<String, dynamic>> updateStatus({
    required String applicationId,
    required ApplicantApplicationStatus nextStatus,
    ApplicantApplicationStatus? currentStatus,
    ApplicantStatusUpdateFn? updateOverride,
  }) {
    return _mutateStatus(
      applicationId: applicationId,
      nextStatus: nextStatus,
      currentStatus: currentStatus,
      updateOverride: updateOverride,
    );
  }

  /// Pure helper for UI-agnostic transition validation.
  @visibleForTesting
  static String? validateStatusTransition({
    required ApplicantApplicationStatus from,
    required ApplicantApplicationStatus to,
  }) {
    return ApplicantStatusTransitionService.validateTransition(
      from: from,
      to: to,
    );
  }

  /// Pure helper for tests — build independent-places stream without Supabase.
  @visibleForTesting
  static IndependentPlacesApplicantStream buildIndependentPlacesStream({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
    required Map<String, Map<String, dynamic>> trustProfilesByUserId,
    Map<String, HighSignalMatch> highSignalMatchesByApplicationId = const {},
  }) {
    return ApplicantStreamPayloadBuilder.buildIndependentPlacesStream(
      listing: listing,
      applicationRows: applicationRows,
      trustProfilesByUserId: trustProfilesByUserId,
      highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
    );
  }

  /// Pure helper for tests — build shared-living stream without Supabase.
  @visibleForTesting
  static SharedLivingApplicantStream buildSharedLivingStream({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
    required Map<String, Map<String, dynamic>> trustProfilesByUserId,
    Map<String, HighSignalMatch> highSignalMatchesByApplicationId = const {},
  }) {
    return ApplicantStreamPayloadBuilder.buildSharedLivingStream(
      listing: listing,
      applicationRows: applicationRows,
      trustProfilesByUserId: trustProfilesByUserId,
      highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
    );
  }

  /// Pure helper for tests — build dashboard without Supabase.
  @visibleForTesting
  static ListingApplicantDashboard buildDashboard({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
    required Map<String, Map<String, dynamic>> trustProfilesByUserId,
    Map<String, HighSignalMatch> highSignalMatchesByApplicationId = const {},
  }) {
    return ApplicantDashboardPayloadBuilder.build(
      listing: listing,
      applicationRows: applicationRows,
      trustProfilesByUserId: trustProfilesByUserId,
      highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
    );
  }

  static Future<Map<String, dynamic>> _mutateStatus({
    required String applicationId,
    required ApplicantApplicationStatus nextStatus,
    ApplicantApplicationStatus? currentStatus,
    ApplicantStatusUpdateFn? updateOverride,
  }) {
    final update = updateOverride ??
        (({
          required String applicationId,
          required ApplicantApplicationStatus nextStatus,
          ApplicantApplicationStatus? currentStatus,
        }) {
          return ApplicantManagementSupabaseService.updateApplicationStatus(
            applicationId: applicationId,
            nextStatus: nextStatus,
            currentStatus: currentStatus,
          );
        });

    return update(
      applicationId: applicationId,
      nextStatus: nextStatus,
      currentStatus: currentStatus,
    );
  }
}
