import '../models/applicant_application_status.dart';
import '../models/applicant_field_keys.dart';
import '../models/applicant_trust_tier.dart';
import '../models/applicant_trust_tier_block.dart';
import '../models/high_signal_match.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/shared_living_applicant_stream.dart';
import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';
import '../utils/shared_space_compatibility_scorer.dart';
import 'applicant_management_supabase_service.dart';
import 'applicant_payload_sanitizer.dart';

/// Builds category-specific, trust-tier-grouped applicant stream payloads.
abstract final class ApplicantStreamPayloadBuilder {
  static const _trustTierOrder = [
    ApplicantTrustTier.sound,
    ApplicantTrustTier.grand,
    ApplicantTrustTier.justLanded,
  ];

  static IndependentPlacesApplicantStream buildIndependentPlacesStream({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
    required Map<String, Map<String, dynamic>> trustProfilesByUserId,
    Map<String, HighSignalMatch> highSignalMatchesByApplicationId = const {},
  }) {
    _assertCategory(
      listing: listing,
      expected: IndependentPlacesApplicantStream.categoryToken,
    );

    final listingId = listing['id']?.toString() ?? '';
    final listingTargetMoveIn = _listingTargetMoveInDate(listing);
    final listingLeaseMonths = _listingLeaseTermMonths(listing);
    final rowsByTier = {
      for (final tier in _trustTierOrder) tier: <IndependentPlacesApplicantRow>[],
    };

    for (final row in applicationRows) {
      final applicationId = row['id']?.toString() ?? '';
      final applicantUserId = row['applicant_user_id']?.toString() ?? '';
      final trustProfile = trustProfilesByUserId[applicantUserId] ?? const {};
      final session = _mergedSession(row, trustProfile);
      final trustTier = _trustTier(session, trustProfile);
      final signal = _resolveHighSignalMatch(
        applicationId: applicationId,
        applicantUserId: applicantUserId,
        highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
      );
      final preferredLeaseMonths = _preferredLeaseMonths(session);
      final earliestMoveIn = _parseDate(
        ProfileData.text(session[ApplicantFieldKeys.earliestMoveInDate]),
      );
      final varianceDays = _timelineVarianceDays(
        seekerMoveIn: earliestMoveIn,
        listingTargetMoveIn: listingTargetMoveIn,
      );

      final localCompatibility = _compatibilityScore(row);
      final displayScore = signal?.overallMatchScore ?? localCompatibility;

      rowsByTier[trustTier]!.add(
        IndependentPlacesApplicantRow(
          applicationId: applicationId,
          listingId: listingId,
          applicantUserId: applicantUserId,
          seekerName: _seekerName(session, trustProfile),
          status: ApplicantApplicationStatus.parseOrDefault(
            row['status']?.toString(),
          ),
          trustTier: trustTier,
          moveInTimelineMatch: _moveInTimelineMatch(varianceDays),
          leaseTermMatch: _leaseTermMatch(
            seekerLeaseMonths: preferredLeaseMonths,
            listingLeaseMonths: listingLeaseMonths,
          ),
          employmentVerified: _employmentVerified(session, trustProfile),
          corporateDocumentVerified: _corporateDocumentVerified(
            session,
            trustProfile,
          ),
          timelineVarianceDays: varianceDays,
          preferredLeaseMonths: preferredLeaseMonths,
          earliestMoveInDate: earliestMoveIn?.toIso8601String().split('T').first,
          compatibilityScore: displayScore,
          overallMatchScore: signal?.overallMatchScore,
          verifiedTransitDurationSeconds:
              signal?.verifiedTransitDurationSeconds,
          affordabilityMultiplier: _affordabilityMultiplier(
            session: session,
            trustTier: trustTier,
            listing: listing,
          ),
          createdAt: _createdAt(row),
        ),
      );
    }

    for (final tier in _trustTierOrder) {
      rowsByTier[tier]!.sort((a, b) {
        final scoreA = a.overallMatchScore ?? a.compatibilityScore;
        final scoreB = b.overallMatchScore ?? b.compatibilityScore;
        final byScore = scoreB.compareTo(scoreA);
        if (byScore != 0) return byScore;

        final varianceA = a.timelineVarianceDays ?? 9999;
        final varianceB = b.timelineVarianceDays ?? 9999;
        final byTimeline = varianceA.compareTo(varianceB);
        if (byTimeline != 0) return byTimeline;

        final leaseA = a.preferredLeaseMonths ?? 0;
        final leaseB = b.preferredLeaseMonths ?? 0;
        return leaseB.compareTo(leaseA);
      });
    }

    final blocks = [
      for (final tier in _trustTierOrder)
        if (rowsByTier[tier]!.isNotEmpty)
          ApplicantTrustTierBlock(
            trustTier: tier,
            applicants: rowsByTier[tier]!,
          ),
    ];

    return IndependentPlacesApplicantStream(
      listingId: listingId,
      marketplaceCategory: IndependentPlacesApplicantStream.categoryToken,
      blocks: blocks,
      totalCount: applicationRows.length,
    );
  }

