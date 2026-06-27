import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/applicant_application_status.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/listing_applicant_dashboard.dart';
import '../models/shared_living_applicant_stream.dart';
import '../models/high_signal_match.dart';
import '../repositories/tenant_profile_repository.dart';
import 'applicant_dashboard_payload_builder.dart';
import 'applicant_status_transition_service.dart';
import 'applicant_stream_payload_builder.dart';
import 'auth_service.dart';

/// Supabase read/write layer for host applicant management (Phase C Step 3).
abstract final class ApplicantManagementSupabaseService {
  static const _applicationsTable = 'listing_applications';
  static const _listingsTable = 'listings';
  static const _trustProfilesTable = 'user_trust_profiles';

  static bool get canQuery => AuthService.isAuthenticated;

  /// Category-specific independent-places stream (trust-tier blocks).
  static Future<IndependentPlacesApplicantStream> getIndependentPlaceApplicants(
    String listingId,
  ) async {
    final context = await _loadApplicantContext(listingId);
    return ApplicantStreamPayloadBuilder.buildIndependentPlacesStream(
      listing: context.listing,
      applicationRows: context.applicationRows,
      trustProfilesByUserId: context.trustProfiles,
      highSignalMatchesByApplicationId: context.highSignalMatchesByApplicationId,
    );
  }

  /// Category-specific shared-living stream (trust-tier blocks).
  static Future<SharedLivingApplicantStream> getSharedLivingApplicants(
    String listingId,
  ) async {
    final context = await _loadApplicantContext(listingId);
    return ApplicantStreamPayloadBuilder.buildSharedLivingStream(
      listing: context.listing,
      applicationRows: context.applicationRows,
      trustProfilesByUserId: context.trustProfiles,
      highSignalMatchesByApplicationId: context.highSignalMatchesByApplicationId,
    );
  }

  /// Joins `listing_applications` with seeker trust profiles and builds a
  /// category-sorted dashboard payload for the listing host.
  static Future<ListingApplicantDashboard> fetchApplicantsForListing(
    String listingId,
  ) async {
    final context = await _loadApplicantContext(listingId);
    return ApplicantDashboardPayloadBuilder.build(
      listing: context.listing,
      applicationRows: context.applicationRows,
      trustProfilesByUserId: context.trustProfiles,
      highSignalMatchesByApplicationId: context.highSignalMatchesByApplicationId,
    );
  }

