import 'package:flutter/foundation.dart';

import 'listing_data.dart';
import 'listing_search_intent.dart';
import 'viewer_profile.dart';

import '../debug/agent_log.dart';
import '../services/commute_scoring_service.dart';
import 'commute_profile.dart';
import 'profile_data.dart';
import 'student_track_preference.dart';

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
    reasons: [],
    excluded: false,
    tower: MatchTower.rent,
  );
}

class ScoredListing {
  const ScoredListing({required this.listing, required this.match});

  final Map<String, dynamic> listing;
  final ListingMatchResult match;
}
class ListingRankOutcome {
  const ListingRankOutcome({
    required this.ranked,
    this.isCommuteDivergent = false,
  });
  final List<ScoredListing> ranked;
  final bool isCommuteDivergent;
}

/// Hard filters + tower scoring + trust multiplier + circle ranking.
///
/// Final Score = TrustMultiplier x CompatibilityScore
abstract final class ListingMatchEngine {
  static const rentMaxScore = 225;
  static const buyMaxScore = 175;
  static const shareMaxScore = 235;

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
  }) {
    final viewer = ViewerProfile.fromSession(viewerSession);
    final scored = <ScoredListing>[];

    for (final listing in listings) {
      final match = evaluate(
        listing,
        viewer,
        viewerSession: viewerSession,
        searchIntent: searchIntent,
        appliedSearchIntent: appliedSearchIntent,
        filtersWereRelaxed: filtersWereRelaxed,
      );
      if (!match.excluded) {
        scored.add(ScoredListing(listing: listing, match: match));
      }
    }

    if (scored.isEmpty && listings.isNotEmpty) {
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
          scored.add(ScoredListing(listing: listing, match: match));
        }
      }
    }

    // Priority ranking:
    // 1. Circle listings ΓåÆ highest quality first
    // 2. High-match (>= 50%) ΓåÆ sorted by score descending
    // 3. Medium-match (25-49%) ΓåÆ sorted by score descending
    // 4. Low-match (< 25%) ΓåÆ pushed to end
    scored.sort((a, b) {
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
    final tower = _towerFor(listing);
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
        ? _MatchFlags.build(listing, viewer)
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
      MatchTower.share => _scoreShare(flags, viewer, listing, searchFlags, weights),
    };

    // Trust multiplier: Final Score = TrustMultiplier x CompatibilityScore
    final hostTrust = TrustStage.fromLevel(ListingData.hostTrustStage(listing));
    final trustMult = hostTrust.multiplier;
    final afterTrust = (trustMult * compatibilityScore).round();
    final finalScore =
        (afterTrust * _preArrivalScoreMultiplier(viewer, listing)).round();

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
    if (percentage >= 80) return '≡ƒöÑ Perfect match';
    if (percentage >= 60) return 'Γ£à Strong match';
    if (percentage >= 40) return '≡ƒæì Good match';
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
    if (_occupantMismatch(viewer.occupantType, ListingData.occupantType(listing))) {
      return true;
    }
    if (_genderMismatch(viewer.genderPreference, ListingData.bachelorPreference(listing))) {
      return true;
    }
    if (_studentMismatch(viewer.studentType, ListingData.studentType(listing))) {
      return true;
    }
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
    if (_lifestyleFlagConflict(viewer, listing)) return true;
    if (_genderMismatch(viewer.genderPreference, ListingData.bachelorPreference(listing))) {
      return true;
    }
    if (_lifestyleConflict(viewer, listing)) return true;
    if (_smokingDrinkingConflict(viewer, listing)) return true;
    return false;
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
    var score = 0;
    if (f.foodMatch || search.foodExact) score += w.food;
    if (f.languageMatch) score += 35;
    if (f.nativityMatch) score += 25;
    if (f.occupantMatch || search.occupantExact) score += w.occupant;
    if (f.genderMatch || search.genderExact) score += w.gender;
    if (f.studentMatch) score += 15;
    if (f.priceFit) score += 10;
    if (f.locationMatch || search.cityExact) score += w.city;
    if (f.bhkMatch) score += 15;
    if (f.furnishingMatch) score += 10;
    if (viewer != null && _mutualMatchRent(viewer, listing)) score += 15;
    score -= _commuteOverBudgetPenalty(viewerSession, listing);
    return score.clamp(0, rentMaxScore);
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
  ) {
    var score = 0;
    if (f.foodMatch || search.foodExact) score += w.food;
    if (f.lifestyleCompatible) score += 40;
    if (f.languageMatch) score += 30;
    if (f.nativityMatch) score += 25;
    if (f.genderMatch || search.genderExact) score += w.gender;
    if (f.roommateTypeMatch || search.occupantExact) score += w.occupant;
    if (f.roomTypeMatch) score += 15;
    if (f.priceFit) score += 10;
    if (f.locationMatch || search.cityExact) score += w.city;
    if (_scheduleCompatible(viewer, listing)) score += 10;
    if (_quietHoursAligned(viewer, listing)) score += 5;
    return score;
  }

  // ΓöÇΓöÇ Mutual matching ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  static bool _mutualMatchRent(ViewerProfile viewer, Map<String, dynamic> listing) {
    final prefOccupant = ListingData.preferredTenantOccupant(listing);
    if (prefOccupant.isNotEmpty && viewer.occupantType.isNotEmpty) {
      return ListingData.matchesOccupantType(
        {'occupantType': viewer.occupantType},
        prefOccupant,
      );
    }
    final prefFood = ListingData.preferredTenantFood(listing);
    if (prefFood.isNotEmpty && viewer.foodPreference.isNotEmpty) {
      return _normFood(viewer.foodPreference) == _normFood(prefFood);
    }
    return false;
  }

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
  }) {
    final all = <String>[];

    if (inCircle) all.add('≡ƒñ¥ In your circle');

    if (hostTrust == TrustStage.idVerified) {
      all.add('≡ƒ¢í∩╕Å ID Verified');
    } else if (hostTrust == TrustStage.socialVerified) {
      all.add('≡ƒÆ╝ Socially verified');
    }

    _appendExactSearchReasons(all, search);

    switch (tower) {
      case MatchTower.rent:
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
        if (f.languageMatch) all.add('Γ£à Speaks your language');
        if (f.nativityMatch) all.add('Γ£à Same native region');
        if (f.bhkMatch) all.add('Γ£à BHK fits your need');
        if (f.furnishingMatch) all.add('Γ£à Furnished');
        if (f.studentMatch) all.add('Γ£à Student background fits');
        if (f.priceFit) all.add('Γ£à Price in your range');
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
        if (f.nativityMatch) all.add('Γ£à Same native region');
    }
    final result = all.take(maxReasons).toList();
    // #region agent log
    if (_combinedReasonsLogCount < 3 && result.isNotEmpty) {
      _combinedReasonsLogCount++;
      agentLog(
        location: 'listing_match_engine.dart:_combinedReasons',
        message: 'Match reasons built',
        hypothesisId: 'B',
        data: {
          'count': result.length,
          'firstReason': result.first,
          'firstHasNonAscii': result.first.runes.any((r) => r > 127),
          'tower': tower.name,
        },
      );
    }
    // #endregion
    return result;
  }

  static int _combinedReasonsLogCount = 0;

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
      );

  static _MatchFlags build(Map<String, dynamic> listing, ViewerProfile viewer) {
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

    final listingBhk = ListingMatchEngine._norm(ListingData.bhk(listing));
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




