import 'package:flutter/foundation.dart';

import '../debug/agent_log.dart';
import '../debug/debug_session_log.dart';

import '../models/move_in_timing.dart';
import '../theme/trust_tier_design.dart';
import 'listing_data.dart';
import 'listing_search_intent.dart';
import 'viewer_profile.dart';

import '../services/commute_scoring_service.dart';
import 'commute_profile.dart';
import 'profile_data.dart';
import 'student_track_preference.dart';
import 'weighted_listing_matcher.dart';

enum MatchTower { rent, buy, share }

/// Result of tower-specific match scoring for one listing.
class ListingMatchResult {
  const ListingMatchResult({
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.label,
    required this.reasons,
    required this.excluded,
    required this.tower,
    this.trustStage = TrustStage.casual,
    this.inCircle = false,
    this.preArrivalBadge = false,
  });

  final int score;
  final int maxScore;
  final double percentage;
  final String label;
  final List<String> reasons;
  final bool excluded;
  final MatchTower tower;
  final TrustStage trustStage;
  final bool inCircle;
  final bool preArrivalBadge;

  static const noProfile = ListingMatchResult(
    score: 0,
    maxScore: 1,
    percentage: 0,
    label: '',
    reasons: const [],
    excluded: false,
    tower: MatchTower.rent,
  );

  static const onboardingRequired = ListingMatchResult(
    score: 0,
    maxScore: 1,
    percentage: 0,
    label: 'Onboarding Required',
    reasons: const [],
    excluded: false,
    tower: MatchTower.rent,
  );
}

class ScoredListing {
  const ScoredListing({
    required this.listing,
    required this.match,
    this.preferenceScore = 100.0,
  });

  final Map<String, dynamic> listing;
  final ListingMatchResult match;
  final double preferenceScore;
}
class ListingRankOutcome {
  const ListingRankOutcome({
    required this.ranked,
    this.isCommuteDivergent = false,
    this.requiresOnboarding = false,
  });
  final List<ScoredListing> ranked;
  final bool isCommuteDivergent;
  final bool requiresOnboarding;
}

/// Hard filters + tower scoring + trust multiplier + circle ranking.
///
/// Final Score = TrustMultiplier x CompatibilityScore
abstract final class ListingMatchEngine {
  static const rentMaxScore = 100;
  static const buyMaxScore = 175;
  static const shareMaxScore = 100;

  static const _rentPetSmokingSoftPenalty = 15;

  static const _shareBudgetHardCapRatio =
      WeightedListingMatcher.budgetHardCapRatio;
  static const _shareBudgetStretchStartRatio =
      WeightedListingMatcher.budgetStretchStartRatio;

  /// Minimum compatibility (0.0–1.0) required to surface the In Your Circle badge.
  static const inCircleMinMatchFraction = 0.75;

  static bool qualifiesForInCircle({
    required bool networkConnected,
    required double matchPercentage,
  }) {
    final matchScore = matchPercentage / 100.0;
    return networkConnected && matchScore >= inCircleMinMatchFraction;
  }

