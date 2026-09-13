import '../models/applicant_application_status.dart';
import '../models/applicant_field_keys.dart';
import '../models/applicant_trust_tier.dart';
import '../models/applicant_trust_tier_block.dart';
import '../models/high_signal_match.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/move_in_timing.dart';
import '../models/shared_living_applicant_stream.dart';
import '../utils/landlord_decision_summary_builder.dart';
import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';
import '../utils/shared_space_compatibility_scorer.dart';
import 'applicant_management_supabase_service.dart';
import 'applicant_payload_sanitizer.dart';

/// Builds category-specific applicant stream payloads ordered by match score.
abstract final class ApplicantStreamPayloadBuilder {
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
    final applicants = <IndependentPlacesApplicantRow>[];

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
      final timing = MoveInTimingEngine.evaluate(
        seekerSession: session,
        listing: listing,
      );
      final varianceDays = _timelineVarianceDays(
        seekerMoveIn: earliestMoveIn,
        listingTargetMoveIn: listingTargetMoveIn,
      );
      final moveInMatch = timing.quality.earnsTimingScore ||
          _moveInTimelineMatch(varianceDays);

      final localCompatibility = _compatibilityScore(row);
      final displayScore = signal?.overallMatchScore ?? localCompatibility;
      final employmentVerified = _employmentVerified(session, trustProfile);
      final corporateVerified = _corporateDocumentVerified(
        session,
        trustProfile,
      );
      final affordability = _affordabilityMultiplier(
        session: session,
        trustTier: trustTier,
        listing: listing,
      );
      final commuteLabel = _commuteLabel(signal?.verifiedTransitDurationSeconds);
      final decision = LandlordDecisionSummaryBuilder.fromSession(
        session: session,
        listing: listing,
        isSharedLiving: false,
        trustTier: trustTier,
        leaseTermMatch: _leaseTermMatch(
          seekerLeaseMonths: preferredLeaseMonths,
          listingLeaseMonths: listingLeaseMonths,
        ),
        preferredLeaseMonths: preferredLeaseMonths,
        employmentVerified: employmentVerified,
        financialVerified: session[ApplicantFieldKeys.financialVerified] ==
                true ||
            trustProfile['financial_verified'] == true,
        commuteLabel: commuteLabel,
      );

      applicants.add(
        IndependentPlacesApplicantRow(
          applicationId: applicationId,
          listingId: listingId,
          applicantUserId: applicantUserId,
          seekerName: _seekerName(session, trustProfile),
          status: ApplicantApplicationStatus.parseOrDefault(
            row['status']?.toString(),
          ),
          trustTier: trustTier,
          moveInTimelineMatch: moveInMatch,
          leaseTermMatch: _leaseTermMatch(
            seekerLeaseMonths: preferredLeaseMonths,
            listingLeaseMonths: listingLeaseMonths,
          ),
          employmentVerified: employmentVerified,
          corporateDocumentVerified: corporateVerified,
          timelineVarianceDays: varianceDays,
          preferredLeaseMonths: preferredLeaseMonths,
          earliestMoveInDate: earliestMoveIn?.toIso8601String().split('T').first,
          compatibilityScore: displayScore,
          overallMatchScore: signal?.overallMatchScore,
          verifiedTransitDurationSeconds:
              signal?.verifiedTransitDurationSeconds,
          affordabilityMultiplier: affordability,
          decision: decision,
          createdAt: _createdAt(row),
        ),
      );
    }

    applicants.sort((a, b) {
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

    final blocks = applicants.isEmpty
        ? <ApplicantTrustTierBlock<IndependentPlacesApplicantRow>>[]
        : [
            ApplicantTrustTierBlock(
              trustTier: applicants.first.trustTier,
              applicants: applicants,
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
    final applicants = <SharedLivingApplicantRow>[];

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
      final affordability = _affordabilityMultiplier(
        session: session,
        trustTier: trustTier,
        listing: listing,
      );
      final commuteLabel = _commuteLabel(signal?.verifiedTransitDurationSeconds);
      final decision = LandlordDecisionSummaryBuilder.fromSession(
        session: session,
        listing: listing,
        isSharedLiving: true,
        trustTier: trustTier,
        lifestyleMatchPercent: displayScore,
        languageOverlap: overlap,
        kitchenCultureAligned: kitchenAligned,
        employmentVerified: _employmentVerified(session, trustProfile),
        financialVerified: session[ApplicantFieldKeys.financialVerified] ==
                true ||
            trustProfile['financial_verified'] == true,
        commuteLabel: commuteLabel,
      );

      applicants.add(
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
          affordabilityMultiplier: affordability,
          decision: decision,
          createdAt: _createdAt(row),
        ),
      );
    }

    applicants.sort((a, b) {
      final scoreA = a.overallMatchScore ?? a.lifestyleMatchScorePercent;
      final scoreB = b.overallMatchScore ?? b.lifestyleMatchScorePercent;
      return scoreB.compareTo(scoreA);
    });

    final blocks = applicants.isEmpty
        ? <ApplicantTrustTierBlock<SharedLivingApplicantRow>>[]
        : [
            ApplicantTrustTierBlock(
              trustTier: applicants.first.trustTier,
              applicants: applicants,
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
      ApplicantFieldKeys.employmentVerified: trustProfile['employment_verified'],
      ApplicantFieldKeys.financialVerified: trustProfile['financial_verified'],
      ApplicantFieldKeys.verificationTrack: trustProfile['verification_track'],
    };
  }

  static ApplicantTrustTier _trustTier(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile,
  ) {
    return ApplicantTrustTier.fromSession(_sessionWithTrustProfile(
      session,
      trustProfile,
    ));
  }

  static Map<String, dynamic> _sessionWithTrustProfile(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile,
  ) {
    if (trustProfile.isEmpty) return session;
    return {
      ...session,
      if (ProfileData.text(session[ApplicantFieldKeys.trustTier]).isEmpty)
        ApplicantFieldKeys.trustTier: trustProfile['trust_tier'],
      if (session[ApplicantFieldKeys.employmentVerified] != true)
        ApplicantFieldKeys.employmentVerified: trustProfile['employment_verified'],
      if (session[ApplicantFieldKeys.financialVerified] != true)
        ApplicantFieldKeys.financialVerified: trustProfile['financial_verified'],
      if (session['linkedin_verified'] != true)
        'linkedin_verified': trustProfile['linkedin_verified'],
      if (session['employment_letter_verified'] != true)
        'employment_letter_verified': trustProfile['employment_letter_verified'],
      if (session['onboarding_letter_verified'] != true)
        'onboarding_letter_verified': trustProfile['onboarding_letter_verified'],
      if (session['light_trust_verified'] != true)
        'light_trust_verified': trustProfile['light_trust_verified'],
      if (ProfileData.text(session['verified_university_email']).isEmpty)
        'verified_university_email': trustProfile['verified_university_email'],
      if (ProfileData.text(session['occupant_type']).isEmpty)
        'occupant_type': trustProfile['occupant_type'],
    };
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
    return LandlordDecisionSummaryBuilder.fromSession(
      session: session,
      listing: listing,
      isSharedLiving: false,
      trustTier: trustTier,
    ).affordabilityMultiplier;
  }

  static String? _commuteLabel(int? transitSeconds) {
    if (transitSeconds == null || transitSeconds <= 0) return null;
    final minutes = (transitSeconds / 60).round();
    return '$minutes min commute';
  }
}
