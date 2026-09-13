import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/models/move_in_timing.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/active_mode_service.dart';
import 'package:true_circle/services/profile_onboarding_repository.dart';
import 'package:true_circle/services/profile_portal_inheritance_service.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/utils/weighted_listing_matcher.dart';

/// Ranking Tie Stability Justification — measure exact / near ties.
///
/// Run: `flutter test test/ranking_tie_stability_justification_test.dart`
///
/// Production path (Active Mode Explore, same as prior UAT audits):
/// - [MarketplaceSpace.fromSession]
/// - [ProfilePortalInheritanceService.seekerFeedDefaults]
/// - [MarketplaceListingPipeline.runWithFilters]
///   → [WeightedListingMatcher.fetchScoredListings]
///   → [ListingMatchEngine.rank]
///
/// Definitions:
/// - Exact score tie: consecutive ranks in the full eligible ranked list with
///   equal [ListingMatchResult.score].
/// - Full-key tie: consecutive ranks where the production comparator would
///   return 0 (preferenceScore when soft filters active, quality
///   tier, match.score) — i.e. order not determined by any secondary key.
/// - Near tie ±1 / ±2: consecutive ranks with absolute score delta of 1 or 2
///   (excluding exact ties).
void main() {
  test('ranking tie stability justification dump', () {
    final corpus = SampleListingsDublin.items;
    final shareCount =
        corpus.where((l) => ListingData.listingType(l) == 'Share').length;
    final rentCount =
        corpus.where((l) => ListingData.listingType(l) == 'Rent').length;

    final seekers = _loadFrozenSeekers();
    expect(seekers.length, 66);

    final seekerResults = <Map<String, dynamic>>[
      for (final seeker in seekers) _runSeeker(seeker, corpus),
    ];

    var exactTiePairs = 0;
    var fullKeyTiePairs = 0;
    var near1Pairs = 0;
    var near2Pairs = 0;
    var resultSetsWithExact = 0;
    var resultSetsWithNear1 = 0;
    var resultSetsWithNear2 = 0;
    var resultSetsWithFullKey = 0;
    var resultSetsNonEmpty = 0;
    var topExactTiePairs = 0;
    var topFullKeyTiePairs = 0;
    var resultSetsWithTopExact = 0;
    var resultSetsWithTopFullKey = 0;

    final listingPairCounts = <String, int>{};
    final scoreValueCounts = <int, int>{};
    final fullKeyPairCounts = <String, int>{};

    for (final r in seekerResults) {
      final rankedCount = r['ranked_count'] as int;
      if (rankedCount == 0) continue;
      resultSetsNonEmpty++;

      final exact = r['exact_score_tie_pairs'] as int;
      final fullKey = r['full_key_tie_pairs'] as int;
      final n1 = r['near_tie_pm1_pairs'] as int;
      final n2 = r['near_tie_pm2_pairs'] as int;
      final topExact = r['top5_exact_score_tie_pairs'] as int;
      final topFull = r['top5_full_key_tie_pairs'] as int;

      exactTiePairs += exact;
      fullKeyTiePairs += fullKey;
      near1Pairs += n1;
      near2Pairs += n2;
      topExactTiePairs += topExact;
      topFullKeyTiePairs += topFull;

      if (exact > 0) resultSetsWithExact++;
      if (fullKey > 0) resultSetsWithFullKey++;
      if (n1 > 0) resultSetsWithNear1++;
      if (n2 > 0) resultSetsWithNear2++;
      if (topExact > 0) resultSetsWithTopExact++;
      if (topFull > 0) resultSetsWithTopFullKey++;

      for (final p in (r['exact_tie_listing_pairs'] as List).cast<String>()) {
        listingPairCounts[p] = (listingPairCounts[p] ?? 0) + 1;
      }
      for (final p in (r['full_key_tie_listing_pairs'] as List).cast<String>()) {
        fullKeyPairCounts[p] = (fullKeyPairCounts[p] ?? 0) + 1;
      }
      for (final s in (r['exact_tie_scores'] as List).cast<int>()) {
        scoreValueCounts[s] = (scoreValueCounts[s] ?? 0) + 1;
      }
    }

    double pct(int n, int d) => d == 0 ? 0.0 : (100.0 * n / d);

    final top20ListingPairs = _topN(listingPairCounts, 20);
    final top20FullKeyPairs = _topN(fullKeyPairCounts, 20);
    final top20Scores = scoreValueCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    // Tie-breaker code inspection (static — inventored ranking files).
    const tieBreakerAnalysis = {
      'primary_sort_keys': [
        'preferenceScore (desc) when WeightedFilterCriteria has soft filters',
        'qualityTier from match.percentage (>=50, 25-49, <25)',
        'match.score (desc)',
      ],
      'explicit_final_tie_breaker': 'none',
      'listing_id_secondary_key': false,
      'dart_list_sort':
          'Dart List.sort is stable; equal comparator results preserve '
          'relative order from the weighted pool (itself sorted only by '
          'preferenceScore with no id key).',
      'weighted_pool_sort':
          'WeightedListingMatcher.fetchScoredListings sorts by preference '
          'score only; equal preference scores keep filter-pass order.',
      'exercised_when_scores_differ': true,
      'exercised_when_all_keys_equal':
          'No product-level deterministic breaker; residual upstream order '
          'only (stable sort of input pool order).',
    };

    final classification = _classify(
      resultSetsNonEmpty: resultSetsNonEmpty,
      resultSetsWithExact: resultSetsWithExact,
      resultSetsWithFullKey: resultSetsWithFullKey,
      resultSetsWithTopExact: resultSetsWithTopExact,
      resultSetsWithTopFullKey: resultSetsWithTopFullKey,
      exactTiePairs: exactTiePairs,
      fullKeyTiePairs: fullKeyTiePairs,
    );

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final summary = <String, dynamic>{
      'seekers_total': seekers.length,
      'result_sets_non_empty': resultSetsNonEmpty,
      'result_sets_empty': seekers.length - resultSetsNonEmpty,
      'exact_score_tie_pairs': exactTiePairs,
      'full_key_tie_pairs': fullKeyTiePairs,
      'near_tie_pm1_pairs': near1Pairs,
      'near_tie_pm2_pairs': near2Pairs,
      'pct_result_sets_with_exact_ties':
          _round1(pct(resultSetsWithExact, resultSetsNonEmpty)),
      'pct_result_sets_with_full_key_ties':
          _round1(pct(resultSetsWithFullKey, resultSetsNonEmpty)),
      'pct_result_sets_with_near_pm1':
          _round1(pct(resultSetsWithNear1, resultSetsNonEmpty)),
      'pct_result_sets_with_near_pm2':
          _round1(pct(resultSetsWithNear2, resultSetsNonEmpty)),
      'top5_exact_score_tie_pairs': topExactTiePairs,
      'top5_full_key_tie_pairs': topFullKeyTiePairs,
      'pct_result_sets_with_top5_exact_ties':
          _round1(pct(resultSetsWithTopExact, resultSetsNonEmpty)),
      'pct_result_sets_with_top5_full_key_ties':
          _round1(pct(resultSetsWithTopFullKey, resultSetsNonEmpty)),
      'result_sets_with_exact_ties': resultSetsWithExact,
      'result_sets_with_full_key_ties': resultSetsWithFullKey,
      'result_sets_with_near_pm1': resultSetsWithNear1,
      'result_sets_with_near_pm2': resultSetsWithNear2,
      'classification': classification['code'],
    };

    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'classification': classification,
      'summary': summary,
      'tie_definitions': {
        'exact_score_tie':
            'Consecutive ranks in full eligible ranked list with equal '
            'ListingMatchResult.score.',
        'full_key_tie':
            'Consecutive ranks where ListingMatchEngine.rank comparator '
            'returns 0 (preferenceScore if soft filters, '
            'qualityTier, match.score).',
        'near_tie_pm1':
            'Consecutive ranks with |scoreA-scoreB|==1 (excludes exact).',
        'near_tie_pm2':
            'Consecutive ranks with |scoreA-scoreB|==2 (excludes exact).',
        'top20_definition':
            'Most frequent canonical listing-id pairs (idA|idB, idA<idB) '
            'that appear as consecutive exact-score ties across seekers; '
            'also top recurring tied score values.',
      },
      'tie_breaker_analysis': tieBreakerAnalysis,
      'top_20_exact_tie_listing_pairs': top20ListingPairs,
      'top_20_full_key_tie_listing_pairs': top20FullKeyPairs,
      'top_20_exact_tie_score_values': [
        for (final e in top20Scores.take(20))
          {'score': e.key, 'occurrence_count': e.value},
      ],
      'methodology': {
        'active_mode': ActiveMode.explore.storageToken,
        'code_paths': [
          'MarketplaceSpace.fromSession',
          'ProfilePortalInheritanceService.seekerFeedDefaults',
          'MarketplaceListingPipeline.runWithFilters',
          'WeightedListingMatcher.fetchScoredListings',
          'ListingMatchEngine.rank',
        ],
        'listing_corpus': {
          'name': 'SampleListingsDublin',
          'shared_living_count': shareCount,
          'independent_places_count': rentCount,
          'total': corpus.length,
        },
        'seeker_dataset': {
          'status': 'reconstructed',
          'count': seekers.length,
          'shared_living':
              seekers.where((s) => s.marketplace == 'shared_living').length,
          'independent_places': seekers
              .where((s) => s.marketplace == 'independent_places')
              .length,
          'includes_market_sentinels': true,
          'fixture':
              'test/fixtures/uat_frozen_seekers_reconstructed.json',
          'note':
              'Frozen UAT seeker JSON is not inventored under lib/. '
              'Preference maps reconstructed from the same prior UAT chat '
              'artifact used by blank_field / active_mode / zero_match '
              'harnesses (66 seekers incl. SL-MARKET-01 / IP-MARKET-01). '
              'Ranking fields only; uat_validation_points omitted.',
        },
        'production_code_modified': false,
      },
      'per_seeker': [
        for (final s in seekerResults)
          {
            'seeker_id': s['seeker_id'],
            'marketplace': s['marketplace'],
            'ranked_count': s['ranked_count'],
            'exact_score_tie_pairs': s['exact_score_tie_pairs'],
            'full_key_tie_pairs': s['full_key_tie_pairs'],
            'near_tie_pm1_pairs': s['near_tie_pm1_pairs'],
            'near_tie_pm2_pairs': s['near_tie_pm2_pairs'],
            'top5_exact_score_tie_pairs': s['top5_exact_score_tie_pairs'],
            'top5_full_key_tie_pairs': s['top5_full_key_tie_pairs'],
            'score_range': s['score_range'],
          },
      ],
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    File('${outDir.path}/ranking_tie_stability_justification.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('${outDir.path}/ranking_tie_stability_justification.md')
        .writeAsStringSync(_markdown(payload));

    // ignore: avoid_print
    print(
      'CLASSIFICATION=${classification['code']} '
      'exact=$exactTiePairs near±1=$near1Pairs near±2=$near2Pairs '
      'pctExact=${summary['pct_result_sets_with_exact_ties']}% '
      'fullKey=$fullKeyTiePairs seekers=${seekers.length}',
    );

    expect(File('${outDir.path}/ranking_tie_stability_justification.md')
        .existsSync(), isTrue);
    expect(
      ['A', 'B', 'C'].contains(classification['code']),
      isTrue,
    );
  });
}

class _FrozenSeeker {
  const _FrozenSeeker({
    required this.seekerId,
    required this.marketplace,
    required this.occupationType,
    required this.maxBudget,
    required this.preferredLocations,
    this.desiredMoveDate,
    this.roomPreference,
    this.propertyTypePreference,
    this.parkingRequired = false,
    this.pets = false,
    this.commutePriority,
    this.transitPreference,
  });

  final String seekerId;
  final String marketplace;
  final String occupationType;
  final int maxBudget;
  final List<String> preferredLocations;
  final String? desiredMoveDate;
  final String? roomPreference;
  final String? propertyTypePreference;
  final bool parkingRequired;
  final bool pets;
  final String? commutePriority;
  final String? transitPreference;
}

List<_FrozenSeeker> _loadFrozenSeekers() {
  final file = File('test/fixtures/uat_frozen_seekers_reconstructed.json');
  expect(file.existsSync(), isTrue, reason: 'frozen seeker fixture missing');
  final raw = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return [
    for (final row in raw)
      _FrozenSeeker(
        seekerId: row['seeker_id'] as String,
        marketplace: row['marketplace'] as String,
        occupationType: row['occupation_type'] as String,
        maxBudget: (row['max_budget'] as num).toInt(),
        preferredLocations: (row['preferred_locations'] as List)
            .map((e) => e.toString())
            .toList(),
        desiredMoveDate: row['desired_move_date']?.toString(),
        roomPreference: row['room_preference']?.toString(),
        propertyTypePreference: row['property_type_preference']?.toString(),
        parkingRequired: row['parking_required'] == true,
        pets: row['pets'] == true,
        commutePriority: row['commute_priority']?.toString(),
        transitPreference: row['transit_preference']?.toString(),
      ),
  ];
}

Map<String, dynamic> _sessionFor(_FrozenSeeker seeker) {
  final isShare = seeker.marketplace == 'shared_living';
  final space =
      isShare ? MarketplaceSpace.sharedSpace : MarketplaceSpace.fullRental;
  final now = DateTime.now().toUtc().toIso8601String();

  final session = <String, dynamic>{
    'email': '${seeker.seekerId.toLowerCase()}@uat.truecircle.dev',
    'full_name': seeker.seekerId,
    'uat_seeker_id': seeker.seekerId,
    'detected_city': 'Dublin',
    'mother_tongue': 'English',
    'spoken_languages': ['English'],
    'food_preference': 'No Preference',
    'budget_max': seeker.maxBudget,
    'preferred_property_type': space.towerPropertyType,
    'preferred_arrangement': space.arrangementBackend,
    'active_marketplace_space': space.storageToken,
    'profile_onboarding_track':
        isShare ? 'seeker_shared_space' : 'seeker_entire_place',
    'preferred_locations': seeker.preferredLocations,
    'occupant_type': _occupantToken(seeker.occupationType),
    'trust_stage': 2,
    ActiveModeService.lastActiveModeKey: ActiveMode.explore.storageToken,
    ActiveModeService.lastModeUpdatedAtKey: now,
  };

  if (isShare) {
    final room = seeker.roomPreference?.toLowerCase();
    if (room == 'private') {
      session['preferred_layout'] = 'private_room';
    } else if (room == 'shared') {
      session['preferred_layout'] = 'shared_room';
    }
  }

  if (!isShare) {
    final prop = seeker.propertyTypePreference?.toLowerCase();
    if (prop == null || prop.isEmpty || prop == 'any') {
      session[PropertyTypePreference.sessionKey] =
          PropertyTypePreference.noPreference.storageToken;
    } else if (prop.contains('house')) {
      session[PropertyTypePreference.sessionKey] =
          PropertyTypePreference.house.storageToken;
    } else if (prop.contains('apartment') || prop.contains('studio')) {
      session[PropertyTypePreference.sessionKey] =
          PropertyTypePreference.apartment.storageToken;
      if (prop.contains('studio')) {
        session['preferred_layout'] = 'Studio';
      }
    }
  }

  if (seeker.parkingRequired) {
    session['parking_required'] = true;
  }
  if (seeker.pets) {
    session['household_has_pets'] = true;
  }

  final commuteBlank = seeker.commutePriority == 'low' ||
      seeker.commutePriority == 'none' ||
      seeker.transitPreference == 'none' ||
      seeker.transitPreference == null;
  if (commuteBlank) {
    session['commute_destination_unknown'] = true;
  }

  if (seeker.transitPreference != null &&
      seeker.transitPreference != 'none' &&
      seeker.transitPreference != 'any') {
    session['preferred_transit'] = seeker.transitPreference;
  }

  if (seeker.desiredMoveDate != null && seeker.desiredMoveDate!.isNotEmpty) {
    session['earliest_move_in_date'] = seeker.desiredMoveDate;
    final parsed = DateTime.tryParse(seeker.desiredMoveDate!);
    if (parsed != null) {
      final window = MoveInTimingMigration.bucketFromDate(
        parsed,
        reference: DateTime.now(),
      );
      session['move_in_window'] = window.storageToken;
    }
  }

  return session;
}

String _occupantToken(String occupationType) {
  final o = occupationType.toLowerCase();
  if (o.contains('student')) return 'Students';
  if (o.contains('family') || o.contains('couple')) return 'Family';
  return 'Working Professionals';
}

int _qualityTier(ListingMatchResult m) {
  if (m.percentage >= 50) return 2;
  if (m.percentage >= 25) return 1;
  return 0;
}

bool _weightedHasSoft(WeightedFilterCriteria c) {
  return c.requiresWfh ||
      c.requiresVeg ||
      c.requiresNonVeg ||
      c.preferredRoomType != null ||
      c.preferredOccupant != null ||
      c.preferredGender != null ||
      c.maxBudget != null;
}

int _compareRankKeys(
  ScoredListing a,
  ScoredListing b, {
  required bool usesWeightedSort,
}) {
  if (usesWeightedSort) {
    final pref = b.preferenceScore.compareTo(a.preferenceScore);
    if (pref != 0) return pref;
  }
  final aTier = _qualityTier(a.match);
  final bTier = _qualityTier(b.match);
  if (aTier != bTier) return bTier - aTier;
  return b.match.score.compareTo(a.match.score);
}

Map<String, dynamic> _runSeeker(
  _FrozenSeeker seeker,
  List<Map<String, dynamic>> corpus,
) {
  final session = _sessionFor(seeker);
  final resolvedSpace = MarketplaceSpace.fromSession(session);
  final tower = resolvedSpace.towerPropertyType;
  final snapshot = ProfileOnboardingRepository.snapshotFromSession(session);
  final filters =
      ProfilePortalInheritanceService.seekerFeedDefaults(snapshot)
          .scopedForTower(tower);

  final pipeline = MarketplaceListingPipeline.runWithFilters(
    allListings: corpus,
    towerPropertyType: tower,
    filters: filters,
    userSession: session,
  );

  final ranked = pipeline.ranked;
  final weightedCriteria = WeightedFilterCriteria.fromSearchContext(
    filters: filters,
    userSession: session,
    towerPropertyType: tower,
  );
  final usesWeightedSort = _weightedHasSoft(weightedCriteria);

  var exact = 0;
  var fullKey = 0;
  var near1 = 0;
  var near2 = 0;
  var topExact = 0;
  var topFull = 0;
  final exactPairs = <String>[];
  final fullKeyPairs = <String>[];
  final exactScores = <int>[];
  var minScore = ranked.isEmpty ? 0 : ranked.first.match.score;
  var maxScore = minScore;

  for (var i = 0; i < ranked.length - 1; i++) {
    final a = ranked[i];
    final b = ranked[i + 1];
    final scoreA = a.match.score;
    final scoreB = b.match.score;
    minScore = math.min(minScore, math.min(scoreA, scoreB));
    maxScore = math.max(maxScore, math.max(scoreA, scoreB));
    final delta = (scoreA - scoreB).abs();
    final inTop5 = i < 5;

    if (delta == 0) {
      exact++;
      exactScores.add(scoreA);
      final idA = ListingData.id(a.listing);
      final idB = ListingData.id(b.listing);
      final pair = idA.compareTo(idB) <= 0 ? '$idA|$idB' : '$idB|$idA';
      exactPairs.add(pair);
      if (inTop5) topExact++;
    } else if (delta == 1) {
      near1++;
    } else if (delta == 2) {
      near2++;
    }

    if (_compareRankKeys(a, b, usesWeightedSort: usesWeightedSort) == 0) {
      fullKey++;
      final idA = ListingData.id(a.listing);
      final idB = ListingData.id(b.listing);
      final pair = idA.compareTo(idB) <= 0 ? '$idA|$idB' : '$idB|$idA';
      fullKeyPairs.add(pair);
      if (inTop5) topFull++;
    }
  }

  return {
    'seeker_id': seeker.seekerId,
    'marketplace': seeker.marketplace,
    'ranked_count': ranked.length,
    'exact_score_tie_pairs': exact,
    'full_key_tie_pairs': fullKey,
    'near_tie_pm1_pairs': near1,
    'near_tie_pm2_pairs': near2,
    'top5_exact_score_tie_pairs': topExact,
    'top5_full_key_tie_pairs': topFull,
    'exact_tie_listing_pairs': exactPairs,
    'full_key_tie_listing_pairs': fullKeyPairs,
    'exact_tie_scores': exactScores,
    'score_range': ranked.isEmpty ? null : {'min': minScore, 'max': maxScore},
    'uses_weighted_sort': usesWeightedSort,
  };
}

List<Map<String, dynamic>> _topN(Map<String, int> counts, int n) {
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return [
    for (final e in entries.take(n))
      {'listing_id_pair': e.key, 'occurrence_count': e.value},
  ];
}

double _round1(double v) => (v * 10).roundToDouble() / 10.0;

Map<String, dynamic> _classify({
  required int resultSetsNonEmpty,
  required int resultSetsWithExact,
  required int resultSetsWithFullKey,
  required int resultSetsWithTopExact,
  required int resultSetsWithTopFullKey,
  required int exactTiePairs,
  required int fullKeyTiePairs,
}) {
  final pctExact =
      resultSetsNonEmpty == 0 ? 0.0 : 100.0 * resultSetsWithExact / resultSetsNonEmpty;
  final pctFull =
      resultSetsNonEmpty == 0 ? 0.0 : 100.0 * resultSetsWithFullKey / resultSetsNonEmpty;
  final pctTopExact = resultSetsNonEmpty == 0
      ? 0.0
      : 100.0 * resultSetsWithTopExact / resultSetsNonEmpty;
  final pctTopFull = resultSetsNonEmpty == 0
      ? 0.0
      : 100.0 * resultSetsWithTopFullKey / resultSetsNonEmpty;

  // A: frequent exact / full-key ties, especially at top ranks, without a
  //    deterministic final breaker.
  // C: almost no exact ties; secondary keys rarely contested at top.
  // B: some ties but rare / low top-rank impact.
  if (pctFull >= 40 ||
      pctTopFull >= 25 ||
      (pctExact >= 50 && pctTopExact >= 20 && fullKeyTiePairs > 0)) {
    return {
      'code': 'A',
      'label': 'Tie Stability Audit Required',
      'reason':
          'Frequent ties among consecutive ranks '
          '(exact score sets ${pctExact.toStringAsFixed(1)}%, '
          'full-key ${pctFull.toStringAsFixed(1)}%; '
          'top-5 exact ${pctTopExact.toStringAsFixed(1)}%, '
          'top-5 full-key ${pctTopFull.toStringAsFixed(1)}%) '
          'with no listing-id/timestamp final breaker.',
    };
  }

  if (exactTiePairs <= 5 &&
      fullKeyTiePairs <= 5 &&
      pctExact < 10 &&
      pctTopExact < 5) {
    return {
      'code': 'C',
      'label': 'Tie Stability Audit Not Required',
      'reason':
          'Almost no exact or full-key consecutive ties '
          '(exact pairs=$exactTiePairs, full-key=$fullKeyTiePairs; '
          '${pctExact.toStringAsFixed(1)}% of non-empty result sets). '
          'Secondary keys (preferenceScore / circle / tier / score) '
          'usually differentiate order.',
    };
  }

  return {
    'code': 'B',
    'label': 'Tie Stability Audit Low Value',
    'reason':
        'Some consecutive ties exist (exact pairs=$exactTiePairs across '
        '${pctExact.toStringAsFixed(1)}% of non-empty sets; '
        'full-key=$fullKeyTiePairs / ${pctFull.toStringAsFixed(1)}%; '
        'top-5 exact ${pctTopExact.toStringAsFixed(1)}%) but frequency / '
        'top-rank impact is moderate. Secondary keys often break order; '
        'final id breaker is absent but contested rarely enough that a '
        'dedicated stability audit is low value.',
  };
}

String _markdown(Map<String, dynamic> payload) {
  final summary = payload['summary'] as Map<String, dynamic>;
  final classification = payload['classification'] as Map<String, dynamic>;
  final methodology = payload['methodology'] as Map<String, dynamic>;
  final seekerDs = methodology['seeker_dataset'] as Map<String, dynamic>;
  final corpus = methodology['listing_corpus'] as Map<String, dynamic>;
  final defs = payload['tie_definitions'] as Map<String, dynamic>;
  final tba = payload['tie_breaker_analysis'] as Map<String, dynamic>;
  final topPairs =
      (payload['top_20_exact_tie_listing_pairs'] as List).cast<Map>();
  final topScores =
      (payload['top_20_exact_tie_score_values'] as List).cast<Map>();
  final buf = StringBuffer();

  buf.writeln('# Ranking Tie Stability Justification');
  buf.writeln();
  buf.writeln('**Classification: ${classification['code']} — '
      '${classification['label']}**');
  buf.writeln();
  buf.writeln(classification['reason']);
  buf.writeln();
  buf.writeln('Audited at: `${payload['audited_at']}`');
  buf.writeln();
  buf.writeln('## Key metrics');
  buf.writeln();
  buf.writeln('| Metric | Value |');
  buf.writeln('| --- | --- |');
  buf.writeln('| Seekers | ${summary['seekers_total']} |');
  buf.writeln(
      '| Non-empty result sets | ${summary['result_sets_non_empty']} |');
  buf.writeln(
      '| Exact score tie pairs (consecutive) | ${summary['exact_score_tie_pairs']} |');
  buf.writeln(
      '| Full-key tie pairs (comparator == 0) | ${summary['full_key_tie_pairs']} |');
  buf.writeln('| Near ties ±1 | ${summary['near_tie_pm1_pairs']} |');
  buf.writeln('| Near ties ±2 | ${summary['near_tie_pm2_pairs']} |');
  buf.writeln(
      '| % result sets with exact ties | ${summary['pct_result_sets_with_exact_ties']}% |');
  buf.writeln(
      '| % result sets with full-key ties | ${summary['pct_result_sets_with_full_key_ties']}% |');
  buf.writeln(
      '| % result sets with near ±1 | ${summary['pct_result_sets_with_near_pm1']}% |');
  buf.writeln(
      '| % result sets with near ±2 | ${summary['pct_result_sets_with_near_pm2']}% |');
  buf.writeln(
      '| Top-5 exact tie pairs | ${summary['top5_exact_score_tie_pairs']} |');
  buf.writeln(
      '| % sets with top-5 exact ties | ${summary['pct_result_sets_with_top5_exact_ties']}% |');
  buf.writeln(
      '| % sets with top-5 full-key ties | ${summary['pct_result_sets_with_top5_full_key_ties']}% |');
  buf.writeln();
  buf.writeln('## Definitions');
  buf.writeln();
  buf.writeln('- **Exact score tie:** ${defs['exact_score_tie']}');
  buf.writeln('- **Full-key tie:** ${defs['full_key_tie']}');
  buf.writeln('- **Near ±1:** ${defs['near_tie_pm1']}');
  buf.writeln('- **Near ±2:** ${defs['near_tie_pm2']}');
  buf.writeln('- **Top 20:** ${defs['top20_definition']}');
  buf.writeln();
  buf.writeln('## Tie-breakers');
  buf.writeln();
  buf.writeln('Primary sort keys in `ListingMatchEngine.rank`:');
  for (final k in (tba['primary_sort_keys'] as List)) {
    buf.writeln('- $k');
  }
  buf.writeln();
  buf.writeln(
      '- Explicit final tie-breaker (listing id / timestamp): '
      '**${tba['explicit_final_tie_breaker']}**');
  buf.writeln('- Listing-id secondary key: `${tba['listing_id_secondary_key']}`');
  buf.writeln('- ${tba['dart_list_sort']}');
  buf.writeln('- ${tba['weighted_pool_sort']}');
  buf.writeln('- When scores differ: secondary keys are exercised.');
  buf.writeln('- When all keys equal: ${tba['exercised_when_all_keys_equal']}');
  buf.writeln();
  buf.writeln('## Top 20 exact-tie listing-id pairs');
  buf.writeln();
  if (topPairs.isEmpty) {
    buf.writeln('_None_');
  } else {
    buf.writeln('| Pair | Occurrences |');
    buf.writeln('| --- | --- |');
    for (final p in topPairs) {
      buf.writeln('| `${p['listing_id_pair']}` | ${p['occurrence_count']} |');
    }
  }
  buf.writeln();
  buf.writeln('## Top 20 exact-tie score values');
  buf.writeln();
  if (topScores.isEmpty) {
    buf.writeln('_None_');
  } else {
    buf.writeln('| Score | Occurrences |');
    buf.writeln('| --- | --- |');
    for (final s in topScores) {
      buf.writeln('| ${s['score']} | ${s['occurrence_count']} |');
    }
  }
  buf.writeln();
  buf.writeln('## Corpus');
  buf.writeln();
  buf.writeln(
      '- Listings: `${corpus['name']}` '
      '(${corpus['shared_living_count']} Share / '
      '${corpus['independent_places_count']} Rent / '
      'total ${corpus['total']})');
  buf.writeln(
      '- Seekers: ${seekerDs['count']} reconstructed '
      '(${seekerDs['shared_living']} SL / '
      '${seekerDs['independent_places']} IP); '
      'fixture `${seekerDs['fixture']}`');
  buf.writeln('- ${seekerDs['note']}');
  buf.writeln();
  buf.writeln('## Production code');
  buf.writeln();
  buf.writeln(
      'No production matching/ranking code was modified. '
      'Test-only harness: `test/ranking_tie_stability_justification_test.dart`.');
  buf.writeln();
  return buf.toString();
}
