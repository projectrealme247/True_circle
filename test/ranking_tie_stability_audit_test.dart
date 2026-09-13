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

/// Ranking Tie Stability Audit — repeat identical production-path searches.
///
/// Run: `flutter test test/ranking_tie_stability_audit_test.dart`
///
/// Production path (Active Mode Explore):
/// - [MarketplaceSpace.fromSession]
/// - [ProfilePortalInheritanceService.seekerFeedDefaults]
/// - [MarketplaceListingPipeline.runWithFilters]
///   → [WeightedListingMatcher.fetchScoredListings]
///   → [ListingMatchEngine.rank]
///
/// Primary metric: 10 identical production-path runs (rebuild corpus each call,
/// matching SampleListingsDublin.items getter behavior).
/// Optional probe: one shuffled input-pool run for latent order dependency.
void main() {
  test('ranking tie stability audit dump', () {
    final seekersById = {
      for (final s in _loadFrozenSeekers()) s.seekerId: s,
    };

    final justification = _loadJustificationPerSeeker();
    final selected = _selectAuditSeekers(justification);
    expect(selected.length, 10);
    expect(
      selected.where((s) => s.marketplace == 'shared_living').length,
      5,
    );
    expect(
      selected.where((s) => s.marketplace == 'independent_places').length,
      5,
    );

    const runsPerSeeker = 10;
    final perSeeker = <Map<String, dynamic>>[];

    for (final meta in selected) {
      final seeker = seekersById[meta.seekerId];
      expect(seeker, isNotNull, reason: 'missing seeker ${meta.seekerId}');
      perSeeker.add(
        _auditSeeker(
          seeker!,
          selection: meta,
          runs: runsPerSeeker,
        ),
      );
    }

    final aggregate = _aggregate(perSeeker);
    final auditedAt = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'risk': {
        'verdict': aggregate['verdict'],
        'severity': aggregate['severity'],
        'rationale': aggregate['rationale'],
      },
      'summary': {
        'seekers_audited': perSeeker.length,
        'runs_per_seeker': runsPerSeeker,
        'aggregate_stability_percentage':
            aggregate['aggregate_stability_percentage'],
        'seekers_fully_stable': aggregate['seekers_fully_stable'],
        'seekers_with_order_changes': aggregate['seekers_with_order_changes'],
        'any_top1_changed': aggregate['any_top1_changed'],
        'any_top5_changed': aggregate['any_top5_changed'],
        'any_tied_pair_swapped_in_top5':
            aggregate['any_tied_pair_swapped_in_top5'],
        'any_shuffled_input_reordered':
            aggregate['any_shuffled_input_reordered'],
        'dart_list_sort_stable': true,
      },
      'selection': {
        'criteria':
            '5 Shared Living + 5 Independent Places from frozen UAT seekers, '
            'chosen from ranking_tie_stability_justification per_seeker metrics '
            'to cover tie-heavy (high exact consecutive ties / top-5 ties), '
            'high-match (higher score_range.max), and medium-match bands.',
        'source_justification':
            'docs/uat/v1/ranking_tie_stability_justification.json',
        'seekers': [
          for (final s in selected)
            {
              'seeker_id': s.seekerId,
              'marketplace': s.marketplace,
              'role': s.role,
              'justification_exact_score_tie_pairs': s.exactTies,
              'justification_top5_exact_tie_pairs': s.top5ExactTies,
              'justification_ranked_count': s.rankedCount,
              'justification_score_range': {
                'min': s.scoreMin,
                'max': s.scoreMax,
              },
            },
        ],
      },
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
          'note':
              'Each production-path run calls SampleListingsDublin.items '
              '(rebuilds via SampleListingsDublinV2.items + '
              'DublinListingBuilder.resetPhotoSlots). Same object identity '
              'is not reused across runs; order of construction is fixed.',
        },
        'seeker_dataset': {
          'fixture': 'test/fixtures/uat_frozen_seekers_reconstructed.json',
          'count_selected': selected.length,
        },
        'repeat_runs': runsPerSeeker,
        'shuffled_input_probe': true,
        'dart_list_sort':
            'Dart List.sort is stable (preserves relative order of equal '
            'elements). ListingMatchEngine.rank and '
            'WeightedListingMatcher.fetchScoredListings have no listing-id '
            'final breaker; equal full keys retain upstream pool order.',
        'production_code_modified': false,
      },
      'root_cause': aggregate['root_cause'],
      'recommended_action': aggregate['recommended_action'],
      'top5_analysis': aggregate['top5_analysis'],
      'per_seeker': perSeeker,
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    File('${outDir.path}/ranking_tie_stability_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('${outDir.path}/ranking_tie_stability_audit.md')
        .writeAsStringSync(_markdown(payload));

    // ignore: avoid_print
    print(
      'VERDICT=${aggregate['verdict']} '
      'stability=${aggregate['aggregate_stability_percentage']}% '
      'top1Changed=${aggregate['any_top1_changed']} '
      'top5Changed=${aggregate['any_top5_changed']} '
      'shuffleReorder=${aggregate['any_shuffled_input_reordered']}',
    );

    expect(
      File('${outDir.path}/ranking_tie_stability_audit.md').existsSync(),
      isTrue,
    );
    expect(
      ['PASS', 'PASS WITH WARNINGS', 'FAIL'].contains(aggregate['verdict']),
      isTrue,
    );
  });
}