  // ΓöÇΓöÇ Public API ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static ListingRankOutcome rank(
    List<Map<String, dynamic>> listings,
    Map<String, dynamic>? viewerSession, {
    SearchIntent? searchIntent,
    SearchIntent? appliedSearchIntent,
    bool filtersWereRelaxed = false,
    WeightedFilterCriteria? weightedCriteria,
  }) {
    final viewer = ViewerProfile.fromSession(viewerSession);
    if (viewer?.needsOnboarding == true) {
      // #region agent log
      agentLog(
        'A',
        'listing_match_engine.dart:rank',
        'skip ranking — needs onboarding',
        {
          'sessionKeyCount': viewerSession?.keys.length ?? 0,
          'hasDetectedCity':
              (viewerSession?['detected_city']?.toString() ?? '').isNotEmpty,
          'hasBudgetMax':
              (viewerSession?['budget_max']?.toString() ?? '').isNotEmpty,
        },
      );
      // #endregion
      return const ListingRankOutcome(
        ranked: [],
        requiresOnboarding: true,
      );
    }

    final scored = <ScoredListing>[];
    var excludedCount = 0;

    for (final listing in listings) {
      final match = evaluate(
        listing,
        viewer,
        viewerSession: viewerSession,
        searchIntent: searchIntent,
        appliedSearchIntent: appliedSearchIntent,
        filtersWereRelaxed: filtersWereRelaxed,
      );
      if (match.excluded) {
        excludedCount++;
      }
      if (!match.excluded) {
        final preferenceScore = weightedCriteria != null
            ? WeightedListingMatcher.computePreferenceScore(
                listing,
                weightedCriteria,
              )
            : 100.0;
        scored.add(ScoredListing(
          listing: listing,
          match: match,
          preferenceScore: preferenceScore,
        ));
      }
    }

    // #region agent log
    if (listings.isNotEmpty) {
      debugSessionLog(
        location: 'listing_match_engine.dart:rank',
        message: 'rank pool outcome',
        hypothesisId: 'B,C',
        data: {
          'inputPool': listings.length,
          'excluded': excludedCount,
          'scored': scored.length,
          'viewerOccupant': viewer?.occupantType,
          'isFamily': isFamilyOccupant(viewer),
        },
      );
    }
    // #endregion

    if (scored.isEmpty &&
        listings.isNotEmpty &&
        !_allShareListingsBlockedForFamily(viewer, listings)) {
      for (final listing in listings) {
        final match = evaluate(
          listing,
          viewer,
          viewerSession: viewerSession,
          searchIntent: searchIntent,
          appliedSearchIntent: appliedSearchIntent,
          filtersWereRelaxed: filtersWereRelaxed,
          skipProfileHardFilters: true,
        );
        if (!match.excluded) {
          final preferenceScore = weightedCriteria != null
              ? WeightedListingMatcher.computePreferenceScore(
                  listing,
                  weightedCriteria,
                )
              : 100.0;
          scored.add(ScoredListing(
            listing: listing,
            match: match,
            preferenceScore: preferenceScore,
          ));
        }
      }
    }

    // Priority ranking:
    // 1. Weighted lifestyle preference score (when active soft filters exist)
    // 2. Circle listings → highest quality first
    // 3. High-match (>= 50%) → sorted by score descending
    // 4. Medium-match (25-49%) → sorted by score descending
    // 5. Low-match (< 25%) → pushed to end
    final usesWeightedSort = weightedCriteria != null &&
        _weightedCriteriaHasSoftFilters(weightedCriteria);
    scored.sort((a, b) {
      if (usesWeightedSort) {
        final pref = b.preferenceScore.compareTo(a.preferenceScore);
        if (pref != 0) return pref;
      }

      final aCircle = a.match.inCircle ? 1 : 0;
      final bCircle = b.match.inCircle ? 1 : 0;
      if (aCircle != bCircle) return bCircle - aCircle;

      final aTier = _qualityTier(a.match);
      final bTier = _qualityTier(b.match);
      if (aTier != bTier) return bTier - aTier;

      return b.match.score.compareTo(a.match.score);
    });

    return ListingRankOutcome(
      ranked: scored,
      isCommuteDivergent: _isCommuteDivergent(viewerSession),
    );
  }

  static bool _weightedCriteriaHasSoftFilters(WeightedFilterCriteria criteria) {
    return criteria.requiresWfh ||
        criteria.requiresVeg ||
        criteria.requiresNonVeg ||
        criteria.preferredRoomType != null ||
        criteria.preferredOccupant != null ||
        criteria.preferredGender != null ||
        criteria.maxBudget != null;
  }

  static bool _isCommuteDivergent(Map<String, dynamic>? viewerSession) {
    if (viewerSession == null) return false;
    final budget = ProfileData.maximumCommuteBudgetMinutes(viewerSession);
    if (budget == null) return false;
    final profiles = CommuteProfileRegistry.fromSession(viewerSession);
    return CommuteProfileRegistry.hubsAreDivergent(profiles);
  }

  static int _qualityTier(ListingMatchResult m) {
    if (m.percentage >= 50) return 2;
    if (m.percentage >= 25) return 1;
    return 0;
  }

  static ListingMatchResult evaluate(
    Map<String, dynamic> listing,
    ViewerProfile? viewer, {
    SearchIntent? searchIntent,
    SearchIntent? appliedSearchIntent,
    bool filtersWereRelaxed = false,
    bool skipProfileHardFilters = false,
    Map<String, dynamic>? viewerSession,
  }) {
    if (viewer?.needsOnboarding == true) {
      return ListingMatchResult.onboardingRequired;
    }

    final tower = _towerFor(listing);

    if (tower == MatchTower.share &&
        viewer != null &&
        _isFamilyOccupant(viewer)) {
      return ListingMatchResult(
        score: 0,
        maxScore: _maxFor(tower),
        percentage: 0,
        label: '',
        reasons: const [],
        excluded: true,
        tower: tower,
      );
    }

    final hasSearch = searchIntent != null && searchIntent.hasStructuredFilters;
    final skipHard = skipProfileHardFilters || hasSearch;

    if (viewer != null && _studentTrackConflict(viewer, listing)) {
      return ListingMatchResult(
        score: 0,
        maxScore: _maxFor(tower),
        percentage: 0,
        label: '⚠️ Less relevant',
        reasons: const [],
        excluded: true,
        tower: tower,
      );
    }


    if (viewer != null &&
        !skipHard &&
        _failsHardFilter(listing, viewer, tower)) {
      return ListingMatchResult(
        score: 0,
        maxScore: _maxFor(tower),
        percentage: 0,
        label: '⚠️ Less relevant',
        reasons: const [],
        excluded: true,
        tower: tower,
      );
    }

    final flags = viewer != null
        ? _MatchFlags.build(listing, viewer, viewerSession: viewerSession)
        : _MatchFlags.empty();
    final searchFlags = hasSearch
        ? _SearchMatchFlags.fromIntent(
            listing,
            searchIntent,
            applied: appliedSearchIntent ?? searchIntent,
            filtersWereRelaxed: filtersWereRelaxed,
          )
        : _SearchMatchFlags.empty();

    final weights = _ScoringWeights.fromSearchIntent(searchIntent);
    final compatibilityScore = switch (tower) {
      MatchTower.rent => _scoreRent(flags, viewer, listing, searchFlags, weights, viewerSession),
      MatchTower.buy => _scoreBuy(flags, viewer, listing, searchFlags, weights),
      MatchTower.share => _scoreShare(
          flags,
          viewer,
          listing,
          searchFlags,
          weights,
          viewerSession,
        ),
    };

    // Trust multiplier: average host + seeker (avoids compounding two penalties).
    final hostTrust = TrustStage.fromLevel(ListingData.hostTrustStage(listing));
    final trustMult = hostTrust.multiplier;
    final seekerMult = viewer == null
        ? 1.0
        : TrustTierDesign.effectiveSeekerTrustMultiplier(
            baseStage: viewer.trustStage,
            hasVerifiedPreArrivalDocs: viewer.hasVerifiedPreArrivalDocs,
          );
    final combinedTrustMult = (trustMult + seekerMult) / 2;
    final finalScoreBeforeArrival =
        (combinedTrustMult * compatibilityScore).round();
    final finalScore = (finalScoreBeforeArrival *
            _preArrivalScoreMultiplier(viewer, listing))
        .round();

    final max = hasSearch && viewer == null
        ? _searchOnlyMax(tower)
        : _maxFor(tower);
    final pct = max > 0 ? ((finalScore / max) * 100).clamp(0, 100) : 0.0;

    final networkInCircle = viewer?.isInCircle(listing) ?? false;
    final inCircle = qualifiesForInCircle(
      networkConnected: networkInCircle,
      matchPercentage: pct.toDouble(),
    );

    final reasons = _combinedReasons(
      flags,
      searchFlags,
      tower,
      hostTrust: hostTrust,
      inCircle: inCircle,
      maxReasons: 4,
      viewer: viewer,
      hasPreArrivalTrustUpgrade: viewer != null &&
          TrustTierDesign.hasPreArrivalTrustUpgrade(
            baseStage: viewer.trustStage,
            hasVerifiedPreArrivalDocs: viewer.hasVerifiedPreArrivalDocs,
          ),
    );

    return ListingMatchResult(
      score: finalScore,
      maxScore: max,
      percentage: pct.toDouble(),
      label: finalScore > 0 ? _labelFor(pct.toDouble()) : '',
      reasons: reasons,
      excluded: false,
      tower: tower,
      trustStage: hostTrust,
      inCircle: inCircle,
    );
  }

  // ΓöÇΓöÇ Debug logging ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static int _searchOnlyMax(MatchTower tower) => switch (tower) {
        MatchTower.rent => 120,
        MatchTower.buy => 100,
        MatchTower.share => 130,
      };

  static void debugLogRanked(
    List<ScoredListing> ranked,
    ViewerProfile? viewer,
  ) {
    debugPrint('--- Listing match ranking ---');
    if (viewer == null) {
      debugPrint('No viewer profile ΓÇö original order, no scoring.');
      debugPrint('--- end ranking ---');
      return;
    }
    for (var i = 0; i < ranked.length; i++) {
      final s = ranked[i];
      final title = ListingData.title(s.listing);
      final m = s.match;
      debugPrint(
        '#${i + 1} $title ΓåÆ ${m.score}/${m.maxScore} '
        '(${m.percentage.round()}%) ${m.label} '
        'trust: ${m.trustStage.label} '
        'circle: ${m.inCircle} '
        'reasons: ${m.reasons.join(' ΓÇó ')}',
      );
    }
    debugPrint('--- end ranking ---');
  }

  // ΓöÇΓöÇ Tower classification ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static MatchTower _towerFor(Map<String, dynamic> listing) {
    return switch (ListingData.propertyType(listing)) {
      'Buy' => MatchTower.buy,
      'Share' => MatchTower.share,
      _ => MatchTower.rent,
    };
  }

  static int _maxFor(MatchTower tower) => switch (tower) {
        MatchTower.rent => rentMaxScore,
        MatchTower.buy => buyMaxScore,
        MatchTower.share => shareMaxScore,
      };

  static String _labelFor(double percentage) {
    if (percentage >= 65) return '≡ƒöÑ Perfect match';
    if (percentage >= 50) return 'Γ£à Strong match';
    if (percentage >= 30) return '≡ƒæì Good match';
    return 'ΓÜá∩╕Å Less relevant';
  }

  // ΓöÇΓöÇ Hard filters ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static bool _failsHardFilter(
    Map<String, dynamic> listing,
    ViewerProfile viewer,
    MatchTower tower,
  ) {
    return switch (tower) {
      MatchTower.rent => _rentHardFilter(listing, viewer),
      MatchTower.buy => _buyHardFilter(listing, viewer),
      MatchTower.share => _shareHardFilter(listing, viewer),
    };
  }

  static bool _rentHardFilter(Map<String, dynamic> listing, ViewerProfile viewer) {
    // Independent Places: occupant, gender, and student type are ranking signals only.
    return false;
  }

  static bool _buyHardFilter(Map<String, dynamic> listing, ViewerProfile viewer) {
    final price = _parsePrice(ListingData.price(listing));
    if (price != null) {
      if (viewer.budgetMin != null && price < viewer.budgetMin!) return true;
      if (viewer.budgetMax != null && price > viewer.budgetMax!) return true;
    }
    final preferred = viewer.preferredPropertyType;
    if (preferred.isNotEmpty && preferred != 'Buy') return true;
    return false;
  }

  static bool _shareHardFilter(Map<String, dynamic> listing, ViewerProfile viewer) {
    if (_genderMismatch(viewer.genderPreference, ListingData.bachelorPreference(listing))) {
      return true;
    }
    if (_sharePetSmokingHardExclude(viewer, listing)) return true;
    return false;
  }

  static bool _sharePetSmokingHardExclude(
    ViewerProfile viewer,
    Map<String, dynamic> listing,
  ) {
    if (_listingExplicitlyDisallowsSmoking(listing) && viewer.smokingOk) {
      return true;
    }
    if (_listingExplicitlyDisallowsPets(listing) && viewer.householdHasPets) {
      return true;
    }
    return false;
  }

  static bool _listingExplicitlyDisallowsSmoking(Map<String, dynamic> listing) {
    if (ListingData.lifestyleFlags(listing).contains('no_smoking')) {
      return true;
    }
    return listing.containsKey('smoking_allowed') &&
        listing['smoking_allowed'] != true;
  }

  static bool _listingExplicitlyDisallowsPets(Map<String, dynamic> listing) {
    if (ListingData.lifestyleFlags(listing).contains('no_pets')) {
      return true;
    }
    return listing.containsKey('pets_allowed') && listing['pets_allowed'] != true;
  }

  static double _shareBudgetFitFraction(int? price, ViewerProfile? viewer) {
    if (price == null || viewer?.budgetMax == null) return 0;
    final max = viewer!.budgetMax!;
    if (price <= max) return 1.0;
    final stretchStart = (max * _shareBudgetStretchStartRatio).round();
    if (price <= stretchStart) return 0.6;
    final hardCap = (max * _shareBudgetHardCapRatio).round();
    if (price <= hardCap) return 0.25;
    return 0;
  }

  static double _rentBudgetFitFraction(int? price, ViewerProfile? viewer) {
    if (price == null || viewer?.budgetMax == null) return 0;
    final max = viewer!.budgetMax!;
    if (price <= max) return 1.0;
    final stretchStart = (max * _shareBudgetStretchStartRatio).round();
    if (price <= stretchStart) return 0.5;
    final hardCap = (max * _shareBudgetHardCapRatio).round();
    if (price <= hardCap) return 0.2;
    return 0;
  }

  static bool _shareBudgetSoftOver(int? price, ViewerProfile viewer) {
    if (price == null || viewer.budgetMax == null) return false;
    final stretchStart = (viewer.budgetMax! * _shareBudgetStretchStartRatio).round();
    final hardCap = (viewer.budgetMax! * _shareBudgetHardCapRatio).round();
    return price > stretchStart && price <= hardCap;
  }

  static Map<String, dynamic> _seekerTimingSession(ViewerProfile viewer) => {
        if (viewer.moveInWindow.isNotEmpty) 'move_in_window': viewer.moveInWindow,
        if (viewer.earliestMoveInDate.isNotEmpty)
          'earliest_move_in_date': viewer.earliestMoveInDate,
      };

  static TimingMatchEvaluation _evaluateTiming(
    ViewerProfile viewer,
    Map<String, dynamic> listing,
  ) {
    return MoveInTimingEngine.evaluate(
      seekerSession: _seekerTimingSession(viewer),
      listing: listing,
    );
  }

  static bool _timingMatch(ViewerProfile viewer, Map<String, dynamic> listing) {
    final hasScheduleSignal = viewer.scheduleType.isNotEmpty ||
        ListingData.scheduleType(listing).isNotEmpty;
    final hasMoveInSignal =
        viewer.moveInWindow.isNotEmpty ||
        viewer.earliestMoveInDate.isNotEmpty ||
        ProfileData.text(listing['available_from']).isNotEmpty;

    if (!hasScheduleSignal && !hasMoveInSignal) return false;

    final scheduleOk = _scheduleCompatible(viewer, listing);
    if (!hasMoveInSignal) return scheduleOk;

    final eval = _evaluateTiming(viewer, listing);
    final moveInOk = eval.earnsTimingScore;
    if (hasScheduleSignal && hasMoveInSignal) return scheduleOk && moveInOk;
    return moveInOk;
  }

  static bool _timingMismatch(ViewerProfile viewer, Map<String, dynamic> listing) {
    final hasScheduleSignal = viewer.scheduleType.isNotEmpty ||
        ListingData.scheduleType(listing).isNotEmpty;
    final hasMoveInSignal =
        viewer.moveInWindow.isNotEmpty ||
        viewer.earliestMoveInDate.isNotEmpty ||
        ProfileData.text(listing['available_from']).isNotEmpty;
    if (!hasScheduleSignal && !hasMoveInSignal) return false;

    final eval = _evaluateTiming(viewer, listing);
    return eval.quality == TimingMatchQuality.weak;
  }

  static bool _studentTrackConflict(
    ViewerProfile viewer,
    Map<String, dynamic> listing,
  ) {
    if (!viewer.isPreArrivalSeeker) return false;
    return ListingData.tenantTrackPreference(listing) ==
        StudentTrackPreference.onCampusOnly;
  }

  static double _preArrivalScoreMultiplier(
    ViewerProfile? viewer,
    Map<String, dynamic> listing,
  ) {
    if (viewer == null || !viewer.isPreArrivalSeeker) return 1.0;
    if (ListingData.tenantTrackPreference(listing) ==
        StudentTrackPreference.allStudents) {
      return 0.9;
    }
    return 1.0;
  }

  static int _commuteOverBudgetPenalty(
    Map<String, dynamic>? viewerSession,
    Map<String, dynamic> listing,
  ) {
    final property = ListingData.listingCoordinates(listing);
    if (property == null) return 0;

    final profiles = CommuteProfileRegistry.fromSession(viewerSession);
    if (profiles.length >= 2) {
      final payload = CommuteScoringService.calculateMultiCommuteMinutes(
        propertyLoc: property,
        profiles: profiles,
        parkingAvailable: ListingData.parkingAvailable(listing),
        dualCommutePriority: ListingData.dualCommutePriority(viewerSession),
        budgetForProfile: (profile, index) =>
            ListingData.commuteBudgetMinutesForProfile(profile, viewerSession),
      );
      final combined = payload.combinedCompatibilityScore;
      if (combined != null) {
        return (100.0 - combined).round().clamp(0, 100);
      }
    }

    final budget = ProfileData.maximumCommuteBudgetMinutes(viewerSession);
    if (budget == null) return 0;
    final minutes =
        ProfileData.commuteMinutesFromListing(viewerSession, property);
    if (minutes == null) return 0;
    return CommuteScoringService.overBudgetScorePenalty(
      doorToDoorMinutes: minutes,
      budgetMinutes: budget,
    );
  }

  static bool isFamilyOccupant(ViewerProfile? viewer) {
    if (viewer == null) return false;
    return _isFamilyOccupant(viewer);
  }

  static bool _isFamilyOccupant(ViewerProfile viewer) {
    final occ = viewer.occupantType.toLowerCase();
    return occ.contains('family');
  }

  static bool _allShareListingsBlockedForFamily(
    ViewerProfile? viewer,
    List<Map<String, dynamic>> listings,
  ) {
    if (!isFamilyOccupant(viewer)) return false;
    return listings.every(
      (listing) => _towerFor(listing) == MatchTower.share,
    );
  }

  static bool _occupantMismatch(String viewerOccupant, String listingOccupant) {
    if (viewerOccupant.isEmpty || listingOccupant.isEmpty) return false;
    return !ListingData.matchesOccupantType(
      {'occupantType': listingOccupant},
      viewerOccupant,
    );
  }

  static bool _studentMismatch(String viewerStudent, String listingStudent) {
    if (viewerStudent.isEmpty || listingStudent.isEmpty) return false;
    return viewerStudent.toLowerCase() != listingStudent.toLowerCase();
  }

  static bool _genderMismatch(String viewerGender, String listingBachelorPref) {
    if (viewerGender.isEmpty || listingBachelorPref.isEmpty) return false;
    final g = viewerGender.toLowerCase();
    final pref = listingBachelorPref.toLowerCase();
    if (pref.contains('boys & girls') || pref.contains('mixed')) return false;
    if (pref.contains('boys only') && (g.contains('female') || g.contains('girl'))) {
      return true;
    }
    if (pref.contains('girls only') && (g.contains('male') || g.contains('boy'))) {
      return true;
    }
    return false;
  }

  static bool _lifestyleConflict(ViewerProfile viewer, Map<String, dynamic> listing) {
    final viewerFood = _normFood(viewer.foodPreference);
    final hostFood = _normFood(ListingData.hostFoodPreference(listing));
    if (viewerFood.isNotEmpty &&
        hostFood.isNotEmpty &&
        viewerFood != hostFood) {
      return true;
    }
    final lifestyle = ListingData.lifestylePreferences(listing).map((e) => e.toLowerCase()).toSet();
    if (viewerFood == 'veg' && lifestyle.contains('non-veg')) return true;
    return false;
  }


  static bool _lifestyleFlagConflict(
    ViewerProfile viewer,
    Map<String, dynamic> listing,
  ) {
    final flags = ListingData.lifestyleFlags(listing);
    if (flags.contains('no_smoking') && viewer.smokingOk) return true;
    if (flags.contains('no_pets') && viewer.householdHasPets) return true;
    if (flags.contains('vegetarian_household')) {
      final viewerFood = _normFood(viewer.foodPreference);
      if (viewerFood == 'non-veg') return true;
    }
    return false;
  }

  static bool _quietHoursAligned(ViewerProfile? viewer, Map<String, dynamic> listing) {
    if (viewer == null) return false;
    final flags = ListingData.lifestyleFlags(listing);
    if (!flags.contains('quiet_hours_preferred')) return false;
    final schedule = viewer.scheduleType.toLowerCase();
    if (schedule.isEmpty || schedule == 'flexible') return true;
    return schedule.contains('day');
  }
  static bool _smokingDrinkingConflict(ViewerProfile viewer, Map<String, dynamic> listing) {
    final viewerFood = _normFood(viewer.foodPreference);
    if (viewerFood == 'veg') {
      if (ListingData.smokingAllowed(listing)) return true;
      if (ListingData.drinkingAllowed(listing)) return true;
    }
    return false;
  }

  // ΓöÇΓöÇ Scoring per tower (REFINED WEIGHTS, no company/profile-completeness) ΓöÇΓöÇ

  static int _scoreRent(
    _MatchFlags f,
    ViewerProfile? viewer,
    Map<String, dynamic> listing,
    _SearchMatchFlags search,
    _ScoringWeights w,
    Map<String, dynamic>? viewerSession,
  ) {
    final weights = _RentTowerWeights.forViewer(viewer);
    final price = _parsePrice(ListingData.price(listing));
    var score = 0.0;

    score += weights.budget *
        (f.priceFit ? 1.0 : _rentBudgetFitFraction(price, viewer));

    if (f.bhkMatch) score += weights.bedCount;

    score += weights.locationCommute *
        _rentLocationCommuteFraction(f, search, viewerSession, listing);

    if (f.timingMatch) score += weights.timing;
    if (f.languageMatch) score += weights.language;

    score += weights.lifestyle * _rentLifestyleFraction(f, search);

    if (viewer != null && _rentPetSmokingMismatch(viewer, listing)) {
      score -= _rentPetSmokingSoftPenalty;
    }

    return score.round().clamp(0, rentMaxScore);
  }

  static double _rentLocationCommuteFraction(
    _MatchFlags f,
    _SearchMatchFlags search,
    Map<String, dynamic>? viewerSession,
    Map<String, dynamic> listing,
  ) {
    final cityOk = f.locationMatch || search.cityExact;
    if (!cityOk) return 0;

    final hasCommuteIntent = viewerSession != null &&
        !ProfileData.commuteDestinationUnknown(viewerSession) &&
        (ProfileData.maximumCommuteBudgetMinutes(viewerSession) != null ||
            CommuteProfileRegistry.fromSession(viewerSession).isNotEmpty);
    if (!hasCommuteIntent) return 1.0;
    if (f.commuteWithinBudget || !f.commuteOverBudget) return 1.0;
    return 0.5;
  }

  static double _rentLifestyleFraction(
    _MatchFlags f,
    _SearchMatchFlags search,
  ) {
    var matched = 0.0;
    if (f.occupantMatch || search.occupantExact) matched += 1;
    if (f.furnishingMatch) matched += 1;
    return matched / 2;
  }

  static bool _rentPetSmokingMismatch(
    ViewerProfile viewer,
    Map<String, dynamic> listing,
  ) {
    if (_listingExplicitlyDisallowsSmoking(listing) && viewer.smokingOk) {
      return true;
    }
    if (_listingExplicitlyDisallowsPets(listing) && viewer.householdHasPets) {
      return true;
    }
    return false;
  }

  static int _scoreBuy(
    _MatchFlags f,
    ViewerProfile? viewer,
    Map<String, dynamic> listing,
    _SearchMatchFlags search,
    _ScoringWeights w,
  ) {
    var score = 0;
    if (f.foodMatch || search.foodExact) score += 10;
    if (f.priceAlignment) score += 45;
    if (f.budgetCompatible) score += 30;
    if (f.locationMatch || search.cityExact) score += w.city;
    if (f.categoryMatch) score += 15;
    if (f.possessionMatch) score += 10;
    if (f.languageMatch) score += 10;
    if (f.nativityMatch) score += 5;
    if (viewer != null && _mutualMatchBuy(viewer, listing)) score += 10;
    return score;
  }

  static int _scoreShare(
    _MatchFlags f,
    ViewerProfile? viewer,
    Map<String, dynamic> listing,
    _SearchMatchFlags search,
    _ScoringWeights w,
    Map<String, dynamic>? viewerSession,
  ) {
    final weights = _ShareTowerWeights.forViewer(viewer);
    final price = _parsePrice(ListingData.price(listing));
    var score = 0.0;

    if (f.languageMatch) score += weights.language;

    if (_shareDietKitchenMatch(f, search, viewer, listing)) {
      score += weights.diet;
    }

    if (f.occupantMatch || f.roommateTypeMatch || search.occupantExact) {
      score += weights.occupant;
    }

    score += weights.budget * _shareBudgetFitFraction(price, viewer);

    score += weights.lifestyle *
        _shareLifestyleSocialFraction(f, viewer, listing);

    if (f.timingMatch) score += weights.timing;

    return score.round().clamp(0, shareMaxScore);
  }

  static bool _shareDietKitchenMatch(
    _MatchFlags f,
    _SearchMatchFlags search,
    ViewerProfile? viewer,
    Map<String, dynamic> listing,
  ) {
    if (f.foodMatch || search.foodExact) return true;
    if (viewer == null) return false;
    return f.lifestyleCompatible;
  }

  static double _shareLifestyleSocialFraction(
    _MatchFlags f,
    ViewerProfile? viewer,
    Map<String, dynamic> listing,
  ) {
    var matched = 0;
    var signals = 0;

    signals++;
    if (f.lifestyleCompatible) matched++;

    final flags = ListingData.lifestyleFlags(listing);
    if (flags.contains('quiet_hours_preferred')) {
      signals++;
      if (_quietHoursAligned(viewer, listing)) matched++;
    }

    if (viewer != null &&
        (viewer.scheduleType.isNotEmpty ||
            ListingData.scheduleType(listing).isNotEmpty)) {
      signals++;
      if (_scheduleCompatible(viewer, listing)) matched++;
    }

    if (signals == 0) return 0;
    return matched / signals;
  }

  // ΓöÇΓöÇ Mutual matching (buy tower only) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static bool _mutualMatchBuy(ViewerProfile viewer, Map<String, dynamic> listing) {
    final prefOccupant = ListingData.preferredTenantOccupant(listing);
    if (prefOccupant.isNotEmpty && viewer.occupantType.isNotEmpty) {
      return ListingData.matchesOccupantType(
        {'occupantType': viewer.occupantType},
        prefOccupant,
      );
    }
    return false;
  }

  static bool _scheduleCompatible(ViewerProfile? viewer, Map<String, dynamic> listing) {
    if (viewer == null) return false;
    final listingSchedule = ListingData.scheduleType(listing).toLowerCase();
    if (listingSchedule.isEmpty || listingSchedule == 'flexible') return true;
    final viewerSchedule = viewer.scheduleType.toLowerCase();
    if (viewerSchedule.isEmpty || viewerSchedule == 'flexible') return true;
    return viewerSchedule == listingSchedule;
  }

  // ΓöÇΓöÇ Reasons ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static List<String> _combinedReasons(
    _MatchFlags f,
    _SearchMatchFlags search,
    MatchTower tower, {
    required TrustStage hostTrust,
    required bool inCircle,
    required int maxReasons,
    ViewerProfile? viewer,
    bool hasPreArrivalTrustUpgrade = false,
  }) {
    final all = <String>[];

    if (inCircle) all.add('≡ƒñ¥ In your circle');

    if (hasPreArrivalTrustUpgrade) {
      all.add('✅ Pre-arrival docs verified — Grand trust weighting');
    }

    if (hostTrust == TrustStage.idVerified) {
      all.add('≡ƒ¢í∩╕Å ID Verified');
    } else if (hostTrust == TrustStage.socialVerified) {
      all.add('≡ƒÆ╝ Socially verified');
    }

    _appendExactSearchReasons(all, search);

    switch (tower) {
      case MatchTower.rent:
        if (f.commuteOverBudget) {
          all.add('⚠️ Commute may exceed your budget');
        }
        if (f.timingQuality == TimingMatchQuality.weak) {
          all.add('⚠️ ${f.timingQuality.label}');
        } else if (f.timingMatch && f.timingQuality.label.isNotEmpty) {
          all.add('✅ ${f.timingQuality.label}');
        }
        if (!search.foodExact && f.foodMatch) {
          all.add('Γ£à Same food preference');
        }
        if (!search.cityExact && f.locationMatch) {
          all.add('Γ£à Same city');
        }
        if (!search.occupantExact && f.occupantMatch) {
          all.add('Γ£à Matches your living preference');
        }
        if (!search.genderExact && f.genderMatch) {
          all.add('Γ£à Gender preference aligned');
        }
        if (f.nativityMatch) all.add('Γ£à Same native region');
        if (f.bhkMatch) all.add('Γ£à Bed count fits your need');
        if (f.furnishingMatch) all.add('Γ£à Furnished');
        if (f.studentMatch) all.add('Γ£à Student background fits');
        if (f.priceFit) all.add('Γ£à Price in your range');
        if (f.timingMatch && f.timingQuality.label.isNotEmpty) {
          all.add('✅ ${f.timingQuality.label}');
        }
        if (f.commuteWithinBudget) all.add('Γ£à Commute within budget');
      case MatchTower.buy:
        if (!search.foodExact && f.foodMatch) {
          all.add('Γ£à Same food preference');
        }
        if (!search.cityExact && f.locationMatch) {
          all.add('Γ£à Same city/region');
        }
        if (f.priceAlignment) all.add('Γ£à Price aligns with budget');
        if (f.budgetCompatible) all.add('Γ£à Within your budget');
        if (f.categoryMatch) all.add('Γ£à Property category fits');
        if (f.possessionMatch) all.add('Γ£à Ready to move');
        if (f.languageMatch) all.add('Γ£à Speaks your language');
        if (f.nativityMatch) all.add('Γ£à Same native region');
      case MatchTower.share:
        if (f.budgetSoftOver) {
          all.add('⚠️ Slightly over your max budget');
        }
        if (f.timingQuality == TimingMatchQuality.weak) {
          all.add('⚠️ ${f.timingQuality.label}');
        } else if (f.timingMatch && f.timingQuality.label.isNotEmpty) {
          all.add('✅ ${f.timingQuality.label}');
        }
        if (f.commuteOverBudget) {
          all.add('⚠️ Commute may exceed your budget');
        }
        if (f.budgetExactFit) {
          all.add('Γ£à Perfect budget fit');
        } else if (f.priceFit) {
          all.add('Γ£à Within your budget');
        } else if (f.budgetSoftOver) {
          all.add('⚠️ Slightly over your max budget');
        }
        if (f.timingMatch && f.timingQuality.label.isNotEmpty) {
          all.add('✅ ${f.timingQuality.label}');
        }
        if (!search.foodExact && f.foodMatch) {
          all.add('Γ£à Same food preference');
        }
        if (!search.cityExact && f.locationMatch) {
          all.add('Γ£à Same city');
        }
        if (!search.genderExact && f.genderMatch) {
          all.add('Γ£à Gender preference aligned');
        }
        if (!search.occupantExact && f.roommateTypeMatch) {
          all.add('Γ£à Roommate type fits');
        }
        if (f.roomTypeMatch) all.add('Γ£à Room type available');
        if (f.lifestyleCompatible) all.add('Γ£à Lifestyle compatible');
        if (f.languageMatch) all.add('Γ£à Speaks your language');
        if (f.commuteWithinBudget) all.add('Γ£à Commute within budget');
    }
    final result = all.take(maxReasons).toList();
    return result;
  }

  static void _appendExactSearchReasons(
    List<String> all,
    _SearchMatchFlags search,
  ) {
    if (search.foodExact && search.foodLabel.isNotEmpty) {
      all.add('≡ƒöì Matches search: ${search.foodLabel}');
    }
    if (search.cityExact && search.cityLabel.isNotEmpty) {
      all.add('≡ƒöì Matches search: ${search.cityLabel}');
    }
    if (search.occupantExact && search.occupantLabel.isNotEmpty) {
      all.add('≡ƒöì Matches search: ${search.occupantLabel}');
    }
    if (search.genderExact && search.genderLabel.isNotEmpty) {
      all.add('≡ƒöì Matches search: ${search.genderLabel}');
    }
    if (search.showRelated) {
      all.add('≡ƒöì Related to your search');
    }
  }

  // ΓöÇΓöÇ Helpers ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static int? _parsePrice(String price) {
    final match = RegExp(r'[\d,]+').firstMatch(price);
    if (match == null) return null;
    return int.tryParse(match.group(0)!.replaceAll(',', ''));
  }

  static String _normFood(String value) {
    final v = value.toLowerCase();
    if (v.contains('veg') && !v.contains('non')) return 'veg';
    if (v.contains('non')) return 'non-veg';
    return v;
  }

  static String _norm(String value) => value.trim().toLowerCase();

  static String _resolveBedLabel(Map<String, dynamic> listing) {
    final raw = listing['bedrooms'] ?? listing['bhk'];
    return raw?.toString().toLowerCase().trim() ?? '';
  }
}

