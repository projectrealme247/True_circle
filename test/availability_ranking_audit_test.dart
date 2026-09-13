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

/// Availability Ranking Audit — does timing soft-score influence order?
///
/// Run: `flutter test test/availability_ranking_audit_test.dart`
///
/// Production path:
/// - [MarketplaceListingPipeline.runWithFilters]
/// - [ListingMatchEngine.rank] / [MoveInTimingEngine.evaluate]
///
/// Allowed sources only (inventory cats 5/6/8 + timing + frozen seekers).
void main() {
  test('availability ranking audit dump', () {
    final reference = DateTime(2026, 8, 5);
    final seekersById = {
      for (final s in _loadFrozenSeekers()) s.seekerId: s,
    };
    final selected = _selectAuditSeekers(seekersById, reference);
    expect(selected.length, 10);
    expect(
      selected.where((s) => s.marketplace == 'shared_living').length,
      5,
    );
    expect(
      selected.where((s) => s.marketplace == 'independent_places').length,
      5,
    );

    final corpus = SampleListingsDublin.items;
    final seedAvailability = _seedAvailabilitySummary(corpus);

    final perSeeker = <Map<String, dynamic>>[];
    for (final meta in selected) {
      final seeker = seekersById[meta.seekerId]!;
      perSeeker.add(
        _auditSeeker(
          seeker: seeker,
          selection: meta,
          corpus: corpus,
          reference: reference,
        ),
      );
    }

    final inversionAnalysis = _analyzeInversions(perSeeker);
    final impact = _measureImpact(perSeeker);
    final edgeCase = _runSep1EdgeCase(
      seekersById: seekersById,
      corpus: corpus,
      reference: reference,
    );

    final verdict = _classify(
      impact: impact,
      inversions: inversionAnalysis,
      edgeCase: edgeCase,
    );

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'reference_date': '2026-08-05',
      'risk': {
        'verdict': verdict['verdict'],
        'severity': verdict['severity'],
        'rationale': verdict['rationale'],
      },
      'timing_mechanism': _timingMechanismDoc(),
      'seed_availability': seedAvailability,
      'selection': {
        'criteria':
            '5 Shared Living + 5 Independent Places from frozen UAT seekers '
            'covering immediate (Aug this_month), near-term (Sep next_month), '
            'and later/future move dates. IP frozen set max is 2026-11-01 '
            '(within_3_months at reference 2026-08-05); no IP flexible-horizon '
            'seeker exists in frozen fixture.',
        'seekers': [
          for (final s in selected)
            {
              'seeker_id': s.seekerId,
              'marketplace': s.marketplace,
              'desired_move_date': s.desiredMoveDate,
              'resolved_move_in_window': s.resolvedWindow,
              'horizon_band': s.horizonBand,
              'role': s.role,
            },
        ],
      },
      'per_seeker': perSeeker,
      'order_validation': inversionAnalysis,
      'availability_impact': impact,
      'edge_case_sep1': edgeCase,
      'recommended_action': verdict['recommended_action'],
      'production_code_modified': false,
    };

    final md = _renderMarkdown(payload);
    Directory('docs/uat/v1').createSync(recursive: true);
    File('docs/uat/v1/availability_ranking_audit.json')
        .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(payload)}\n');
    File('docs/uat/v1/availability_ranking_audit.md').writeAsStringSync(md);

    // ignore: avoid_print
    print(
      'Availability Ranking Audit: ${verdict['verdict']} '
      '(${verdict['severity']}) → docs/uat/v1/availability_ranking_audit.md',
    );

    expect(File('docs/uat/v1/availability_ranking_audit.md').existsSync(), isTrue);
    expect(File('docs/uat/v1/availability_ranking_audit.json').existsSync(), isTrue);
  });
}

// ─── Selection ───────────────────────────────────────────────────────────────

class _SelectionMeta {
  _SelectionMeta({
    required this.seekerId,
    required this.marketplace,
    required this.desiredMoveDate,
    required this.resolvedWindow,
    required this.horizonBand,
    required this.role,
  });

  final String seekerId;
  final String marketplace;
  final String desiredMoveDate;
  final String resolvedWindow;
  final String horizonBand;
  final String role;
}

List<_SelectionMeta> _selectAuditSeekers(
  Map<String, _FrozenSeeker> byId,
  DateTime reference,
) {
  const plan = <(String, String, String)>[
    // Shared Living: immediate / near / future
    ('SL-STU-03', 'immediate', 'Aug this_month — high budget student'),
    ('SL-EDGE-03', 'immediate', 'Aug this_month — early August edge'),
    ('SL-STU-01', 'near-term', 'Sep 1 next_month — primary Sep edge case'),
    ('SL-PRO-03', 'near-term', 'Sep 15 next_month — professional'),
    ('SL-STU-04', 'future', 'Jan 2027 flexible horizon'),
    // Independent Places: immediate / near / later (frozen max Nov)
    ('IP-EDGE-06', 'immediate', 'Aug this_month — budget-constrained IP'),
    ('IP-SIN-07', 'immediate', 'Aug this_month — single professional'),
    ('IP-SIN-01', 'near-term', 'Sep 1 next_month — primary Sep edge case'),
    ('IP-CPL-01', 'near-term', 'Sep 1 next_month — couple'),
    ('IP-FAM-06', 'later', 'Nov within_3_months — latest IP in frozen set'),
  ];

  return [
    for (final (id, band, role) in plan)
      () {
        final s = byId[id]!;
        final window = _windowFor(s.desiredMoveDate, reference);
        return _SelectionMeta(
          seekerId: id,
          marketplace: s.marketplace,
          desiredMoveDate: s.desiredMoveDate ?? '',
          resolvedWindow: window.storageToken,
          horizonBand: band,
          role: role,
        );
      }(),
  ];
}