  static SharedLivingApplicantStream buildSharedLivingStream({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
    required Map<String, Map<String, dynamic>> trustProfilesByUserId,
    Map<String, HighSignalMatch> highSignalMatchesByApplicationId = const {},
  }) {
    _assertCategory(
      listing: listing,
      expected: SharedLivingApplicantStream.categoryToken,
    );

    final listingId = listing['id']?.toString() ?? '';
    final listingLanguages = ApplicantPayloadSanitizer.listingLanguagesFromRow(
      listing,
    );
    final listingKitchenCulture = ProfileData.text(
      listing[ListingCreationFieldKeys.kitchenCulture],
    );
    final rowsByTier = {
      for (final tier in _trustTierOrder) tier: <SharedLivingApplicantRow>[],
    };

    for (final row in applicationRows) {
      final applicationId = row['id']?.toString() ?? '';
      final applicantUserId = row['applicant_user_id']?.toString() ?? '';
      final trustProfile = trustProfilesByUserId[applicantUserId] ?? const {};
      final session = _mergedSession(row, trustProfile);
      final trustTier = _trustTier(session, trustProfile);
      final signal = _resolveHighSignalMatch(
        applicationId: applicationId,
        applicantUserId: applicantUserId,
        highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
      );
    final seekerLanguages = ApplicantPayloadSanitizer.seekerLanguagesFromSession(
      session,
    );
      final overlap = ApplicantPayloadSanitizer.languageIntersection(
        seekerLanguages,
        listingLanguages,
      );
      final kitchenAligned = _kitchenCultureAligned(
        listingKitchenCulture: listingKitchenCulture,
        seekerFoodPreference: ProfileData.text(
          session[ApplicantFieldKeys.foodPreference],
        ),
      );
      final lifestyleScore = NumericBounds.clampPercentInt(
        SharedSpaceCompatibilityScorer.calculateCompatibility(
          seekerSession: session,
          listing: listing,
        ),
      );
      final displayScore = signal?.overallMatchScore ?? lifestyleScore;

      rowsByTier[trustTier]!.add(
        SharedLivingApplicantRow(
          applicationId: applicationId,
          listingId: listingId,
          applicantUserId: applicantUserId,
          seekerName: _seekerName(session, trustProfile),
          status: ApplicantApplicationStatus.parseOrDefault(
            row['status']?.toString(),
          ),
          trustTier: trustTier,
          lifestyleMatchScorePercent: displayScore,
          languageAlignmentOverlap: overlap,
          seekerLanguages: seekerLanguages,
          listingLanguages: listingLanguages,
          kitchenCultureAligned: kitchenAligned,
          listingKitchenCulture:
              listingKitchenCulture.isEmpty ? null : listingKitchenCulture,
          customBioPitch: _customBioPitch(session),
          compatibilityScore: _compatibilityScore(row),
          overallMatchScore: signal?.overallMatchScore,
          verifiedTransitDurationSeconds:
              signal?.verifiedTransitDurationSeconds,
          affordabilityMultiplier: _affordabilityMultiplier(
            session: session,
            trustTier: trustTier,
            listing: listing,
          ),
          createdAt: _createdAt(row),
        ),
      );
    }

    for (final tier in _trustTierOrder) {
      rowsByTier[tier]!.sort((a, b) {
        final scoreA = a.overallMatchScore ?? a.lifestyleMatchScorePercent;
        final scoreB = b.overallMatchScore ?? b.lifestyleMatchScorePercent;
        return scoreB.compareTo(scoreA);
      });
    }

    final blocks = [
      for (final tier in _trustTierOrder)
        if (rowsByTier[tier]!.isNotEmpty)
          ApplicantTrustTierBlock(
            trustTier: tier,
            applicants: rowsByTier[tier]!,
          ),
    ];

    return SharedLivingApplicantStream(
      listingId: listingId,
      marketplaceCategory: SharedLivingApplicantStream.categoryToken,
      blocks: blocks,
      totalCount: applicationRows.length,
    );
  }