  static Future<_ApplicantLoadContext> _loadApplicantContext(
    String listingId,
  ) async {
    _requireAuth();
    if (listingId.trim().isEmpty) {
      throw ApplicantManagementException(
        'Listing id is required.',
        code: ApplicantManagementErrorCode.validation,
      );
    }

    try {
      final listing = await _fetchListing(listingId);
      final applicationRows = await _fetchApplicationRows(listingId);
      final applicantIds = applicationRows
          .map((row) => row['applicant_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final trustProfiles = await _fetchTrustProfiles(applicantIds);
      final highSignalMatches = await _fetchHighSignalMatches(listingId);
      final highSignalMatchesByApplicationId =
          HighSignalMatch.indexByApplicationId(highSignalMatches);
      final matchesByUserId =
          HighSignalMatch.indexByApplicantUserId(highSignalMatches);

      for (final row in applicationRows) {
        final applicationId = row['id']?.toString() ?? '';
        if (highSignalMatchesByApplicationId.containsKey(applicationId)) {
          continue;
        }
        final applicantUserId = row['applicant_user_id']?.toString() ?? '';
        final fallback = matchesByUserId[applicantUserId];
        if (fallback != null && applicationId.isNotEmpty) {
          highSignalMatchesByApplicationId[applicationId] = fallback;
        }
      }

      return _ApplicantLoadContext(
        listing: listing,
        applicationRows: applicationRows,
        trustProfiles: trustProfiles,
        highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
      );
    } on ApplicantManagementException {
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint(
        'ApplicantManagementSupabaseService fetch failed: ${e.message}',
      );
      throw ApplicantManagementException(
        e.message.trim().isEmpty
            ? 'Could not load applicants for this listing.'
            : e.message,
        code: ApplicantManagementErrorCode.database,
        cause: e,
      );
    } catch (e) {
      debugPrint('ApplicantManagementSupabaseService fetch error: $e');
      final isTimeout = e is TimeoutException;
      throw ApplicantManagementException(
        isTimeout
            ? 'Loading applicants timed out. Check your connection and retry.'
            : 'Could not load applicants for this listing.',
        code: isTimeout
            ? ApplicantManagementErrorCode.timeout
            : ApplicantManagementErrorCode.network,
        cause: e,
      );
    }
  }

  /// Atomically updates a single application status for a listing host.
  static Future<Map<String, dynamic>> updateApplicationStatus({
    required String applicationId,
    required ApplicantApplicationStatus nextStatus,
    ApplicantApplicationStatus? currentStatus,
  }) async {
    _requireAuth();
    if (applicationId.trim().isEmpty) {
      throw ApplicantManagementException(
        'Application id is required.',
        code: ApplicantManagementErrorCode.validation,
      );
    }

    if (currentStatus != null) {
      final transitionError = ApplicantStatusTransitionService.validateTransition(
        from: currentStatus,
        to: nextStatus,
      );
      if (transitionError != null) {
        throw ApplicantManagementException(
          transitionError,
          code: ApplicantManagementErrorCode.invalidTransition,
        );
      }
    }

    try {
      final existing = await AuthService.client
          .from(_applicationsTable)
          .select('id, status, listing_id, applicant_user_id')
          .eq('id', applicationId)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));

      if (existing == null) {
        throw ApplicantManagementException(
          'Application not found.',
          code: ApplicantManagementErrorCode.notFound,
        );
      }

      final resolvedCurrent = ApplicantApplicationStatus.parseOrDefault(
        existing['status']?.toString(),
      );
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

      final response = await AuthService.client
          .from(_applicationsTable)
          .update({
            'status': nextStatus.storageToken,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', applicationId)
          .select()
          .single()
          .timeout(const Duration(seconds: 20));

      return Map<String, dynamic>.from(response);
    } on ApplicantManagementException {
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint(
        'ApplicantManagementSupabaseService status update failed: ${e.message}',
      );
      throw ApplicantManagementException(
        e.message.trim().isEmpty
            ? 'Could not update application status.'
            : e.message,
        code: ApplicantManagementErrorCode.database,
        cause: e,
      );
    } catch (e) {
      debugPrint('ApplicantManagementSupabaseService status update error: $e');
      final isTimeout = e is TimeoutException;
      throw ApplicantManagementException(
        isTimeout
            ? 'Status update timed out. Check your connection and retry.'
            : 'Could not update application status.',
        code: isTimeout
            ? ApplicantManagementErrorCode.timeout
            : ApplicantManagementErrorCode.network,
        cause: e,
      );
    }
  }

  static Future<Map<String, dynamic>> _fetchListing(String listingId) async {
    final response = await AuthService.client
        .from(_listingsTable)
        .select(
          'id, user_id, title, price, listing_type, metadata, '
          'marketplace_category, languages_spoken, kitchen_culture, '
          'household_dynamic, lifestyle_flags',
        )
        .eq('id', listingId)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

    if (response == null) {
      throw ApplicantManagementException(
        'Listing not found.',
        code: ApplicantManagementErrorCode.notFound,
      );
    }

    return Map<String, dynamic>.from(response);
  }

  static Future<List<Map<String, dynamic>>> _fetchApplicationRows(
    String listingId,
  ) async {
    final response = await AuthService.client
        .from(_applicationsTable)
        .select()
        .eq('listing_id', listingId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 20));

    return [
      for (final row in response as List)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  static Future<List<HighSignalMatch>> _fetchHighSignalMatches(
    String listingId,
  ) async {
    try {
      return await TenantProfileRepository.getHighSignalMatches(listingId);
    } on PostgrestException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e) {
      debugPrint(
        'ApplicantManagementSupabaseService high-signal RPC fallback: $e',
      );
      return const [];
    }
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchTrustProfiles(
    List<String> applicantUserIds,
  ) async {
    if (applicantUserIds.isEmpty) return const {};

    final response = await AuthService.client
        .from(_trustProfilesTable)
        .select(
          'user_id, full_name, trust_tier, trust_stage, '
          'employment_verified, financial_verified, verification_track, '
          'corporate_verification_seal',
        )
        .inFilter('user_id', applicantUserIds)
        .timeout(const Duration(seconds: 20));

    final profiles = <String, Map<String, dynamic>>{};
    for (final row in response as List) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final userId = map['user_id']?.toString() ?? '';
      if (userId.isEmpty) continue;
      profiles[userId] = map;
    }
    return profiles;
  }

  static void _requireAuth() {
    if (!canQuery) {
      throw ApplicantManagementException(
        'Sign in to manage applicants.',
        code: ApplicantManagementErrorCode.unauthenticated,
      );
    }
  }
}

class _ApplicantLoadContext {
  const _ApplicantLoadContext({
    required this.listing,
    required this.applicationRows,
    required this.trustProfiles,
    required this.highSignalMatchesByApplicationId,
  });

  final Map<String, dynamic> listing;
  final List<Map<String, dynamic>> applicationRows;
  final Map<String, Map<String, dynamic>> trustProfiles;
  final Map<String, HighSignalMatch> highSignalMatchesByApplicationId;
}

enum ApplicantManagementErrorCode {
  validation,
  unauthenticated,
  notFound,
  invalidTransition,
  categoryMismatch,
  database,
  network,
  timeout,
}

class ApplicantManagementException implements Exception {
  ApplicantManagementException(
    this.message, {
    required this.code,
    this.cause,
  });

  final String message;
  final ApplicantManagementErrorCode code;
  final Object? cause;

  @override
  String toString() => message;
}
