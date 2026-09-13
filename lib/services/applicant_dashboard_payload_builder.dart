import '../models/applicant_application_status.dart';
import '../models/applicant_field_keys.dart';
import '../models/applicant_profile_metrics.dart';
import '../models/applicant_trust_tier.dart';
import '../models/high_signal_match.dart';
import '../models/independent_places_match_metrics.dart';
import '../models/listing_applicant_dashboard.dart';
import '../models/listing_applicant_record.dart';
import '../models/listing_creation_category.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/shared_living_match_metrics.dart';
import '../utils/listing_data.dart';
import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';
import '../utils/shared_space_compatibility_scorer.dart';
import 'applicant_payload_sanitizer.dart';

/// Maps raw Supabase rows into category-sorted applicant dashboard payloads.
abstract final class ApplicantDashboardPayloadBuilder {
  static ListingApplicantDashboard build({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> applicationRows,
    required Map<String, Map<String, dynamic>> trustProfilesByUserId,
    Map<String, HighSignalMatch> highSignalMatchesByApplicationId = const {},
  }) {
    final listingId = listing['id']?.toString() ?? '';
    final category = _resolveCategory(listing);

    final applicants = <ListingApplicantRecord>[];
    for (final row in applicationRows) {
      final applicationId = row['id']?.toString() ?? '';
      final applicantUserId = row['applicant_user_id']?.toString() ?? '';
      final payload = _payloadMap(row['payload']);
      final trustProfile = trustProfilesByUserId[applicantUserId] ?? const {};
      final mergedSession = ApplicantPayloadSanitizer.sanitizeSession({
        ...payload,
        ..._trustProfileSession(trustProfile),
      });
      final signal = _resolveHighSignalMatch(
        applicationId: applicationId,
        applicantUserId: applicantUserId,
        highSignalMatchesByApplicationId: highSignalMatchesByApplicationId,
      );

      final profileMetrics = _profileMetrics(
        mergedSession,
        trustProfile,
        signal: signal,
      );
      final sharedMatch = category.isShared
          ? _sharedLivingMetrics(
              listing: listing,
              session: mergedSession,
            )
          : null;
      final independentMatch = category.isIndependent
          ? _independentPlacesMetrics(
              listing: listing,
              session: mergedSession,
            )
          : null;

      final compatibilityScore = NumericBounds.clampPercentInt(
        signal?.overallMatchScore ??
            (row['compatibility_score'] is int
                ? row['compatibility_score'] as int
                : int.tryParse(ProfileData.text(row['compatibility_score'])) ??
                    0),
      );

      final sortScore = _dashboardSortScore(
        category: category,
        compatibilityScore: compatibilityScore,
        sharedMatch: sharedMatch,
        independentMatch: independentMatch,
        overallMatchScore: signal?.overallMatchScore,
      );

      applicants.add(
        ListingApplicantRecord(
          applicationId: row['id']?.toString() ?? '',
          listingId: listingId,
          applicantUserId: applicantUserId,
          status: ApplicantApplicationStatus.parseOrDefault(
            row['status']?.toString(),
          ),
          compatibilityScore: compatibilityScore,
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
          seekerName: _seekerName(mergedSession, trustProfile),
          pitchNarrative: _pitchNarrative(mergedSession),
          profileMetrics: profileMetrics,
          dashboardSortScore: sortScore,
          sharedLivingMatch: sharedMatch,
          independentPlacesMatch: independentMatch,
          rawPayload: mergedSession,
        ),
      );
    }

    applicants.sort((a, b) {
      final byScore = b.dashboardSortScore.compareTo(a.dashboardSortScore);
      if (byScore != 0) return byScore;
      return b.createdAt.compareTo(a.createdAt);
    });

    final pendingCount = applicants
        .where((a) => a.status == ApplicantApplicationStatus.pending)
        .length;

    return ListingApplicantDashboard(
      listingId: listingId,
      category: category,
      applicants: applicants,
      totalCount: applicants.length,
      pendingCount: pendingCount,
    );
  }

  static ListingCreationCategory _resolveCategory(
    Map<String, dynamic> listing,
  ) {
    final explicit = ListingCreationCategory.fromStorageToken(
      ProfileData.text(listing[ListingCreationFieldKeys.marketplaceCategory]),
    );
    if (ProfileData.text(listing[ListingCreationFieldKeys.marketplaceCategory])
        .isNotEmpty) {
      return explicit;
    }

    return ListingData.propertyType(listing) == 'Share'
        ? ListingCreationCategory.sharedLiving
        : ListingCreationCategory.independentPlaces;
  }