// ΓöÇΓöÇ Match flags ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _MatchFlags {
  const _MatchFlags({
    required this.foodMatch,
    required this.languageMatch,
    required this.nativityMatch,
    required this.occupantMatch,
    required this.genderMatch,
    required this.studentMatch,
    required this.locationMatch,
    required this.priceFit,
    required this.priceAlignment,
    required this.budgetCompatible,
    required this.propertyTypeMatch,
    required this.lifestyleCompatible,
    required this.roommateTypeMatch,
    required this.bhkMatch,
    required this.furnishingMatch,
    required this.categoryMatch,
    required this.possessionMatch,
    required this.roomTypeMatch,
    required this.shareBudgetScore,
    required this.budgetSoftOver,
    required this.budgetExactFit,
    required this.timingMatch,
    required this.timingMismatch,
    required this.timingQuality,
    required this.commuteOverBudget,
    required this.commuteWithinBudget,
  });

  final bool foodMatch;
  final bool languageMatch;
  final bool nativityMatch;
  final bool occupantMatch;
  final bool genderMatch;
  final bool studentMatch;
  final bool locationMatch;
  final bool priceFit;
  final bool priceAlignment;
  final bool budgetCompatible;
  final bool propertyTypeMatch;
  final bool lifestyleCompatible;
  final bool roommateTypeMatch;
  final bool bhkMatch;
  final bool furnishingMatch;
  final bool categoryMatch;
  final bool possessionMatch;
  final bool roomTypeMatch;
  final int shareBudgetScore;
  final bool budgetSoftOver;
  final bool budgetExactFit;
  final bool timingMatch;
  final bool timingMismatch;
  final TimingMatchQuality timingQuality;
  final bool commuteOverBudget;
  final bool commuteWithinBudget;

  static _MatchFlags empty() => const _MatchFlags(
        foodMatch: false,
        languageMatch: false,
        nativityMatch: false,
        occupantMatch: false,
        genderMatch: false,
        studentMatch: false,
        locationMatch: false,
        priceFit: false,
        priceAlignment: false,
        budgetCompatible: false,
        propertyTypeMatch: false,
        lifestyleCompatible: false,
        roommateTypeMatch: false,
        bhkMatch: false,
        furnishingMatch: false,
        categoryMatch: false,
        possessionMatch: false,
        roomTypeMatch: false,
        shareBudgetScore: 0,
        budgetSoftOver: false,
        budgetExactFit: false,
        timingMatch: false,
        timingMismatch: false,
        timingQuality: TimingMatchQuality.none,
        commuteOverBudget: false,
        commuteWithinBudget: false,
      );

  static _MatchFlags build(
    Map<String, dynamic> listing,
    ViewerProfile viewer, {
    Map<String, dynamic>? viewerSession,
  }) {
    final listingFood = ListingData.foodPreferenceToken(listing);
    final viewerFood = ListingMatchEngine._normFood(viewer.foodPreference);
    final foodMatch =
        viewerFood.isNotEmpty &&
        listingFood.isNotEmpty &&
        viewerFood == listingFood;

    final languageMatch = _languageMatch(listing, viewer);
    final nativityMatch = _nativityMatch(listing, viewer);
    final locationMatch = _locationMatch(listing, viewer);

    final listingOccupant = ListingData.occupantType(listing);
    final occupantMatch = viewer.occupantType.isNotEmpty &&
        listingOccupant.isNotEmpty &&
        ListingData.matchesOccupantType(listing, viewer.occupantType);

    final bachelor = ListingData.bachelorPreference(listing);
    final genderMatchResolved = _genderAligned(viewer.genderPreference, bachelor);

    final listingStudent = ListingData.studentType(listing);
    final studentMatch = viewer.studentType.isNotEmpty &&
        listingStudent.isNotEmpty &&
        viewer.studentType.toLowerCase() == listingStudent.toLowerCase();

    final price = ListingMatchEngine._parsePrice(ListingData.price(listing));
    final priceFit = _priceFitRentShare(price, viewer);
    final priceAlignment = _priceAlignmentBuy(price, viewer);
    final budgetCompatible = priceAlignment;

    final propertyTypeMatch =
        ListingData.propertyType(listing) == 'Buy' ||
        viewer.preferredPropertyType.isEmpty;

    final lifestyleOk = _lifestyleOk(viewer, listing, foodMatch);

    final roommateTypeMatch =
        occupantMatch || (listingOccupant == 'Bachelors' && bachelor.isNotEmpty) ||
        (listingOccupant == 'Working Professionals' && bachelor.isNotEmpty);

    final listingBhk = ListingMatchEngine._resolveBedLabel(listing);
    final bhkMatch = listingBhk.isNotEmpty && _inferredBhkMatches(listingBhk, viewer);

    final listingFurnishing = ListingMatchEngine._norm(ListingData.furnishing(listing));
    final furnishingMatch = listingFurnishing.isNotEmpty &&
        listingFurnishing.contains('furnished') &&
        !listingFurnishing.contains('unfurnished');

    final listingCategory = ListingMatchEngine._norm(ListingData.propertyCategory(listing));
    final categoryMatch = listingCategory.isNotEmpty;

    final listingPossession = ListingMatchEngine._norm(ListingData.possessionStatus(listing));
    final possessionMatch = listingPossession.contains('ready');

    final listingRoomType = ListingMatchEngine._norm(ListingData.roomType(listing));
    final roomTypeMatch = listingRoomType.isNotEmpty;

    final shareBudgetFraction =
        ListingMatchEngine._shareBudgetFitFraction(price, viewer);
    final shareBudgetScore = (shareBudgetFraction * 15).round();
    final budgetSoftOver = ListingMatchEngine._shareBudgetSoftOver(price, viewer);
    final budgetExactFit = price != null &&
        viewer.budgetMax != null &&
        price <= viewer.budgetMax! &&
        (viewer.budgetMin == null ||
            (price >= viewer.budgetMin! && price <= viewer.budgetMax!));
    final timingEval = ListingMatchEngine._evaluateTiming(viewer, listing);
    final timingMatch = ListingMatchEngine._timingMatch(viewer, listing);
    final timingMismatch = ListingMatchEngine._timingMismatch(viewer, listing);
    final commutePenalty =
        ListingMatchEngine._commuteOverBudgetPenalty(viewerSession, listing);
    final commuteOverBudget = commutePenalty >= 12;
    final commuteWithinBudget =
        commutePenalty == 0 && viewerSession != null;

    return _MatchFlags(
      foodMatch: foodMatch,
      languageMatch: languageMatch,
      nativityMatch: nativityMatch,
      occupantMatch: occupantMatch,
      genderMatch: genderMatchResolved,
      studentMatch: studentMatch,
      locationMatch: locationMatch,
      priceFit: priceFit,
      priceAlignment: priceAlignment,
      budgetCompatible: budgetCompatible,
      propertyTypeMatch: propertyTypeMatch,
      lifestyleCompatible: lifestyleOk,
      roommateTypeMatch: roommateTypeMatch,
      bhkMatch: bhkMatch,
      furnishingMatch: furnishingMatch,
      categoryMatch: categoryMatch,
      possessionMatch: possessionMatch,
      roomTypeMatch: roomTypeMatch,
      shareBudgetScore: shareBudgetScore,
      budgetSoftOver: budgetSoftOver,
      budgetExactFit: budgetExactFit,
      timingMatch: timingMatch,
      timingMismatch: timingMismatch,
      timingQuality: timingEval.quality,
      commuteOverBudget: commuteOverBudget,
      commuteWithinBudget: commuteWithinBudget,
    );
  }

  static bool _inferredBhkMatches(String listingBhk, ViewerProfile viewer) {
    final occupant = viewer.occupantType.toLowerCase();
    if (occupant.contains('family')) {
      return listingBhk.contains('2') || listingBhk.contains('3') || listingBhk.contains('4');
    }
    if (occupant.contains('student') || occupant.contains('working') || occupant.contains('bachelor')) {
      return listingBhk.contains('1') || listingBhk.contains('rk');
    }
    return true;
  }

  static bool _genderAligned(String viewerGender, String bachelorPref) {
    if (viewerGender.isEmpty || bachelorPref.isEmpty) return false;
    final g = viewerGender.toLowerCase();
    final p = bachelorPref.toLowerCase();
    if (p.contains('boys & girls') || p.contains('mixed')) return true;
    if (p.contains('boys') && (g.contains('male') || g.contains('boy'))) return true;
    if (p.contains('girls') && (g.contains('female') || g.contains('girl'))) return true;
    return false;
  }

  static bool _languageMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
    if (viewer.motherTongue.isEmpty) return false;
    final hostMother = ListingMatchEngine._norm(ListingData.hostMotherTongue(listing));
    final hostLang = ListingMatchEngine._norm(ListingData.hostLanguage(listing));
    final mother = ListingMatchEngine._norm(viewer.motherTongue);
    if (hostMother == mother) return true;
    if (hostLang.contains(mother)) return true;
    for (final lang in viewer.spokenLanguages) {
      final token = ListingMatchEngine._norm(lang);
      if (hostMother.contains(token) || hostLang.contains(token)) return true;
    }
    return false;
  }

  static bool _nativityMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
    if (viewer.nativePlace.isEmpty) return false;
    final native = ListingMatchEngine._norm(viewer.nativePlace);
    final hostCity = ListingMatchEngine._norm(ListingData.hostCity(listing));
    final location = ListingMatchEngine._norm(ListingData.location(listing));
    return hostCity.contains(native) ||
        location.contains(native) ||
        native.contains(hostCity);
  }

  static bool _locationMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
    if (viewer.city.isEmpty) return false;
    final city = ListingMatchEngine._norm(viewer.city);
    final loc = ListingMatchEngine._norm(ListingData.location(listing));
    final hostCity = ListingMatchEngine._norm(ListingData.hostCity(listing));
    return loc.contains(city) || hostCity.contains(city) || city.contains(hostCity);
  }

  static bool _priceFitRentShare(int? price, ViewerProfile viewer) {
    if (price == null) return false;
    if (viewer.budgetMax != null && price <= viewer.budgetMax!) return true;
    if (viewer.budgetMin != null && viewer.budgetMax != null) {
      return price >= viewer.budgetMin! && price <= viewer.budgetMax!;
    }
    return viewer.budgetMax == null && viewer.budgetMin == null;
  }

  static bool _priceAlignmentBuy(int? price, ViewerProfile viewer) {
    if (price == null) return false;
    if (viewer.budgetMin != null && viewer.budgetMax != null) {
      return price >= viewer.budgetMin! && price <= viewer.budgetMax!;
    }
    if (viewer.budgetMax != null) return price <= viewer.budgetMax! * 1.15;
    return false;
  }

  static bool _lifestyleOk(
    ViewerProfile viewer,
    Map<String, dynamic> listing,
    bool foodMatch,
  ) {
    if (foodMatch) return true;
    if (ListingMatchEngine._lifestyleConflict(viewer, listing)) return false;
    if (ListingMatchEngine._lifestyleFlagConflict(viewer, listing)) return false;
    final lifestyle = ListingData.lifestylePreferences(listing);
    if (lifestyle.isEmpty) return viewer.foodPreference.isEmpty;
    final viewerFood = ListingMatchEngine._normFood(viewer.foodPreference);
    if (viewerFood == 'veg') {
      return !lifestyle.any((e) => e.toLowerCase().contains('non-veg'));
    }
    return true;
  }
}