  static HighSignalMatch? _resolveHighSignalMatch({
    required String applicationId,
    required String applicantUserId,
    required Map<String, HighSignalMatch> highSignalMatchesByApplicationId,
  }) {
    final byApplication = highSignalMatchesByApplicationId[applicationId];
    if (byApplication != null) return byApplication;

    for (final match in highSignalMatchesByApplicationId.values) {
      if (match.applicantUserId == applicantUserId &&
          applicantUserId.isNotEmpty) {
        return match;
      }
    }
    return null;
  }

  static void _assertCategory({
    required Map<String, dynamic> listing,
    required String expected,
  }) {
    final actual = ProfileData.text(
      listing[ListingCreationFieldKeys.marketplaceCategory],
    ).toLowerCase();
    if (actual != expected) {
      throw ApplicantManagementException(
        'Listing marketplace_category must be "$expected" (found "$actual").',
        code: ApplicantManagementErrorCode.categoryMismatch,
      );
    }
  }

  static Map<String, dynamic> _mergedSession(
    Map<String, dynamic> row,
    Map<String, dynamic> trustProfile,
  ) {
    final payload = row['payload'];
    final session = payload is Map
        ? ApplicantPayloadSanitizer.sanitizeSession(
            Map<String, dynamic>.from(payload),
          )
        : <String, dynamic>{};

    if (trustProfile.isEmpty) return session;

    return {
      ...session,
      ApplicantFieldKeys.fullName: trustProfile['full_name'],
      ApplicantFieldKeys.trustTier: trustProfile['trust_tier'],
      ApplicantFieldKeys.trustStage: trustProfile['trust_stage'],
      ApplicantFieldKeys.employmentVerified: trustProfile['employment_verified'],
      ApplicantFieldKeys.financialVerified: trustProfile['financial_verified'],
      ApplicantFieldKeys.verificationTrack: trustProfile['verification_track'],
    };
  }

  static ApplicantTrustTier _trustTier(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile,
  ) {
    return ApplicantTrustTier.fromTrustProfile(
      trustTier: ProfileData.text(
        session[ApplicantFieldKeys.trustTier] ?? trustProfile['trust_tier'],
      ),
      trustStage: session[ApplicantFieldKeys.trustStage] is int
          ? session[ApplicantFieldKeys.trustStage] as int
          : trustProfile['trust_stage'] is int
              ? trustProfile['trust_stage'] as int
              : int.tryParse(
                    ProfileData.text(
                      session[ApplicantFieldKeys.trustStage] ??
                          trustProfile['trust_stage'],
                    ),
                  ),
    );
  }

  static String _seekerName(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile,
  ) {
    final fromSession = ProfileData.text(session[ApplicantFieldKeys.fullName]);
    if (fromSession.isNotEmpty) return fromSession;
    return ProfileData.text(trustProfile['full_name']);
  }