  static Map<String, dynamic> _payloadMap(dynamic raw) {
    if (raw is Map) {
      return ApplicantPayloadSanitizer.sanitizeSession(
        Map<String, dynamic>.from(raw),
      );
    }
    return const {};
  }

  static Map<String, dynamic> _trustProfileSession(
    Map<String, dynamic> trustProfile,
  ) {
    if (trustProfile.isEmpty) return const {};
    return {
      ApplicantFieldKeys.fullName: trustProfile['full_name'],
      ApplicantFieldKeys.trustTier: trustProfile['trust_tier'],
      ApplicantFieldKeys.employmentVerified: trustProfile['employment_verified'],
      ApplicantFieldKeys.financialVerified: trustProfile['financial_verified'],
      ApplicantFieldKeys.verificationTrack: trustProfile['verification_track'],
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

  static String _pitchNarrative(Map<String, dynamic> session) {
    for (final key in const [
      ApplicantFieldKeys.pitchNarrative,
      ApplicantFieldKeys.personalIntroduction,
      ApplicantFieldKeys.bio,
      ApplicantFieldKeys.aboutMe,
      'introduction',
    ]) {
      final value = ProfileData.text(session[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static ApplicantProfileMetrics _profileMetrics(
    Map<String, dynamic> session,
    Map<String, dynamic> trustProfile, {
    HighSignalMatch? signal,
  }) {
    final merged = {
      ...session,
      if (trustProfile.isNotEmpty) ...{
        if (ProfileData.text(session[ApplicantFieldKeys.trustTier]).isEmpty)
          ApplicantFieldKeys.trustTier: trustProfile['trust_tier'],
        if (session[ApplicantFieldKeys.employmentVerified] != true)
          ApplicantFieldKeys.employmentVerified:
              trustProfile['employment_verified'],
        if (session[ApplicantFieldKeys.financialVerified] != true)
          ApplicantFieldKeys.financialVerified:
              trustProfile['financial_verified'],
        if (session['linkedin_verified'] != true)
          'linkedin_verified': trustProfile['linkedin_verified'],
        if (session['employment_letter_verified'] != true)
          'employment_letter_verified':
              trustProfile['employment_letter_verified'],
        if (session['onboarding_letter_verified'] != true)
          'onboarding_letter_verified':
              trustProfile['onboarding_letter_verified'],
        if (session['light_trust_verified'] != true)
          'light_trust_verified': trustProfile['light_trust_verified'],
        if (ProfileData.text(session['verified_university_email']).isEmpty)
          'verified_university_email':
              trustProfile['verified_university_email'],
        if (ProfileData.text(session['occupant_type']).isEmpty)
          'occupant_type': trustProfile['occupant_type'],
      },
    };

    final completenessRaw = session[ApplicantFieldKeys.profileCompletenessPercent];
    final completeness = completenessRaw is int
        ? completenessRaw
        : int.tryParse(ProfileData.text(completenessRaw)) ?? 0;

    return ApplicantProfileMetrics(
      trustTier: ApplicantTrustTier.fromSession(merged),
      employmentVerified: session[ApplicantFieldKeys.employmentVerified] == true ||
          trustProfile['employment_verified'] == true,
      financialVerified: session[ApplicantFieldKeys.financialVerified] == true ||
          trustProfile['financial_verified'] == true,
      profileCompletenessPercent:
          NumericBounds.clampPercentInt(completeness),
      verificationTrack: _nullableText(
        session[ApplicantFieldKeys.verificationTrack] ??
            trustProfile['verification_track'],
      ),
      overallMatchScore: signal?.overallMatchScore,
      verifiedTransitDurationSeconds: signal?.verifiedTransitDurationSeconds,
    );
  }

  static SharedLivingMatchMetrics _sharedLivingMetrics({
    required Map<String, dynamic> listing,
    required Map<String, dynamic> session,
  }) {
    final seekerLanguages = ApplicantPayloadSanitizer.sanitizeLanguageList(
      session[ApplicantFieldKeys.spokenLanguages],
    );
    final listingLanguages = ApplicantPayloadSanitizer.listingLanguagesFromRow(
      listing,
    );
    final overlap = ApplicantPayloadSanitizer.languageIntersection(
      seekerLanguages,
      listingLanguages,
    );

    final listingKitchen = ProfileData.text(
      listing[ListingCreationFieldKeys.kitchenCulture],
    );
    final seekerFood = ProfileData.text(
      session[ApplicantFieldKeys.foodPreference],
    );
    final kitchenAligned = _kitchenCultureAligned(
      listingKitchenCulture: listingKitchen,
      seekerFoodPreference: seekerFood,
    );

    final languageScore = overlap.isEmpty
        ? 0
        : NumericBounds.clampPercentInt(
            (overlap.length / listingLanguages.length.clamp(1, 99)) * 40,
          );
    final kitchenScore = kitchenAligned ? 35 : 0;
    final scorerScore = SharedSpaceCompatibilityScorer.calculateCompatibility(
      seekerSession: session,
      listing: listing,
    );

    final lifestyleAlignmentScore = NumericBounds.clampPercentInt(
      (languageScore + kitchenScore + (scorerScore * 0.25)).round(),
    );

    return SharedLivingMatchMetrics(
      spokenLanguages: seekerLanguages,
      listingLanguages: listingLanguages,
      languageOverlap: overlap,
      kitchenCultureAligned: kitchenAligned,
      seekerFoodPreference: seekerFood,
      listingKitchenCulture:
          listingKitchen.isEmpty ? null : listingKitchen,
      lifestyleAlignmentScore: lifestyleAlignmentScore,
    );
  }

  static IndependentPlacesMatchMetrics _independentPlacesMetrics({
    required Map<String, dynamic> listing,
    required Map<String, dynamic> session,
  }) {
    final leaseMonths = session[ApplicantFieldKeys.preferredLeaseMonths];
    final preferredLeaseMonths = leaseMonths is int
        ? leaseMonths
        : int.tryParse(ProfileData.text(leaseMonths));

    final budgetMin = _nullableDouble(session[ApplicantFieldKeys.budgetMin]);
    final budgetMax = _nullableDouble(session[ApplicantFieldKeys.budgetMax]);
    final moveInDate = _nullableText(
      session[ApplicantFieldKeys.earliestMoveInDate],
    );

    final listingRent = _listingRent(listing);
    final leaseAlignmentScore = preferredLeaseMonths == null
        ? 10
        : preferredLeaseMonths >= 12
            ? 35
            : preferredLeaseMonths >= 6
                ? 25
                : 15;

    final budgetAlignmentScore = _budgetAlignmentScore(
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      listingRent: listingRent,
    );

    final moveInTimelineScore = moveInDate == null ? 10 : 30;

    final independentMatchScore = NumericBounds.clampPercentInt(
      leaseAlignmentScore + budgetAlignmentScore + moveInTimelineScore,
    );

    return IndependentPlacesMatchMetrics(
      preferredLeaseMonths: preferredLeaseMonths,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      earliestMoveInDate: moveInDate,
      leaseAlignmentScore: leaseAlignmentScore,
      budgetAlignmentScore: budgetAlignmentScore,
      moveInTimelineScore: moveInTimelineScore,
      independentMatchScore: independentMatchScore,
    );
  }

  static int _dashboardSortScore({
    required ListingCreationCategory category,
    required int compatibilityScore,
    required SharedLivingMatchMetrics? sharedMatch,
    required IndependentPlacesMatchMetrics? independentMatch,
    int? overallMatchScore,
  }) {
    if (overallMatchScore != null) {
      return NumericBounds.clampPercentInt(overallMatchScore);
    }

    if (category.isShared) {
      final lifestyle = sharedMatch?.lifestyleAlignmentScore ?? 0;
      return NumericBounds.clampPercentInt(
        ((lifestyle * 0.55 + compatibilityScore * 0.35) / 0.90).round(),
      );
    }

    final independent = independentMatch?.independentMatchScore ?? 0;
    return NumericBounds.clampPercentInt(
      ((independent * 0.50 + compatibilityScore * 0.40) / 0.90).round(),
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

  static int _budgetAlignmentScore({
    required double? budgetMin,
    required double? budgetMax,
    required double listingRent,
  }) {
    if (listingRent <= 0) return 15;
    if (budgetMin == null && budgetMax == null) return 10;

    final ceiling = budgetMax ?? budgetMin ?? 0;
    if (ceiling <= 0) return 10;
    if (listingRent <= ceiling) {
      final headroom = ceiling - listingRent;
      if (headroom >= listingRent * 0.15) return 35;
      return 25;
    }
    return 5;
  }

  static double _listingRent(Map<String, dynamic> listing) {
    final raw = ListingData.price(listing);
    final match = RegExp(r'[\d,.]+').firstMatch(raw);
    if (match == null) return 0;
    return double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
  }

  static String? _nullableText(dynamic value) {
    final parsed = ProfileData.text(value);
    return parsed.isEmpty ? null : parsed;
  }

  static double? _nullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(ProfileData.text(value));
    return parsed;
  }
}