/// Listing alignment with parsed search intent.
class _SearchMatchFlags {
  const _SearchMatchFlags({
    required this.foodExact,
    required this.cityExact,
    required this.occupantExact,
    required this.genderExact,
    required this.showRelated,
    required this.foodLabel,
    required this.cityLabel,
    required this.occupantLabel,
    required this.genderLabel,
  });

  final bool foodExact;
  final bool cityExact;
  final bool occupantExact;
  final bool genderExact;
  final bool showRelated;
  final String foodLabel;
  final String cityLabel;
  final String occupantLabel;
  final String genderLabel;

  static _SearchMatchFlags empty() => const _SearchMatchFlags(
        foodExact: false,
        cityExact: false,
        occupantExact: false,
        genderExact: false,
        showRelated: false,
        foodLabel: '',
        cityLabel: '',
        occupantLabel: '',
        genderLabel: '',
      );

  static _SearchMatchFlags fromIntent(
    Map<String, dynamic> listing,
    SearchIntent requested, {
    required SearchIntent applied,
    required bool filtersWereRelaxed,
  }) {
    final foodExact = requested.food != null &&
        ListingData.matchesFoodPreference(listing, requested.food!);
    final cityExact = requested.city != null &&
        ListingSearchIntent.matchesCity(listing, requested.city!);
    final occupantExact = requested.occupant != null &&
        ListingData.matchesOccupantType(listing, requested.occupant!);
    final genderExact = requested.gender != null &&
        ListingSearchIntent.matchesGender(listing, requested.gender!);

    final keywordsExact = ListingSearchIntent.matchesKeywords(
      listing,
      requested.remainingKeywords,
    );

    final anyExact = foodExact ||
        cityExact ||
        occupantExact ||
        genderExact ||
        keywordsExact;

    final softRelaxed = (requested.city != null && applied.city == null) ||
        (requested.food != null && applied.food == null);

    final showRelated =
        requested.hasStructuredFilters && !anyExact && (softRelaxed || filtersWereRelaxed);

    return _SearchMatchFlags(
      foodExact: foodExact,
      cityExact: cityExact,
      occupantExact: occupantExact,
      genderExact: genderExact,
      showRelated: showRelated,
      foodLabel: switch (requested.food) {
        'veg' => 'Veg',
        'non-veg' => 'Non-veg',
        _ => '',
      },
      cityLabel: requested.city != null
          ? ListingSearchIntent.cityDisplayName(requested.city!)
          : '',
      occupantLabel: requested.occupant ?? '',
      genderLabel: requested.gender == 'girls'
          ? 'Girls'
          : requested.gender == 'boys'
              ? 'Boys'
              : '',
    );
  }
}