  static String _customBioPitch(Map<String, dynamic> session) {
    for (final key in const [
      ApplicantFieldKeys.pitchNarrative,
      ApplicantFieldKeys.personalIntroduction,
      ApplicantFieldKeys.bio,
      ApplicantFieldKeys.aboutMe,
    ]) {
      final value = ProfileData.text(session[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static bool _employmentVerified(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile,
  ) {
    return session[ApplicantFieldKeys.employmentVerified] == true ||
        trustProfile['employment_verified'] == true;
  }

  static bool _corporateDocumentVerified(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile,
  ) {
    final track = ProfileData.text(
      session[ApplicantFieldKeys.verificationTrack] ??
          trustProfile['verification_track'],
    ).toLowerCase();
    final hasCorporateTrack = track.contains('corporate');
    final sealPresent = ProfileData.text(
      trustProfile['corporate_verification_seal'],
    ).isNotEmpty;

    return _employmentVerified(session, trustProfile) &&
        (hasCorporateTrack || sealPresent);
  }

  static int? _preferredLeaseMonths(Map<String, dynamic> session) {
    final raw = session[ApplicantFieldKeys.preferredLeaseMonths];
    if (raw is int) return raw;
    return int.tryParse(ProfileData.text(raw));
  }

  static int? _listingLeaseTermMonths(Map<String, dynamic> listing) {
    final metadata = listing['metadata'];
    if (metadata is! Map) return null;

    final map = Map<String, dynamic>.from(metadata);
    final raw = map['lease_term_months'] ?? map['preferred_lease_months'];
    if (raw is int) return raw;
    return int.tryParse(ProfileData.text(raw));
  }

  static DateTime? _listingTargetMoveInDate(Map<String, dynamic> listing) {
    final metadata = listing['metadata'];
    if (metadata is Map) {
      final map = Map<String, dynamic>.from(metadata);
      for (final key in const [
        'target_move_in_date',
        'available_from',
        'earliest_move_in_date',
      ]) {
        final parsed = _parseDate(ProfileData.text(map[key]));
        if (parsed != null) return parsed;
      }
    }

    return _parseDate(ProfileData.text(listing['available_from']));
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static int? _timelineVarianceDays({
    required DateTime? seekerMoveIn,
    required DateTime? listingTargetMoveIn,
  }) {
    if (seekerMoveIn == null || listingTargetMoveIn == null) return null;
    return seekerMoveIn.difference(listingTargetMoveIn).inDays.abs();
  }

  static bool _moveInTimelineMatch(int? varianceDays) {
    if (varianceDays == null) return false;
    return varianceDays <= ApplicantPayloadSanitizer.moveInWindowDays;
  }

  static bool _leaseTermMatch({
    required int? seekerLeaseMonths,
    required int? listingLeaseMonths,
  }) {
    if (seekerLeaseMonths == null) return false;
    if (listingLeaseMonths == null) return seekerLeaseMonths >= 6;
    return (seekerLeaseMonths - listingLeaseMonths).abs() <= 1;
  }

  static bool _kitchenCultureAligned({
    required String listingKitchenCulture,
    required String seekerFoodPreference,
  }) {
    final listing = listingKitchenCulture.trim().toLowerCase();
    final seeker = seekerFoodPreference.trim().toLowerCase();
    if (listing.isEmpty || listing == 'open') return true;
    if (seeker.isEmpty) return false;

    if (listing == 'veg_friendly' || listing.contains('veg')) {
      return seeker.contains('veg') || seeker.contains('vegetarian');
    }
    if (listing == 'non_veg_friendly' || listing.contains('non')) {
      return seeker.contains('non') ||
          seeker.contains('omnivore') ||
          seeker.contains('flex');
    }
    return true;
  }

  static int _compatibilityScore(Map<String, dynamic> row) {
    return NumericBounds.clampPercentInt(
      row['compatibility_score'] is int
          ? row['compatibility_score'] as int
          : int.tryParse(ProfileData.text(row['compatibility_score'])) ?? 0,
    );
  }

  static DateTime? _createdAt(Map<String, dynamic> row) {
    return DateTime.tryParse(row['created_at']?.toString() ?? '');
  }

  static double _affordabilityMultiplier({
    required Map<String, dynamic> session,
    required ApplicantTrustTier trustTier,
    required Map<String, dynamic> listing,
  }) {
    final explicit = session[ApplicantFieldKeys.affordabilityMultiplier] ??
        session['affordability_multiplier'];
    if (explicit is num && explicit > 0) {
      return (explicit.toDouble() * 10).roundToDouble() / 10;
    }

    final salaryRaw = session['annual_salary'];
    if (salaryRaw is num && salaryRaw > 0) {
      final rent = _listingMonthlyRent(listing);
      if (rent != null && rent > 0) {
        final monthlyGross = salaryRaw / 12;
        return ((monthlyGross / rent) * 10).roundToDouble() / 10;
      }
    }

    return switch (trustTier) {
      ApplicantTrustTier.sound => 3.5,
      ApplicantTrustTier.grand => 3.0,
      ApplicantTrustTier.justLanded => 2.5,
    };
  }

  static double? _listingMonthlyRent(Map<String, dynamic> listing) {
    final price = ProfileData.text(listing['price']);
    if (price.isEmpty) return null;

    final digits = price.replaceAll(RegExp(r'[^\d.]'), '');
    if (digits.isEmpty) return null;

    return double.tryParse(digits);
  }
}
