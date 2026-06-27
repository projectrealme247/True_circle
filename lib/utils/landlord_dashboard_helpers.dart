import '../models/applicant_trust_tier.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/listing_creation_category.dart';
import '../models/listing_creation_field_keys.dart';
import '../models/shared_living_applicant_stream.dart';
import '../utils/full_rental_applicant_scorer.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';

/// Design tokens for the landlord command center.
abstract final class LandlordDashboardTokens {
  static const pageSize = 10;
  static const unselectedGrey = 0xFF9CA3AF;
  static const emeraldHighlight = 0xFF10B981;
  static const magazineQuoteBg = 0xFFF9FAFB;
}

/// Resolved metrics for the metrics ribbon.
class LandlordStreamMetrics {
  const LandlordStreamMetrics({
    required this.activeMatches,
    required this.avgCommuteMinutes,
    required this.vettingClearedPercent,
    required this.soundCount,
    required this.grandCount,
    required this.justLandedCount,
    required this.noiseDeflected,
  });

  final int activeMatches;
  final int avgCommuteMinutes;
  final int vettingClearedPercent;
  final int soundCount;
  final int grandCount;
  final int justLandedCount;
  final int noiseDeflected;

  /// Estimated landlord time saved from noise-filter deflections.
  double get siftingHoursSaved => noiseDeflected / 47.0;
}

abstract final class LandlordDashboardHelpers {
  static ListingCreationCategory categoryForListing(Map<String, dynamic> listing) {
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

  static bool isMockListing(String listingId) =>
      listingId.startsWith('mock-listing-');

  static String listingTitle(Map<String, dynamic> listing) {
    final title = ProfileData.text(listing['title']);
    if (title.isNotEmpty) return title;
    final location = ProfileData.text(listing['location']);
    if (location.isNotEmpty) return location;
    return 'Listing ${listing['id']}';
  }

  static String listingShortLabel(Map<String, dynamic> listing) {
    final category = categoryForListing(listing);
    return category.isShared ? 'Shared' : 'Entire place';
  }

  static int noiseDeflectedCount({
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> rawApplications,
    required int streamCount,
  }) {
    final category = categoryForListing(listing);
    if (category.isShared) {
      return (rawApplications.length - streamCount).clamp(0, 99);
    }
    final sessions = rawApplications
        .map((a) => a['payload'])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return FullRentalApplicantScorer.countHiddenApplicantSessions(
      sessions: sessions,
      listing: listing,
    );
  }

  static String noiseFilterBannerCopy(int deflected) {
    if (deflected <= 0) {
      return 'Silence is golden — zero low-signal profiles bounced by our streams today.';
    }
    if (deflected == 1) {
      return 'Noise Filter spared you 1 unverified ghost. Your inbox stayed suspiciously sane.';
    }
    if (deflected <= 4) {
      return 'Noise Filter politely redirected $deflected low-signal seekers. You\'re welcome.';
    }
    return 'Our backend streams just deflected $deflected noisy profiles. Pop the kettle on — we\'ve got this.';
  }

  static LandlordStreamMetrics metricsFromIndependent({
    required IndependentPlacesApplicantStream stream,
    required int noiseDeflected,
    required Set<String> archivedIds,
  }) {
    final active = stream.flattenedApplicants
        .where((r) => !archivedIds.contains(r.applicationId))
        .toList();
    final tiers = _tierCounts(
      active.map((r) => r.trustTier).toList(),
    );
    return LandlordStreamMetrics(
      activeMatches: active.length,
      avgCommuteMinutes: _avgCommuteMinutesIndependent(active),
      vettingClearedPercent:
          _vettingClearedPercent(tiers, active.length),
      soundCount: tiers[ApplicantTrustTier.sound] ?? 0,
      grandCount: tiers[ApplicantTrustTier.grand] ?? 0,
      justLandedCount: tiers[ApplicantTrustTier.justLanded] ?? 0,
      noiseDeflected: noiseDeflected,
    );
  }

  static LandlordStreamMetrics metricsFromShared({
    required SharedLivingApplicantStream stream,
    required int noiseDeflected,
    required Set<String> archivedIds,
  }) {
    final active = stream.flattenedApplicants
        .where((r) => !archivedIds.contains(r.applicationId))
        .toList();
    final tiers = _tierCounts(
      active.map((r) => r.trustTier).toList(),
    );
    return LandlordStreamMetrics(
      activeMatches: active.length,
      avgCommuteMinutes: _avgCommuteMinutesShared(active),
      vettingClearedPercent:
          _vettingClearedPercent(tiers, active.length),
      soundCount: tiers[ApplicantTrustTier.sound] ?? 0,
      grandCount: tiers[ApplicantTrustTier.grand] ?? 0,
      justLandedCount: tiers[ApplicantTrustTier.justLanded] ?? 0,
      noiseDeflected: noiseDeflected,
    );
  }

  static Map<ApplicantTrustTier, int> _tierCounts(List<ApplicantTrustTier> tiers) {
    final counts = {
      for (final tier in ApplicantTrustTier.values) tier: 0,
    };
    for (final tier in tiers) {
      counts[tier] = (counts[tier] ?? 0) + 1;
    }
    return counts;
  }

  static int _vettingClearedPercent(
    Map<ApplicantTrustTier, int> tiers,
    int total,
  ) {
    if (total == 0) return 0;
    final cleared =
        (tiers[ApplicantTrustTier.sound] ?? 0) +
        (tiers[ApplicantTrustTier.grand] ?? 0);
    return ((cleared / total) * 100).round();
  }

  static int _avgCommuteMinutesShared(List<SharedLivingApplicantRow> rows) {
    final seconds = rows
        .map((r) => r.verifiedTransitDurationSeconds)
        .whereType<int>()
        .where((s) => s > 0)
        .toList();
    if (seconds.isEmpty) return 0;
    final avg = seconds.reduce((a, b) => a + b) / seconds.length;
    return (avg / 60).round().clamp(1, 999);
  }

  static int _avgCommuteMinutesIndependent(
    List<IndependentPlacesApplicantRow> rows,
  ) {
    final seconds = rows
        .map((r) => r.verifiedTransitDurationSeconds)
        .whereType<int>()
        .where((s) => s > 0)
        .toList();
    if (seconds.isEmpty) return 0;
    final avg = seconds.reduce((a, b) => a + b) / seconds.length;
    return (avg / 60).round().clamp(1, 999);
  }

  static String trustTierEmoji(ApplicantTrustTier tier) => switch (tier) {
        ApplicantTrustTier.sound => '🤝',
        ApplicantTrustTier.grand => '👍',
        ApplicantTrustTier.justLanded => '✈️',
      };
}