/// Persona-adjusted weight buckets for independent-places scoring (sum = 100).
class _RentTowerWeights {
  const _RentTowerWeights({
    required this.budget,
    required this.bedCount,
    required this.locationCommute,
    required this.timing,
    required this.language,
    required this.lifestyle,
  });

  final int budget;
  final int bedCount;
  final int locationCommute;
  final int timing;
  final int language;
  final int lifestyle;

  static _RentTowerWeights forViewer(ViewerProfile? viewer) {
    final occ = viewer?.occupantType.toLowerCase() ?? '';
    if (occ.contains('student')) {
      return const _RentTowerWeights(
        budget: 30,
        bedCount: 15,
        locationCommute: 20,
        timing: 20,
        language: 10,
        lifestyle: 5,
      );
    }
    if (occ.contains('working') || occ.contains('professional')) {
      return const _RentTowerWeights(
        budget: 20,
        bedCount: 15,
        locationCommute: 25,
        timing: 15,
        language: 10,
        lifestyle: 15,
      );
    }
    if (occ.contains('family')) {
      return const _RentTowerWeights(
        budget: 25,
        bedCount: 30,
        locationCommute: 20,
        timing: 10,
        language: 5,
        lifestyle: 10,
      );
    }
    return const _RentTowerWeights(
      budget: 25,
      bedCount: 20,
      locationCommute: 20,
      timing: 15,
      language: 10,
      lifestyle: 10,
    );
  }
}