class _SelectionMeta {
  const _SelectionMeta({
    required this.seekerId,
    required this.marketplace,
    required this.role,
    required this.exactTies,
    required this.top5ExactTies,
    required this.rankedCount,
    required this.scoreMin,
    required this.scoreMax,
  });

  final String seekerId;
  final String marketplace;
  final String role;
  final int exactTies;
  final int top5ExactTies;
  final int rankedCount;
  final int scoreMin;
  final int scoreMax;
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

Map<String, Map<String, dynamic>> _loadJustificationPerSeeker() {
  final file = File('docs/uat/v1/ranking_tie_stability_justification.json');
  expect(file.existsSync(), isTrue);
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final list = (raw['per_seeker'] as List).cast<Map<String, dynamic>>();
  return {for (final row in list) row['seeker_id'] as String: row};
}

List<_SelectionMeta> _selectAuditSeekers(
  Map<String, Map<String, dynamic>> justification,
) {
  // Explicit selection covering tie-heavy / high-match / medium-match.
  const plan = <(String, String)>[
    // Shared Living
    ('SL-EDGE-05', 'tie-heavy + high-match (28 exact ties, max score 76)'),
    ('SL-PRO-03', 'tie-heavy (25 exact ties, max score 76)'),
    ('SL-STU-03', 'medium ties (15), medium-high match band'),
    ('SL-STU-01', 'lower ties (3), medium-match band 41-70'),
    ('SL-EDGE-11', 'moderate ties (9), higher floor medium-high match'),
    // Independent Places
    ('IP-EDGE-03', 'tie-heavy (42 exact ties, top-5 fully tied)'),
    ('IP-FAM-04', 'tie-heavy (41 exact ties, top-5 fully tied)'),
    ('IP-SIN-03', 'high-match (max 81) + heavy ties (37)'),
    ('IP-EDGE-01', 'high-match (max 90) + moderate ties (13)'),
    ('IP-CPL-01', 'medium-match (max 57) + medium-high ties (19)'),
  ];

  return [
    for (final (id, role) in plan)
      () {
        final j = justification[id]!;
        final range = j['score_range'] as Map<String, dynamic>;
        return _SelectionMeta(
          seekerId: id,
          marketplace: j['marketplace'] as String,
          role: role,
          exactTies: j['exact_score_tie_pairs'] as int,
          top5ExactTies: j['top5_exact_score_tie_pairs'] as int,
          rankedCount: j['ranked_count'] as int,
          scoreMin: (range['min'] as num).toInt(),
          scoreMax: (range['max'] as num).toInt(),
        );
      }(),
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

class _RunCapture {
  _RunCapture({
    required this.orderIds,
    required this.scores,
    required this.tiedPairCount,
    required this.top5Ids,
    required this.top1Id,
  });

  final List<String> orderIds;
  final List<int> scores;
  final int tiedPairCount;
  final List<String> top5Ids;
  final String? top1Id;

  String get orderFingerprint => orderIds.join('|');
  String get top5Fingerprint => top5Ids.join('|');
}

_RunCapture _captureFromRanked(List<ScoredListing> ranked) {
  final ids = <String>[];
  final scores = <int>[];
  var tied = 0;
  for (var i = 0; i < ranked.length; i++) {
    final id = ListingData.id(ranked[i].listing);
    ids.add(id);
    scores.add(ranked[i].match.score);
    if (i > 0 && ranked[i].match.score == ranked[i - 1].match.score) {
      tied++;
    }
  }
  return _RunCapture(
    orderIds: ids,
    scores: scores,
    tiedPairCount: tied,
    top5Ids: ids.take(5).toList(),
    top1Id: ids.isEmpty ? null : ids.first,
  );
}

MarketplaceListingPipelineResult _runProductionPath(
  _FrozenSeeker seeker, {
  List<Map<String, dynamic>>? listingsOverride,
}) {
  final session = _sessionFor(seeker);
  final resolvedSpace = MarketplaceSpace.fromSession(session);
  final tower = resolvedSpace.towerPropertyType;
  final snapshot = ProfileOnboardingRepository.snapshotFromSession(session);
  final filters =
      ProfilePortalInheritanceService.seekerFeedDefaults(snapshot)
          .scopedForTower(tower);

  // Production-like: rebuild SampleListingsDublin each call unless override.
  final corpus = listingsOverride ?? SampleListingsDublin.items;

  return MarketplaceListingPipeline.runWithFilters(
    allListings: corpus,
    towerPropertyType: tower,
    filters: filters,
    userSession: session,
  );
}

int _countTiesReordered(
  List<String> baseline,
  List<int> baselineScores,
  List<String> other,
  List<int> otherScores,
) {
  // Count consecutive exact-score pairs in baseline whose relative order
  // flipped in `other` (same two IDs adjacent-or-same-score-group membership).
  if (baseline.length != other.length) {
    return baseline.length; // treat size drift as full instability
  }
  final otherIndex = <String, int>{
    for (var i = 0; i < other.length; i++) other[i]: i,
  };
  var reordered = 0;
  for (var i = 0; i < baseline.length - 1; i++) {
    if (baselineScores[i] != baselineScores[i + 1]) continue;
    final a = baseline[i];
    final b = baseline[i + 1];
    final ia = otherIndex[a];
    final ib = otherIndex[b];
    if (ia == null || ib == null) {
      reordered++;
      continue;
    }
    // In baseline a precedes b; if b precedes a in other among same scores.
    if (ib < ia) reordered++;
  }
  return reordered;
}

Map<String, dynamic> _auditSeeker(
  _FrozenSeeker seeker, {
  required _SelectionMeta selection,
  required int runs,
}) {
  final captures = <_RunCapture>[];
  for (var i = 0; i < runs; i++) {
    final result = _runProductionPath(seeker);
    captures.add(_captureFromRanked(result.ranked));
  }

  final baseline = captures.first;
  final fingerprints = captures.map((c) => c.orderFingerprint).toSet();
  final identicalOrders = captures
      .where((c) => c.orderFingerprint == baseline.orderFingerprint)
      .length;
  final differentOrders = runs - identicalOrders;

  var maxTiesReordered = 0;
  for (final c in captures.skip(1)) {
    maxTiesReordered = math.max(
      maxTiesReordered,
      _countTiesReordered(
        baseline.orderIds,
        baseline.scores,
        c.orderIds,
        c.scores,
      ),
    );
  }

  final top1Changed = captures.any((c) => c.top1Id != baseline.top1Id);
  final top5Changed =
      captures.any((c) => c.top5Fingerprint != baseline.top5Fingerprint);

  // Tied listings switch in top-5 across runs?
  var tiedListingsSwitchedTop5 = false;
  var tiedPairSwappedTop5 = false;
  for (final c in captures.skip(1)) {
    if (c.top5Fingerprint != baseline.top5Fingerprint) {
      // Same set different order, or membership change.
      final baseSet = baseline.top5Ids.toSet();
      final otherSet = c.top5Ids.toSet();
      if (baseSet.length == otherSet.length &&
          baseSet.containsAll(otherSet) &&
          c.top5Fingerprint != baseline.top5Fingerprint) {
        tiedListingsSwitchedTop5 = true;
      }
      // Adjacent same-score pairs in baseline top-5 that flip.
      for (var i = 0; i < baseline.top5Ids.length - 1; i++) {
        if (baseline.scores[i] != baseline.scores[i + 1]) continue;
        final a = baseline.top5Ids[i];
        final b = baseline.top5Ids[i + 1];
        final ia = c.top5Ids.indexOf(a);
        final ib = c.top5Ids.indexOf(b);
        if (ia >= 0 && ib >= 0 && ib < ia) {
          tiedPairSwappedTop5 = true;
          tiedListingsSwitchedTop5 = true;
        }
      }
    }
  }

  // Shuffled input probe (latent risk): shuffle once, compare to baseline.
  final corpus = SampleListingsDublin.items;
  final shuffled = List<Map<String, dynamic>>.from(corpus);
  shuffled.shuffle(math.Random(42));
  final shuffleCapture =
      _captureFromRanked(_runProductionPath(seeker, listingsOverride: shuffled).ranked);
  final shuffleReordered =
      shuffleCapture.orderFingerprint != baseline.orderFingerprint;
  final shuffleTop1Changed = shuffleCapture.top1Id != baseline.top1Id;
  final shuffleTop5Changed =
      shuffleCapture.top5Fingerprint != baseline.top5Fingerprint;
  final shuffleTiesReordered = _countTiesReordered(
    baseline.orderIds,
    baseline.scores,
    shuffleCapture.orderIds,
    shuffleCapture.scores,
  );

  final stabilityPct =
      runs == 0 ? 0.0 : _round1(100.0 * identicalOrders / runs);

  return {
    'seeker_id': seeker.seekerId,
    'marketplace': seeker.marketplace,
    'selection_role': selection.role,
    'total_runs': runs,
    'identical_orders': identicalOrders,
    'different_orders': differentOrders,
    'stability_percentage': stabilityPct,
    'number_of_tied_results': baseline.tiedPairCount,
    'number_of_ties_reordered': maxTiesReordered,
    'ranked_count': baseline.orderIds.length,
    'top5_analysis': {
      'tied_listings_switched': tiedListingsSwitchedTop5,
      'top_result_changed': top1Changed,
      'top5_order_changed': top5Changed,
      'tied_pair_swapped': tiedPairSwappedTop5,
      'baseline_top5': baseline.top5Ids,
      'baseline_top5_scores': baseline.scores.take(5).toList(),
    },
    'shuffled_input_probe': {
      'order_changed_vs_baseline': shuffleReordered,
      'top1_changed': shuffleTop1Changed,
      'top5_changed': shuffleTop5Changed,
      'ties_reordered': shuffleTiesReordered,
      'shuffled_top5': shuffleCapture.top5Ids,
    },
    'baseline_order_ids': baseline.orderIds,
    'baseline_scores': baseline.scores,
    'unique_order_fingerprints': fingerprints.length,
  };
}

Map<String, dynamic> _aggregate(List<Map<String, dynamic>> perSeeker) {
  final n = perSeeker.length;
  final stabilitySum = perSeeker.fold<double>(
    0,
    (acc, s) => acc + (s['stability_percentage'] as num).toDouble(),
  );
  final aggregateStability = n == 0 ? 0.0 : _round1(stabilitySum / n);
  final fullyStable =
      perSeeker.where((s) => s['different_orders'] == 0).length;
  final withChanges = n - fullyStable;

  final anyTop1 = perSeeker.any(
    (s) => (s['top5_analysis'] as Map)['top_result_changed'] == true,
  );
  final anyTop5 = perSeeker.any(
    (s) => (s['top5_analysis'] as Map)['top5_order_changed'] == true,
  );
  final anyTiedSwap = perSeeker.any(
    (s) => (s['top5_analysis'] as Map)['tied_pair_swapped'] == true,
  );
  final anyShuffle = perSeeker.any(
    (s) =>
        (s['shuffled_input_probe'] as Map)['order_changed_vs_baseline'] == true,
  );
  final anyShuffleTop5 = perSeeker.any(
    (s) => (s['shuffled_input_probe'] as Map)['top5_changed'] == true,
  );
  final anyShuffleTop1 = perSeeker.any(
    (s) => (s['shuffled_input_probe'] as Map)['top1_changed'] == true,
  );

  // Success criteria (primary = 10 identical production-path runs):
  // PASS: identical ranking order every run
  // PASS WITH WARNINGS: minor reorderings only outside top 5
  // FAIL: Top-5 or top result changes across runs
  // Latent: stable on identical runs but unstable when input shuffled →
  // PASS WITH WARNINGS if production path can reshuffle; here production
  // rebuilds SampleListingsDublin in fixed construction order, so shuffle
  // instability is latent risk (WARN) unless identical-run top5 fails.
  late final String verdict;
  late final String severity;
  late final String rationale;

  if (anyTop1 || anyTop5) {
    verdict = 'FAIL';
    severity = anyTop1 ? 'Critical' : 'High';
    rationale =
        'Top-1 and/or top-5 order changed across identical production-path '
        'runs for at least one audited seeker.';
  } else if (withChanges > 0) {
    verdict = 'PASS WITH WARNINGS';
    severity = 'Medium';
    rationale =
        'Identical production-path runs reordered listings only outside '
        'top-5 for some seekers.';
  } else if (anyShuffle && (anyShuffleTop1 || anyShuffleTop5)) {
    verdict = 'PASS WITH WARNINGS';
    severity = 'Medium';
    rationale =
        'All 10 identical production-path runs were stable (top-1 and top-5 '
        'unchanged), but shuffled input pool changed top-5/top-1 order. '
        'Production SampleListingsDublin rebuild is currently fixed-order, '
        'so this is latent risk if a future feed/DB path supplies unstable '
        'input order (no listing-id final breaker).';
  } else if (anyShuffle) {
    verdict = 'PASS WITH WARNINGS';
    severity = 'Low';
    rationale =
        'Identical production-path runs fully stable; shuffled input only '
        'reordered outside top-5. Latent dependency on upstream pool order '
        'because no listing-id final tie-breaker exists.';
  } else {
    verdict = 'PASS';
    severity = 'Low';
    rationale =
        'Identical ranking order on every production-path run for all '
        'audited seekers; shuffled probe also preserved order.';
  }

  final rootCause = <String, dynamic>{
    'identical_run_instability': withChanges > 0,
    'input_order_dependency_detected': anyShuffle,
    'missing_listing_id_final_breaker': true,
    'score_collisions_present': perSeeker.any(
      (s) => (s['number_of_tied_results'] as int) > 0,
    ),
    'dart_sort_stable': true,
    'files': [
      {
        'path': 'lib/utils/listing_match_engine.dart',
        'function': 'ListingMatchEngine.rank',
        'note':
            'scored.sort comparator: preferenceScore → '
            'qualityTier → match.score; no listing-id breaker. Equal keys '
            'preserve relative order via Dart stable sort.',
      },
      {
        'path': 'lib/utils/weighted_listing_matcher.dart',
        'function': 'WeightedListingMatcher.fetchScoredListings',
        'note':
            'Sorts hard-pass pool by preference score only; equal preference '
            'scores keep filter-pass (input) order.',
      },
      {
        'path': 'lib/utils/marketplace_listing_pipeline.dart',
        'function': 'MarketplaceListingPipeline.runWithFilters',
        'note':
            'Builds weightedPool then calls ListingMatchEngine.rank; seed '
            'path starts from SampleListingsDublin.items construction order.',
      },
      {
        'path': 'lib/data/sample_listings_dublin_v2.dart',
        'function': 'SampleListingsDublinV2.items',
        'note':
            'Rebuilds unmodifiable list in fixed composition order each get; '
            'production demo path does not shuffle.',
      },
    ],
    'summary': anyShuffle
        ? 'Order among full-key ties is determined by upstream listing pool '
            'order (stable sort). Identical SampleListingsDublin rebuilds '
            'yield identical order; shuffled input can reorder ties.'
        : 'No reorder observed even under shuffled input for this sample; '
            'still no product-level listing-id breaker.',
  };

  final recommendedAction = (verdict == 'PASS' && !anyShuffle)
      ? 'Optional hardening: add deterministic listing-id (or created_at) '
          'final comparator in ListingMatchEngine.rank to remove latent '
          'input-order dependency before non-seed feeds.'
      : 'Decision: add a deterministic final tie-breaker (canonical '
          'listing id ascending) in ListingMatchEngine.rank after '
          'match.score, and mirror in WeightedListingMatcher preference '
          'sort if soft-score ties matter. Do not change production until '
          'explicitly approved. Priority driven by severity '
          '($severity).';

  return {
    'verdict': verdict,
    'severity': severity,
    'rationale': rationale,
    'aggregate_stability_percentage': aggregateStability,
    'seekers_fully_stable': fullyStable,
    'seekers_with_order_changes': withChanges,
    'any_top1_changed': anyTop1,
    'any_top5_changed': anyTop5,
    'any_tied_pair_swapped_in_top5': anyTiedSwap,
    'any_shuffled_input_reordered': anyShuffle,
    'any_shuffled_top1_changed': anyShuffleTop1,
    'any_shuffled_top5_changed': anyShuffleTop5,
    'root_cause': rootCause,
    'recommended_action': recommendedAction,
    'top5_analysis': {
      'top_result_changed_any_seeker': anyTop1,
      'top5_changed_any_seeker': anyTop5,
      'tied_pair_swapped_any_seeker': anyTiedSwap,
      'shuffled_input_top1_changed': anyShuffleTop1,
      'shuffled_input_top5_changed': anyShuffleTop5,
    },
  };
}

double _round1(double v) => (v * 10).roundToDouble() / 10.0;

String _markdown(Map<String, dynamic> payload) {
  final risk = payload['risk'] as Map<String, dynamic>;
  final summary = payload['summary'] as Map<String, dynamic>;
  final selection = payload['selection'] as Map<String, dynamic>;
  final root = payload['root_cause'] as Map<String, dynamic>;
  final top5 = payload['top5_analysis'] as Map<String, dynamic>;
  final perSeeker = (payload['per_seeker'] as List).cast<Map<String, dynamic>>();
  final seekers = (selection['seekers'] as List).cast<Map<String, dynamic>>();

  final buf = StringBuffer()
    ..writeln('# Ranking Tie Stability Audit')
    ..writeln()
    ..writeln('**Verdict: ${risk['verdict']}**')
    ..writeln()
    ..writeln('Severity: ${risk['severity']}')
    ..writeln()
    ..writeln(risk['rationale'])
    ..writeln()
    ..writeln('Audited at: `${payload['audited_at']}`')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| Metric | Value |')
    ..writeln('| --- | --- |')
    ..writeln('| Seekers audited | ${summary['seekers_audited']} |')
    ..writeln('| Runs per seeker | ${summary['runs_per_seeker']} |')
    ..writeln(
      '| Aggregate stability % | ${summary['aggregate_stability_percentage']} |',
    )
    ..writeln('| Fully stable seekers | ${summary['seekers_fully_stable']} |')
    ..writeln(
      '| Seekers with order changes | ${summary['seekers_with_order_changes']} |',
    )
    ..writeln('| Any top-1 changed | ${summary['any_top1_changed']} |')
    ..writeln('| Any top-5 changed | ${summary['any_top5_changed']} |')
    ..writeln(
      '| Any tied pair swapped in top-5 | ${summary['any_tied_pair_swapped_in_top5']} |',
    )
    ..writeln(
      '| Shuffled input reordered | ${summary['any_shuffled_input_reordered']} |',
    )
    ..writeln('| Dart List.sort stable | ${summary['dart_list_sort_stable']} |')
    ..writeln()
    ..writeln('## Part 1 — Test set selection')
    ..writeln()
    ..writeln(selection['criteria'])
    ..writeln()
    ..writeln('| Seeker | Marketplace | Role | Exact ties | Top-5 ties | Score |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  for (final s in seekers) {
    final range = s['justification_score_range'] as Map<String, dynamic>;
    buf.writeln(
      '| `${s['seeker_id']}` | ${s['marketplace']} | ${s['role']} | '
      '${s['justification_exact_score_tie_pairs']} | '
      '${s['justification_top5_exact_tie_pairs']} | '
      '${range['min']}-${range['max']} |',
    );
  }

  buf
    ..writeln()
    ..writeln('## Part 2 — Repeat execution')
    ..writeln()
    ..writeln(
      'Each seeker: **${summary['runs_per_seeker']}** identical runs via '
      '`MarketplaceListingPipeline.runWithFilters` → '
      '`WeightedListingMatcher.fetchScoredListings` → '
      '`ListingMatchEngine.rank`, rebuilding `SampleListingsDublin.items` '
      'each call (production-like seed path). Optional shuffled-input probe '
      'documents input-order dependency.',
    )
    ..writeln()
    ..writeln('## Part 3 — Per seeker metrics')
    ..writeln()
    ..writeln(
      '| Seeker | Runs | Identical | Different | Stability % | Tied pairs | Ties reordered |',
    )
    ..writeln('| --- | --- | --- | --- | --- | --- | --- |');
  for (final s in perSeeker) {
    buf.writeln(
      '| `${s['seeker_id']}` | ${s['total_runs']} | '
      '${s['identical_orders']} | ${s['different_orders']} | '
      '${s['stability_percentage']} | ${s['number_of_tied_results']} | '
      '${s['number_of_ties_reordered']} |',
    );
  }

  buf
    ..writeln()
    ..writeln('## Part 4 — Top-5 analysis')
    ..writeln()
    ..writeln('| Check | Result |')
    ..writeln('| --- | --- |')
    ..writeln(
      '| Top result changed (identical runs) | ${top5['top_result_changed_any_seeker']} |',
    )
    ..writeln(
      '| Top-5 changed (identical runs) | ${top5['top5_changed_any_seeker']} |',
    )
    ..writeln(
      '| Tied pair swapped in top-5 | ${top5['tied_pair_swapped_any_seeker']} |',
    )
    ..writeln(
      '| Shuffled input changed top-1 | ${top5['shuffled_input_top1_changed']} |',
    )
    ..writeln(
      '| Shuffled input changed top-5 | ${top5['shuffled_input_top5_changed']} |',
    )
    ..writeln()
    ..writeln('### Per-seeker top-5 / shuffle')
    ..writeln();
  for (final s in perSeeker) {
    final t = s['top5_analysis'] as Map<String, dynamic>;
    final sh = s['shuffled_input_probe'] as Map<String, dynamic>;
    buf
      ..writeln('#### `${s['seeker_id']}`')
      ..writeln()
      ..writeln(
        '- Baseline top-5: `${(t['baseline_top5'] as List).join(', ')}` '
        '(scores ${(t['baseline_top5_scores'] as List).join(', ')})',
      )
      ..writeln('- Tied listings switched: ${t['tied_listings_switched']}')
      ..writeln('- Top result changed: ${t['top_result_changed']}')
      ..writeln('- Top-5 order changed: ${t['top5_order_changed']}')
      ..writeln('- Tied pair swapped: ${t['tied_pair_swapped']}')
      ..writeln(
        '- Shuffled probe order changed: ${sh['order_changed_vs_baseline']} '
        '(top1=${sh['top1_changed']}, top5=${sh['top5_changed']}, '
        'ties_reordered=${sh['ties_reordered']})',
      )
      ..writeln();
  }

  buf
    ..writeln('## Part 5 — Root cause')
    ..writeln()
    ..writeln(root['summary'])
    ..writeln()
    ..writeln('| File | Function | Note |')
    ..writeln('| --- | --- | --- |');
  for (final f in (root['files'] as List).cast<Map<String, dynamic>>()) {
    buf.writeln('| `${f['path']}` | `${f['function']}` | ${f['note']} |');
  }

  buf
    ..writeln()
    ..writeln('- Identical-run instability: ${root['identical_run_instability']}')
    ..writeln(
      '- Input-order dependency detected: ${root['input_order_dependency_detected']}',
    )
    ..writeln(
      '- Missing listing-id final breaker: ${root['missing_listing_id_final_breaker']}',
    )
    ..writeln('- Score collisions present: ${root['score_collisions_present']}')
    ..writeln('- Dart sort stable: ${root['dart_sort_stable']}')
    ..writeln()
    ..writeln('## Part 6 — Risk')
    ..writeln()
    ..writeln('- **Verdict:** ${risk['verdict']}')
    ..writeln('- **Severity:** ${risk['severity']}')
    ..writeln()
    ..writeln('### Recommended action (decision only)')
    ..writeln()
    ..writeln(payload['recommended_action'])
    ..writeln()
    ..writeln('## Production code')
    ..writeln()
    ..writeln(
      'No production matching/ranking code was modified. '
      'Test-only harness: `test/ranking_tie_stability_audit_test.dart`.',
    );

  return buf.toString();
}