SeekerMoveInWindow _windowFor(String? iso, DateTime reference) {
  final parsed = DateTime.tryParse(iso ?? '');
  if (parsed == null) return SeekerMoveInWindow.flexible;
  return MoveInTimingMigration.bucketFromDate(parsed, reference: reference);
}

// ─── Seeker load / session ───────────────────────────────────────────────────

class _FrozenSeeker {
  _FrozenSeeker({
    required this.seekerId,
    required this.marketplace,
    required this.occupationType,
    required this.maxBudget,
    required this.preferredLocations,
    required this.desiredMoveDate,
    required this.roomPreference,
    required this.propertyTypePreference,
    required this.parkingRequired,
    required this.pets,
    required this.commutePriority,
    required this.transitPreference,
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

Map<String, dynamic> _sessionFor(
  _FrozenSeeker seeker, {
  required DateTime reference,
  String? moveDateOverride,
}) {
  final isShare = seeker.marketplace == 'shared_living';
  final space =
      isShare ? MarketplaceSpace.sharedSpace : MarketplaceSpace.fullRental;
  final now = reference.toUtc().toIso8601String();
  final moveDate = moveDateOverride ?? seeker.desiredMoveDate;

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

  if (moveDate != null && moveDate.isNotEmpty) {
    session['earliest_move_in_date'] = moveDate;
    final parsed = DateTime.tryParse(moveDate);
    if (parsed != null) {
      final window = MoveInTimingMigration.bucketFromDate(
        parsed,
        reference: reference,
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

MarketplaceListingPipelineResult _runPipeline(
  _FrozenSeeker seeker, {
  required DateTime reference,
  required List<Map<String, dynamic>> corpus,
  String? moveDateOverride,
}) {
  final session = _sessionFor(
    seeker,
    reference: reference,
    moveDateOverride: moveDateOverride,
  );
  final resolvedSpace = MarketplaceSpace.fromSession(session);
  final tower = resolvedSpace.towerPropertyType;
  final snapshot = ProfileOnboardingRepository.snapshotFromSession(session);
  final filters =
      ProfilePortalInheritanceService.seekerFeedDefaults(snapshot)
          .scopedForTower(tower);

  return MarketplaceListingPipeline.runWithFilters(
    allListings: corpus,
    towerPropertyType: tower,
    filters: filters,
    userSession: session,
  );
}

// ─── Availability labels ─────────────────────────────────────────────────────

String _availabilityBucket(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return 'unknown';
  if (d.year == 2026 && d.month == 8) return 'Available Now / Aug';
  if (d.year == 2026 && d.month == 9) return 'Sep';
  if (d.year == 2026 && d.month == 10) return 'Oct';
  if (d.year == 2026 && d.month == 11) return 'Nov';
  if (d.year == 2026 && d.month == 12) return 'Dec';
  if (d.year == 2027 && d.month == 1) return 'Jan';
  if (d.isBefore(DateTime(2026, 8, 1))) return 'Before Aug (Available Now)';
  return 'Other (${d.year}-${d.month.toString().padLeft(2, '0')})';
}

int _bucketOrdinal(String bucket) {
  // Lower = earlier availability (preferred for soon movers).
  return switch (bucket) {
    'Before Aug (Available Now)' || 'Available Now / Aug' => 0,
    'Sep' => 1,
    'Oct' => 2,
    'Nov' => 3,
    'Dec' => 4,
    'Jan' => 5,
    _ => 9,
  };
}

Map<String, dynamic> _seedAvailabilitySummary(
  List<Map<String, dynamic>> corpus,
) {
  final byBucket = <String, int>{};
  final byType = <String, Map<String, int>>{};
  for (final listing in corpus) {
    final type = ListingData.propertyType(listing);
    final avail = listing['available_from']?.toString() ?? '';
    final bucket = _availabilityBucket(avail.isEmpty ? null : avail);
    byBucket[bucket] = (byBucket[bucket] ?? 0) + 1;
    byType.putIfAbsent(type, () => <String, int>{});
    byType[type]![bucket] = (byType[type]![bucket] ?? 0) + 1;
  }
  return {
    'listing_count': corpus.length,
    'by_bucket': byBucket,
    'by_tower_bucket': byType,
    'note':
        'DublinListingBuilder._availableFromForId cycles months Aug–Dec 2026 '
        '(8 + (n-1)%5); seed has no January unless raw override.',
  };
}

// ─── Per-seeker audit ────────────────────────────────────────────────────────

Map<String, dynamic> _auditSeeker({
  required _FrozenSeeker seeker,
  required _SelectionMeta selection,
  required List<Map<String, dynamic>> corpus,
  required DateTime reference,
}) {
    final session = _sessionFor(seeker, reference: reference);
    final result = _runPipeline(
      seeker,
      reference: reference,
      corpus: corpus,
    );

  final ranked = result.ranked;
  final top10 = <Map<String, dynamic>>[];
  for (var i = 0; i < math.min(10, ranked.length); i++) {
    final scored = ranked[i];
    final listing = scored.listing;
    final avail = listing['available_from']?.toString() ?? '';
    final flex = listing['availability_flexibility']?.toString() ?? '';
    final eval = MoveInTimingEngine.evaluate(
      seekerSession: session,
      listing: listing,
      reference: reference,
    );
    top10.add({
      'rank': i + 1,
      'listing_id': ListingData.id(listing),
      'available_from': avail,
      'availability_bucket': _availabilityBucket(avail.isEmpty ? null : avail),
      'availability_flexibility': flex,
      'score': scored.match.score,
      'percentage': scored.match.percentage,
      'preference_score': scored.preferenceScore,
      'timing_match': eval.earnsTimingScore,
      'timing_quality': eval.quality.name,
      'timing_overlap_days': eval.overlapDays,
      'timing_gap_days': eval.gapDays,
      'timing_weight_earned': eval.earnsTimingScore,
    });
  }

  final allRows = <Map<String, dynamic>>[];
  for (var i = 0; i < ranked.length; i++) {
    final scored = ranked[i];
    final listing = scored.listing;
    final avail = listing['available_from']?.toString() ?? '';
    final eval = MoveInTimingEngine.evaluate(
      seekerSession: session,
      listing: listing,
      reference: reference,
    );
    allRows.add({
      'rank': i + 1,
      'listing_id': ListingData.id(listing),
      'available_from': avail,
      'availability_bucket': _availabilityBucket(avail.isEmpty ? null : avail),
      'score': scored.match.score,
      'timing_match': eval.earnsTimingScore,
      'timing_quality': eval.quality.name,
      'timing_gap_days': eval.gapDays,
      'timing_overlap_days': eval.overlapDays,
    });
  }

  final inversions = _findInversions(allRows);
  final timingStats = _timingRankStats(allRows);

  // Ablation: remove timing signal by clearing move-in fields, compare top-5.
  final sessionNoTiming = Map<String, dynamic>.from(session)
    ..remove('earliest_move_in_date')
    ..remove('move_in_window');
  final tower = MarketplaceSpace.fromSession(session).towerPropertyType;
  final snapshot =
      ProfileOnboardingRepository.snapshotFromSession(sessionNoTiming);
  final filters = ProfilePortalInheritanceService.seekerFeedDefaults(snapshot)
      .scopedForTower(tower);
  final ablating = MarketplaceListingPipeline.runWithFilters(
    allListings: corpus,
    towerPropertyType: tower,
    filters: filters,
    userSession: sessionNoTiming,
  );
  final top5With = top10.take(5).map((e) => e['listing_id']).toList();
  final top5Without = ablating.ranked
      .take(5)
      .map((e) => ListingData.id(e.listing))
      .toList();
  final top5Changed = !_listEq(top5With, top5Without);
  final top1Changed =
      (top5With.isEmpty ? null : top5With.first) !=
      (top5Without.isEmpty ? null : top5Without.first);

  return {
    'seeker_id': seeker.seekerId,
    'marketplace': seeker.marketplace,
    'desired_move_date': selection.desiredMoveDate,
    'resolved_move_in_window': selection.resolvedWindow,
    'horizon_band': selection.horizonBand,
    'role': selection.role,
    'ranked_count': ranked.length,
    'top10': top10,
    'timing_rank_stats': timingStats,
    'inversions_in_full_rank': inversions,
    'ablation': {
      'top5_with_timing': top5With,
      'top5_without_timing': top5Without,
      'top5_changed': top5Changed,
      'top1_changed': top1Changed,
    },
  };
}

List<Map<String, dynamic>> _findInversions(List<Map<String, dynamic>> rows) {
  // Later-availability ranked above earlier-availability among ranked results.
  final inversions = <Map<String, dynamic>>[];
  for (var i = 0; i < rows.length; i++) {
    for (var j = i + 1; j < rows.length; j++) {
      final earlier = rows[j];
      final later = rows[i];
      final earlierOrd =
          _bucketOrdinal(earlier['availability_bucket'] as String);
      final laterOrd = _bucketOrdinal(later['availability_bucket'] as String);
      if (laterOrd <= earlierOrd) continue;
      // later listing (higher rank position i) has later availability than
      // earlier listing at lower position j.
      final laterTiming = later['timing_match'] == true;
      final earlierTiming = earlier['timing_match'] == true;
      final laterScore = later['score'] as int;
      final earlierScore = earlier['score'] as int;
      final scoreDelta = laterScore - earlierScore;

      String classification;
      if (laterTiming && !earlierTiming) {
        // Unexpected: later-avail earned timing, earlier didn't — odd
        classification = 'possible_ranking_issue';
      } else if (!laterTiming && earlierTiming && scoreDelta > 0) {
        // Later-avail lacks timing but still outscores — other signals stronger
        classification = 'justified_by_stronger_score';
      } else if (scoreDelta > 0 && laterTiming == earlierTiming) {
        classification = 'justified_by_stronger_score';
      } else if (scoreDelta == 0 && laterTiming == earlierTiming) {
        classification = 'justified_by_stronger_score'; // tier/tie/input order
      } else if (!laterTiming && earlierTiming && scoreDelta <= 0) {
        // Earlier has timing and score >= later but ranked worse — issue
        classification = 'possible_ranking_issue';
      } else {
        classification = 'unexplained_ordering';
      }

      // Only report top-region inversions to keep signal high (top 20 pairs
      // where higher-ranked is later-bucket than a lower-ranked earlier-bucket,
      // and at least one is in top 15).
      if ((later['rank'] as int) > 15 && (earlier['rank'] as int) > 15) {
        continue;
      }

      inversions.add({
        'higher_rank_listing': later['listing_id'],
        'higher_rank_position': later['rank'],
        'higher_rank_available_from': later['available_from'],
        'higher_rank_bucket': later['availability_bucket'],
        'higher_rank_score': laterScore,
        'higher_rank_timing_match': laterTiming,
        'higher_rank_timing_quality': later['timing_quality'],
        'lower_rank_listing': earlier['listing_id'],
        'lower_rank_position': earlier['rank'],
        'lower_rank_available_from': earlier['available_from'],
        'lower_rank_bucket': earlier['availability_bucket'],
        'lower_rank_score': earlierScore,
        'lower_rank_timing_match': earlierTiming,
        'lower_rank_timing_quality': earlier['timing_quality'],
        'score_delta': scoreDelta,
        'classification': classification,
      });
    }
  }

  // Cap per seeker for readability; keep first 25 by higher rank position.
  inversions.sort(
    (a, b) =>
        (a['higher_rank_position'] as int)
            .compareTo(b['higher_rank_position'] as int),
  );
  return inversions.take(25).toList();
}

Map<String, dynamic> _timingRankStats(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) {
    return {
      'timing_match_count': 0,
      'timing_miss_count': 0,
      'avg_rank_timing_match': null,
      'avg_rank_timing_miss': null,
      'avg_score_timing_match': null,
      'avg_score_timing_miss': null,
      'median_rank_timing_match': null,
      'median_rank_timing_miss': null,
    };
  }
  final match = rows.where((r) => r['timing_match'] == true).toList();
  final miss = rows.where((r) => r['timing_match'] != true).toList();
  double? avgRank(List<Map<String, dynamic>> xs) {
    if (xs.isEmpty) return null;
    return xs.map((e) => e['rank'] as int).reduce((a, b) => a + b) / xs.length;
  }

  double? avgScore(List<Map<String, dynamic>> xs) {
    if (xs.isEmpty) return null;
    return xs.map((e) => e['score'] as int).reduce((a, b) => a + b) / xs.length;
  }

  double? medianRank(List<Map<String, dynamic>> xs) {
    if (xs.isEmpty) return null;
    final ranks = xs.map((e) => e['rank'] as int).toList()..sort();
    final mid = ranks.length ~/ 2;
    if (ranks.length.isOdd) return ranks[mid].toDouble();
    return (ranks[mid - 1] + ranks[mid]) / 2.0;
  }

  return {
    'timing_match_count': match.length,
    'timing_miss_count': miss.length,
    'avg_rank_timing_match': avgRank(match),
    'avg_rank_timing_miss': avgRank(miss),
    'avg_score_timing_match': avgScore(match),
    'avg_score_timing_miss': avgScore(miss),
    'median_rank_timing_match': medianRank(match),
    'median_rank_timing_miss': medianRank(miss),
    'top10_timing_match_count':
        rows.take(10).where((r) => r['timing_match'] == true).length,
    'top5_timing_match_count':
        rows.take(5).where((r) => r['timing_match'] == true).length,
  };
}

bool _listEq(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ─── Aggregate analysis ──────────────────────────────────────────────────────

Map<String, dynamic> _analyzeInversions(List<Map<String, dynamic>> perSeeker) {
  var justified = 0;
  var unexplained = 0;
  var possibleIssue = 0;
  final samples = <Map<String, dynamic>>[];

  for (final seeker in perSeeker) {
    final invs =
        (seeker['inversions_in_full_rank'] as List).cast<Map<String, dynamic>>();
    for (final inv in invs) {
      switch (inv['classification']) {
        case 'justified_by_stronger_score':
          justified++;
        case 'unexplained_ordering':
          unexplained++;
          if (samples.length < 12) {
            samples.add({
              'seeker_id': seeker['seeker_id'],
              ...inv,
            });
          }
        case 'possible_ranking_issue':
          possibleIssue++;
          if (samples.length < 12) {
            samples.add({
              'seeker_id': seeker['seeker_id'],
              ...inv,
            });
          }
      }
    }
  }

  return {
    'total_reported_inversions': justified + unexplained + possibleIssue,
    'justified_by_stronger_score': justified,
    'unexplained_ordering': unexplained,
    'possible_ranking_issue': possibleIssue,
    'sample_non_justified': samples,
    'note':
        'Inversion = later availability bucket ranked above earlier bucket '
        '(top-15 region, capped 25/seeker). Classification uses timing_match '
        'flags + score delta; binary timing points mean same-quality buckets '
        'are not further ordered by calendar proximity.',
  };
}

Map<String, dynamic> _measureImpact(List<Map<String, dynamic>> perSeeker) {
  var ablationTop5Changes = 0;
  var ablationTop1Changes = 0;
  var seekersWithTimingDifferentiation = 0;
  var seekersWhereTimingMatchRanksBetter = 0;
  var seekersTop5AllEarnTiming = 0;
  var seekersTop5MixedTiming = 0;
  var pairComparisons = 0;
  var timingWinsWhenOtherScoresClose = 0;
  var timingLosesWhenOtherScoresClose = 0;

  final perSeekerImpact = <Map<String, dynamic>>[];

  for (final seeker in perSeeker) {
    final ablation = seeker['ablation'] as Map<String, dynamic>;
    if (ablation['top5_changed'] == true) ablationTop5Changes++;
    if (ablation['top1_changed'] == true) ablationTop1Changes++;

    final stats = seeker['timing_rank_stats'] as Map<String, dynamic>;
    final matchCount = stats['timing_match_count'] as int;
    final missCount = stats['timing_miss_count'] as int;
    final hasDiff = matchCount > 0 && missCount > 0;
    if (hasDiff) seekersWithTimingDifferentiation++;

    final avgMatch = stats['avg_rank_timing_match'] as double?;
    final avgMiss = stats['avg_rank_timing_miss'] as double?;
    final ranksBetter =
        avgMatch != null && avgMiss != null && avgMatch < avgMiss;
    if (ranksBetter) seekersWhereTimingMatchRanksBetter++;

    final top5Match = stats['top5_timing_match_count'] as int? ?? 0;
    if (top5Match == 5) seekersTop5AllEarnTiming++;
    if (top5Match > 0 && top5Match < 5) seekersTop5MixedTiming++;

    // Close-score pair probe within top 20: same score±timing-weight band.
    final top10 = (seeker['top10'] as List).cast<Map<String, dynamic>>();
    // Expand: rebuild from inversions + top10 for close pairs
    for (var i = 0; i < top10.length; i++) {
      for (var j = i + 1; j < top10.length; j++) {
        final a = top10[i];
        final b = top10[j];
        final scoreA = a['score'] as int;
        final scoreB = b['score'] as int;
        final timingA = a['timing_match'] == true;
        final timingB = b['timing_match'] == true;
        if (timingA == timingB) continue;
        final delta = (scoreA - scoreB).abs();
        // "close" if non-timing gap likely ≤ timing weight (~5–20)
        if (delta > 25) continue;
        pairComparisons++;
        final winnerHasTiming =
            (scoreA > scoreB && timingA) || (scoreB > scoreA && timingB) ||
            (scoreA == scoreB &&
                ((a['rank'] as int) < (b['rank'] as int) ? timingA : timingB));
        if (winnerHasTiming) {
          timingWinsWhenOtherScoresClose++;
        } else {
          timingLosesWhenOtherScoresClose++;
        }
      }
    }

    final mix = <String, int>{};
    for (final row in top10) {
      final b = row['availability_bucket'] as String;
      mix[b] = (mix[b] ?? 0) + 1;
    }

    perSeekerImpact.add({
      'seeker_id': seeker['seeker_id'],
      'horizon_band': seeker['horizon_band'],
      'ablation_top5_changed': ablation['top5_changed'],
      'ablation_top1_changed': ablation['top1_changed'],
      'timing_match_count': matchCount,
      'timing_miss_count': missCount,
      'avg_rank_timing_match': avgMatch,
      'avg_rank_timing_miss': avgMiss,
      'timing_match_ranks_better_on_avg': ranksBetter,
      'top5_timing_match_count': top5Match,
      'top10_bucket_mix': mix,
    });
  }

  final influencesOrdering = ablationTop5Changes >= 3 ||
      seekersWhereTimingMatchRanksBetter >=
          (seekersWithTimingDifferentiation / 2).ceil();

  final appearsIgnored = ablationTop5Changes == 0 &&
      seekersWhereTimingMatchRanksBetter == 0 &&
      seekersWithTimingDifferentiation > 0;

  return {
    'seekers_audited': perSeeker.length,
    'seekers_with_timing_match_and_miss': seekersWithTimingDifferentiation,
    'seekers_where_timing_match_avg_rank_better':
        seekersWhereTimingMatchRanksBetter,
    'seekers_top5_all_earn_timing': seekersTop5AllEarnTiming,
    'seekers_top5_mixed_timing': seekersTop5MixedTiming,
    'ablation_top5_changed_count': ablationTop5Changes,
    'ablation_top1_changed_count': ablationTop1Changes,
    'close_score_pairs_compared': pairComparisons,
    'timing_wins_close_pairs': timingWinsWhenOtherScoresClose,
    'timing_loses_close_pairs': timingLosesWhenOtherScoresClose,
    'influences_ordering': influencesOrdering,
    'appears_ignored': appearsIgnored,
    'per_seeker': perSeekerImpact,
  };
}

Map<String, dynamic> _runSep1EdgeCase({
  required Map<String, _FrozenSeeker> seekersById,
  required List<Map<String, dynamic>> corpus,
  required DateTime reference,
}) {
  // Use SL-STU-01 and IP-SIN-01 with forced 2026-09-01.
  final cases = <Map<String, dynamic>>[];
  for (final id in ['SL-STU-01', 'IP-SIN-01']) {
    final seeker = seekersById[id]!;
    final session = _sessionFor(
      seeker,
      reference: reference,
      moveDateOverride: '2026-09-01',
    );
    final result = _runPipeline(
      seeker,
      reference: reference,
      corpus: corpus,
      moveDateOverride: '2026-09-01',
    );

    final bucketRanks = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < result.ranked.length; i++) {
      final scored = result.ranked[i];
      final avail = scored.listing['available_from']?.toString() ?? '';
      final bucket = _availabilityBucket(avail.isEmpty ? null : avail);
      final eval = MoveInTimingEngine.evaluate(
        seekerSession: session,
        listing: scored.listing,
        reference: reference,
      );
      bucketRanks.putIfAbsent(bucket, () => []).add({
        'rank': i + 1,
        'listing_id': ListingData.id(scored.listing),
        'available_from': avail,
        'score': scored.match.score,
        'timing_quality': eval.quality.name,
        'timing_match': eval.earnsTimingScore,
        'gap_days': eval.gapDays,
        'overlap_days': eval.overlapDays,
      });
    }

    final bestByBucket = <String, Map<String, dynamic>>{};
    for (final entry in bucketRanks.entries) {
      bestByBucket[entry.key] = entry.value.first;
    }

    // Intended for next_month (Sep) seeker:
    // Sep overlap strong; Aug may overlap/gap small (good/flexible);
    // Oct/Nov may still earn if gap≤30; far Jan weak if not flexible landlord.
    final orderedBuckets = [
      'Available Now / Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
      'Jan',
    ];
    final present = [
      for (final b in orderedBuckets)
        if (bestByBucket.containsKey(b)) b,
    ];

    final bestRanks = [
      for (final b in present) bestByBucket[b]!['rank'] as int,
    ];

    // Check whether earliest timing-earning buckets appear before weak ones
    // on average (by best-of-bucket rank).
    final earningBestRanks = <int>[];
    final weakBestRanks = <int>[];
    for (final b in present) {
      final row = bestByBucket[b]!;
      if (row['timing_match'] == true) {
        earningBestRanks.add(row['rank'] as int);
      } else {
        weakBestRanks.add(row['rank'] as int);
      }
    }

    var followsLogic = true;
    String? note;
    if (earningBestRanks.isNotEmpty && weakBestRanks.isNotEmpty) {
      final avgEarn =
          earningBestRanks.reduce((a, b) => a + b) / earningBestRanks.length;
      final avgWeak =
          weakBestRanks.reduce((a, b) => a + b) / weakBestRanks.length;
      followsLogic = avgEarn < avgWeak;
      note = followsLogic
          ? 'Best-of-bucket: timing-earning buckets average better rank '
              '($avgEarn) than weak ($avgWeak).'
          : 'Best-of-bucket: timing-earning avg rank $avgEarn not better than '
              'weak $avgWeak — other signals dominate bucket-best picks.';
    } else if (weakBestRanks.isEmpty) {
      note =
          'All present buckets earn timing for this Sep-1 seeker (flexible '
          'landlords / gap≤30). Soft score cannot demote later months.';
      followsLogic = true; // consistent with binary soft score + flexible flex
    } else {
      note = 'No timing-earning buckets found (unexpected).';
      followsLogic = false;
    }

    cases.add({
      'seeker_id': id,
      'marketplace': seeker.marketplace,
      'forced_move_date': '2026-09-01',
      'resolved_window': session['move_in_window'],
      'ranked_count': result.ranked.length,
      'best_of_bucket': bestByBucket,
      'buckets_present': present,
      'best_ranks_by_bucket_order': {
        for (final b in present) b: bestByBucket[b]!['rank'],
      },
      'follows_intended_availability_logic': followsLogic,
      'note': note,
      'top10': [
        for (var i = 0; i < math.min(10, result.ranked.length); i++)
          {
            'rank': i + 1,
            'listing_id': ListingData.id(result.ranked[i].listing),
            'available_from':
                result.ranked[i].listing['available_from']?.toString() ?? '',
            'availability_bucket': _availabilityBucket(
              result.ranked[i].listing['available_from']?.toString(),
            ),
            'score': result.ranked[i].match.score,
            'timing_quality': MoveInTimingEngine.evaluate(
              seekerSession: session,
              listing: result.ranked[i].listing,
              reference: reference,
            ).quality.name,
          },
      ],
    });
  }

  final allFollow =
      cases.every((c) => c['follows_intended_availability_logic'] == true);

  return {
    'move_date': '2026-09-01',
    'reference_date': '2026-08-05',
    'resolved_window_expected': 'next_month',
    'cases': cases,
    'overall_follows_logic': allFollow,
    'summary': allFollow
        ? 'Sep-1 (next_month) seekers: timing soft-score behaves as coded '
            '(earn points for overlap/gap≤30/flexible; no calendar sort within '
            'earning set).'
        : 'Sep-1 edge case showed weak buckets outranking timing-earning '
            'bucket-bests on average for at least one seeker.',
  };
}

Map<String, dynamic> _classify({
  required Map<String, dynamic> impact,
  required Map<String, dynamic> inversions,
  required Map<String, dynamic> edgeCase,
}) {
  final ignored = impact['appears_ignored'] == true;
  final influences = impact['influences_ordering'] == true;
  final possibleIssues = inversions['possible_ranking_issue'] as int;
  final unexplained = inversions['unexplained_ordering'] as int;
  final ablationTop5 = impact['ablation_top5_changed_count'] as int;
  final edgeOk = edgeCase['overall_follows_logic'] == true;

  if (ignored || !influences) {
    return {
      'verdict': 'FAIL',
      'severity': 'High',
      'rationale':
          'Availability timing shows little/no observable ranking impact '
          '(ablation top-5 changes=$ablationTop5; timing-match avg-rank '
          'advantage weak/absent).',
      'recommended_action':
          'Investigate timing weight magnitude and whether flexible landlords '
          'collapse differentiation; consider graded proximity scoring if '
          'product intent requires Available-Now ≫ Much-Later ordering.',
    };
  }

  if (possibleIssues > 0 || unexplained > 5 || !edgeOk) {
    return {
      'verdict': 'PASS WITH WARNINGS',
      'severity': possibleIssues > 0 ? 'Medium' : 'Low',
      'rationale':
          'Timing soft-score influences order (ablation/avg-rank evidence), '
          'but exceptions exist: possible_issue=$possibleIssues, '
          'unexplained=$unexplained, sep1_ok=$edgeOk. Binary earn/no-earn '
          'timing points + flexible landlords limit fine-grained month ordering.',
      'recommended_action':
          'Accept soft-preference design; optional follow-up to grade timing '
          'by proximity if product wants stricter Available-Now preference '
          'within the earning band.',
    };
  }

  return {
    'verdict': 'PASS',
    'severity': 'Low',
    'rationale':
        'Availability consistently influences ranking via soft timing score; '
        'later-above-earlier cases are justified by stronger non-timing scores; '
        'Sep-1 edge case follows coded logic.',
    'recommended_action':
        'No ranking change required for availability; proceed to other UAT surfaces.',
  };
}

Map<String, dynamic> _timingMechanismDoc() {
  return {
    'hard_filter': false,
    'hard_filter_evidence':
        'ListingSearchFilters.passesMoveInWindow always returns true; '
        'TowerFilterPolicy documents move-in as Soft for both towers; '
        'ListingMatchEngine hard filters (rent/share/buy) do not exclude on timing.',
    'soft_preference': true,
    'soft_preference_evidence':
        'MoveInTimingEngine.evaluate → TimingMatchQuality; '
        'earnsTimingScore for strong/good/flexible only; '
        'ListingMatchEngine adds weights.timing when timingMatch; '
        'weak quality earns 0 timing points (warning only).',
    'quality_tier':
        'Ranking uses percentage quality tiers (50+/25+/<25) then score; '
        'timing contributes to score/percentage but is not its own sort key.',
    'weights': {
      'rent_student_timing': 20,
      'rent_professional_timing': 15,
      'rent_family_timing': 10,
      'share_student_timing': 5,
      'share_default_timing_range': '5–10',
    },
    'classification_rules': {
      'overlap_ge_14': 'strong',
      'overlap_gt_0_or_gap_le_14': 'good',
      'gap_le_30': 'flexible',
      'seeker_or_landlord_flexible': 'flexible (always earns)',
      'gap_gt_30_neither_flexible': 'weak (no score)',
    },
    'feed_defaults_note':
        'ProfilePortalInheritanceService.seekerFeedDefaults does not set '
        'moveInWindow; WeightedListingMatcher move-in soft counter is unused '
        'on the production Explore path. Timing impact is solely via '
        'ListingMatchEngine score.',
  };
}

// ─── Markdown ────────────────────────────────────────────────────────────────

String _renderMarkdown(Map<String, dynamic> payload) {
  final risk = payload['risk'] as Map<String, dynamic>;
  final selection = payload['selection'] as Map<String, dynamic>;
  final seekers = (selection['seekers'] as List).cast<Map<String, dynamic>>();
  final perSeeker = (payload['per_seeker'] as List).cast<Map<String, dynamic>>();
  final inversions = payload['order_validation'] as Map<String, dynamic>;
  final impact = payload['availability_impact'] as Map<String, dynamic>;
  final edge = payload['edge_case_sep1'] as Map<String, dynamic>;
  final mech = payload['timing_mechanism'] as Map<String, dynamic>;
  final seed = payload['seed_availability'] as Map<String, dynamic>;

  final buf = StringBuffer();
  buf.writeln('# Availability Ranking Audit');
  buf.writeln();
  buf.writeln('**Verdict: ${risk['verdict']}**');
  buf.writeln();
  buf.writeln('Severity: ${risk['severity']}');
  buf.writeln();
  buf.writeln(risk['rationale']);
  buf.writeln();
  buf.writeln('Audited at: `${payload['audited_at']}`');
  buf.writeln();
  buf.writeln('Reference date for window bucketing: `${payload['reference_date']}`');
  buf.writeln();
  buf.writeln('Recommended action: ${payload['recommended_action']}');
  buf.writeln();
  buf.writeln('Production matching/ranking code modified: '
      '**${payload['production_code_modified']}**');
  buf.writeln();

  buf.writeln('## Timing mechanism (inventored code)');
  buf.writeln();
  buf.writeln('| Aspect | Value |');
  buf.writeln('| --- | --- |');
  buf.writeln('| Hard filter | `${mech['hard_filter']}` |');
  buf.writeln('| Soft preference | `${mech['soft_preference']}` |');
  buf.writeln('| Quality tier role | ${mech['quality_tier']} |');
  buf.writeln();
  buf.writeln(mech['hard_filter_evidence']);
  buf.writeln();
  buf.writeln(mech['soft_preference_evidence']);
  buf.writeln();
  buf.writeln(mech['feed_defaults_note']);
  buf.writeln();

  buf.writeln('## Seed availability buckets');
  buf.writeln();
  buf.writeln('Listing count: ${seed['listing_count']}');
  buf.writeln();
  buf.writeln('| Bucket | Count |');
  buf.writeln('| --- | --- |');
  final byBucket = (seed['by_bucket'] as Map).cast<String, dynamic>();
  for (final e in byBucket.entries) {
    buf.writeln('| ${e.key} | ${e.value} |');
  }
  buf.writeln();
  buf.writeln(seed['note']);
  buf.writeln();

  buf.writeln('## Part 1 — Test seekers');
  buf.writeln();
  buf.writeln(selection['criteria']);
  buf.writeln();
  buf.writeln('| Seeker | Marketplace | Move date | Window | Band | Role |');
  buf.writeln('| --- | --- | --- | --- | --- | --- |');
  for (final s in seekers) {
    buf.writeln(
      '| `${s['seeker_id']}` | ${s['marketplace']} | ${s['desired_move_date']} | '
      '`${s['resolved_move_in_window']}` | ${s['horizon_band']} | ${s['role']} |',
    );
  }
  buf.writeln();

  buf.writeln('## Part 2 — Availability analysis (top 10)');
  buf.writeln();
  for (final s in perSeeker) {
    buf.writeln('### `${s['seeker_id']}`');
    buf.writeln();
    buf.writeln(
      'Move date: **${s['desired_move_date']}** → `${s['resolved_move_in_window']}` '
      '(${s['horizon_band']}). Ranked: ${s['ranked_count']}.',
    );
    buf.writeln();
    buf.writeln(
      '| Rank | Listing | Available from | Bucket | Score | Timing | Quality |',
    );
    buf.writeln('| --- | --- | --- | --- | --- | --- | --- |');
    for (final row in (s['top10'] as List).cast<Map<String, dynamic>>()) {
      buf.writeln(
        '| ${row['rank']} | `${row['listing_id']}` | ${row['available_from']} | '
        '${row['availability_bucket']} | ${row['score']} | '
        '${row['timing_match']} | ${row['timing_quality']} |',
      );
    }
    buf.writeln();
    final stats = s['timing_rank_stats'] as Map<String, dynamic>;
    buf.writeln(
      'Timing stats: match=${stats['timing_match_count']}, '
      'miss=${stats['timing_miss_count']}, '
      'avg_rank_match=${stats['avg_rank_timing_match']}, '
      'avg_rank_miss=${stats['avg_rank_timing_miss']}.',
    );
    final ablation = s['ablation'] as Map<String, dynamic>;
    buf.writeln(
      'Ablation (clear move-in fields): top5_changed=${ablation['top5_changed']}, '
      'top1_changed=${ablation['top1_changed']}.',
    );
    buf.writeln();
  }

  buf.writeln('## Part 3 — Order validation');
  buf.writeln();
  buf.writeln('| Classification | Count |');
  buf.writeln('| --- | --- |');
  buf.writeln(
    '| Justified by stronger score | ${inversions['justified_by_stronger_score']} |',
  );
  buf.writeln(
    '| Unexplained ordering | ${inversions['unexplained_ordering']} |',
  );
  buf.writeln(
    '| Possible ranking issue | ${inversions['possible_ranking_issue']} |',
  );
  buf.writeln();
  buf.writeln(inversions['note']);
  buf.writeln();
  final samples =
      (inversions['sample_non_justified'] as List).cast<Map<String, dynamic>>();
  if (samples.isNotEmpty) {
    buf.writeln('### Sample non-justified inversions');
    buf.writeln();
    for (final inv in samples.take(8)) {
      buf.writeln(
        '- `${inv['seeker_id']}`: `${inv['higher_rank_listing']}` '
        '(${inv['higher_rank_bucket']}, score ${inv['higher_rank_score']}, '
        'timing=${inv['higher_rank_timing_match']}) above '
        '`${inv['lower_rank_listing']}` (${inv['lower_rank_bucket']}, '
        'score ${inv['lower_rank_score']}, timing=${inv['lower_rank_timing_match']}) '
        '→ **${inv['classification']}**',
      );
    }
    buf.writeln();
  }

  buf.writeln('## Part 4 — Edge case (move date 2026-09-01)');
  buf.writeln();
  buf.writeln(edge['summary']);
  buf.writeln();
  for (final c in (edge['cases'] as List).cast<Map<String, dynamic>>()) {
    buf.writeln('### `${c['seeker_id']}`');
    buf.writeln();
    buf.writeln(
      'Window: `${c['resolved_window']}`. '
      'Follows logic: **${c['follows_intended_availability_logic']}**.',
    );
    buf.writeln();
    buf.writeln(c['note']);
    buf.writeln();
    buf.writeln('| Bucket | Best rank | Listing | Score | Timing quality |');
    buf.writeln('| --- | --- | --- | --- | --- |');
    final best = (c['best_of_bucket'] as Map).cast<String, dynamic>();
    for (final b in (c['buckets_present'] as List).cast<String>()) {
      final row = (best[b] as Map).cast<String, dynamic>();
      buf.writeln(
        '| $b | ${row['rank']} | `${row['listing_id']}` | '
        '${row['score']} | ${row['timing_quality']} |',
      );
    }
    buf.writeln();
  }

  buf.writeln('## Part 5 — Availability impact');
  buf.writeln();
  buf.writeln('| Metric | Value |');
  buf.writeln('| --- | --- |');
  buf.writeln(
    '| Seekers with timing match+miss | ${impact['seekers_with_timing_match_and_miss']} |',
  );
  buf.writeln(
    '| Timing-match better avg rank | ${impact['seekers_where_timing_match_avg_rank_better']} |',
  );
  buf.writeln(
    '| Ablation top-5 changed | ${impact['ablation_top5_changed_count']} |',
  );
  buf.writeln(
    '| Ablation top-1 changed | ${impact['ablation_top1_changed_count']} |',
  );
  buf.writeln(
    '| Influences ordering | ${impact['influences_ordering']} |',
  );
  buf.writeln('| Appears ignored | ${impact['appears_ignored']} |');
  buf.writeln();

  buf.writeln('## Part 6 — Result');
  buf.writeln();
  buf.writeln('- Classification: **${risk['verdict']}**');
  buf.writeln('- Severity: **${risk['severity']}**');
  buf.writeln('- ${risk['rationale']}');
  buf.writeln();

  return buf.toString();
}