/// Persona-adjusted weight buckets for shared-living scoring (sum = 100).
class _ShareTowerWeights {
  const _ShareTowerWeights({
    required this.language,
    required this.diet,
    required this.occupant,
    required this.budget,
    required this.lifestyle,
    required this.timing,
  });

  final int language;
  final int diet;
  final int occupant;
  final int budget;
  final int lifestyle;
  final int timing;

  static _ShareTowerWeights forViewer(ViewerProfile? viewer) {
    final occ = viewer?.occupantType.toLowerCase() ?? '';
    if (occ.contains('student')) {
      return const _ShareTowerWeights(
        language: 30,
        lifestyle: 20,
        occupant: 20,
        diet: 15,
        budget: 10,
        timing: 5,
      );
    }
    if (occ.contains('working') || occ.contains('professional')) {
      return const _ShareTowerWeights(
        budget: 20,
        occupant: 25,
        lifestyle: 15,
        language: 20,
        diet: 15,
        timing: 5,
      );
    }
    return const _ShareTowerWeights(
      language: 25,
      diet: 20,
      occupant: 20,
      budget: 15,
      lifestyle: 10,
      timing: 10,
    );
  }
}

/// Base weights; boosted when the dimension appears in the search query.
class _ScoringWeights {
  const _ScoringWeights({
    required this.food,
    required this.city,
    required this.occupant,
    required this.gender,
  });

  final int food;
  final int city;
  final int occupant;
  final int gender;

  static _ScoringWeights fromSearchIntent(SearchIntent? intent) {
    return _ScoringWeights(
      food: intent?.food != null ? 60 : 40,
      city: intent?.city != null ? 45 : 30,
      occupant: intent?.occupant != null ? 45 : 30,
      gender: intent?.gender != null ? 40 : 25,
    );
  }
}




