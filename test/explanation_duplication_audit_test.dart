import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/models/move_in_timing.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/services/active_mode_service.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/utils/viewer_profile.dart';

/// Explanation Duplication Audit — measure uniqueness of
/// "Why this could work for you" across top listings per seeker.
///
/// Run: `flutter test test/explanation_duplication_audit_test.dart`
///
/// Production paths (read-only):
/// - [MarketplaceListingPipeline.runWithFilters]
/// - [ListingMatchEngine.sharedLivingPreferenceExplanations]
/// - [ListingMatchEngine.independentPlacePreferenceExplanations]
void main() {
  test('explanation duplication audit dump', () {
    final corpus = SampleListingsDublin.items;
    final shareCount =
        corpus.where((l) => ListingData.listingType(l) == 'Share').length;
    final rentCount =
        corpus.where((l) => ListingData.listingType(l) == 'Rent').length;

    final seekerResults = <Map<String, dynamic>>[
      for (final seeker in _auditSeekers) _runSeeker(seeker, corpus),
    ];

    final findings = _collectFindings(seekerResults);
    final blockers = findings['blocker']!;
    final highs = findings['high']!;
    final mediums = findings['medium']!;

    final avgDup = seekerResults.isEmpty
        ? 0.0
        : seekerResults
                .map((s) => (s['duplicate_percentage'] as num).toDouble())
                .reduce((a, b) => a + b) /
            seekerResults.length;
    final avgNearDup = seekerResults.isEmpty
        ? 0.0
        : seekerResults
                .map((s) => (s['near_duplicate_percentage'] as num).toDouble())
                .reduce((a, b) => a + b) /
            seekerResults.length;
    final avgUnique = seekerResults.isEmpty
        ? 0.0
        : seekerResults
                .map((s) => (s['unique_explanations'] as num).toDouble())
                .reduce((a, b) => a + b) /
            seekerResults.length;

    final identicalHeavyCount = seekerResults
        .where((s) => (s['max_exact_cluster_size'] as int) >= 7)
        .length;

    final String overall;
    if (avgDup > 70.0 || identicalHeavyCount >= 3) {
      overall = 'FAIL';
    } else if (avgDup >= 40.0 || identicalHeavyCount >= 1) {
      overall = 'PASS WITH WARNINGS';
    } else {
      overall = 'PASS';
    }

    // Escalate if blockers present from quality review.
    final effectiveOverall = blockers.isNotEmpty
        ? 'FAIL'
        : (highs.isNotEmpty && overall == 'PASS'
            ? 'PASS WITH WARNINGS'
            : overall);

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'overall': effectiveOverall,
      'overall_pass': effectiveOverall == 'PASS',
      'thresholds': {
        'fail_avg_duplicate_pct_gt': 70,
        'fail_identical_cluster_ge_7_seekers_ge': 3,
        'warn_avg_duplicate_pct_range': [40, 70],
        'near_duplicate_definition':
            'Two explanations are near-duplicates when not exact-equal after '
            'normalization, but Jaccard similarity of reason-type sets ≥ 0.8. '
            'Reason types are category keys (budget, bedrooms, availability, '
            'commute, location, property_type, household, room, bathroom, '
            'lifestyle) derived from known preference-explanation templates. '
            'Exact duplicates: identical after trim + whitespace collapse + '
            'emoji/symbol strip.',
        'duplicate_percentage_formula':
            '(total_listings_reviewed - unique_explanations) / '
            'total_listings_reviewed * 100',
      },
      'summary': {
        'overall': effectiveOverall,
        'seekers_tested': seekerResults.length,
        'shared_living_seekers':
            seekerResults.where((s) => s['marketplace'] == 'shared_living').length,
        'independent_places_seekers': seekerResults
            .where((s) => s['marketplace'] == 'independent_places')
            .length,
        'average_duplicate_percentage':
            double.parse(avgDup.toStringAsFixed(1)),
        'average_near_duplicate_percentage':
            double.parse(avgNearDup.toStringAsFixed(1)),
        'average_unique_explanations':
            double.parse(avgUnique.toStringAsFixed(2)),
        'seekers_with_identical_cluster_ge_7': identicalHeavyCount,
        'findings': {
          'blocker': blockers.length,
          'high': highs.length,
          'medium': mediums.length,
        },
      },
      'per_seeker': [
        for (final s in seekerResults)
          {
            'seeker_id': s['seeker_id'],
            'marketplace': s['marketplace'],
            'match_volume_tier': s['match_volume_tier'],
            'matches_returned': s['matches_returned'],
            'total_listings_reviewed': s['total_listings_reviewed'],
            'unique_explanations': s['unique_explanations'],
            'duplicate_explanations': s['duplicate_explanations'],
            'duplicate_percentage': s['duplicate_percentage'],
            'near_unique_signatures': s['near_unique_signatures'],
            'near_duplicate_percentage': s['near_duplicate_percentage'],
            'max_exact_cluster_size': s['max_exact_cluster_size'],
          },
      ],
      'findings': {
        'blocker': blockers,
        'high': highs,
        'medium': mediums,
      },
      'duplicate_pairs_examples': _collectDuplicatePairExamples(seekerResults),
      'seekers': seekerResults,
      'methodology': {
        'active_mode': ActiveMode.explore.storageToken,
        'code_paths': [
          'MarketplaceSpace.fromSession',
          'MarketplaceListingPipeline.runWithFilters (tower → rank)',
          'ListingMatchEngine.sharedLivingPreferenceExplanations',
          'ListingMatchEngine.independentPlacePreferenceExplanations',
        ],
        'listing_corpus': {
          'name': 'SampleListingsDublin',
          'shared_living_count': shareCount,
          'independent_places_count': rentCount,
          'total': corpus.length,
        },
        'top_n': 10,
        'sources': [
          'docs/uat/v1/implementation_file_inventory.md',
          'inventory categories 5, 6, 7, 8, 11, 12 (execution only)',
        ],
        'production_code_modified': false,
      },
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/explanation_duplication_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/explanation_duplication_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'EXPLANATION_DUPLICATION_AUDIT overall=$effectiveOverall '
      'avg_dup=${avgDup.toStringAsFixed(1)}% '
      'avg_near=${avgNearDup.toStringAsFixed(1)}% '
      'identical_ge7=$identicalHeavyCount '
      'blocker=${blockers.length} high=${highs.length} medium=${mediums.length}',
    );

    expect(seekerResults.length, 10);
    expect(corpus.length, 90);
    for (final s in seekerResults) {
      expect(s['marketplace_correct'], 'YES',
          reason: '${s['seeker_id']} marketplace isolation failed');
    }
  });
}

// ── Seeker definitions ───────────────────────────────────────────────────────

class _AuditSeeker {
  const _AuditSeeker({
    required this.seekerId,
    required this.marketplace,
    required this.intendedVolume,
    required this.scenario,
    required this.maxBudget,
    required this.preferredLocations,
    required this.occupationType,
    this.roomPreference,
    this.bathroomPreference,
    this.propertyTypePreference,
    this.preferredLayout,
    this.foodPreference = 'No Preference',
    this.desiredMoveDate = '2026-10-01',
    this.commuteHubId,
    this.commuteMaxMinutes,
  });

  final String seekerId;
  final String marketplace;
  final String intendedVolume; // many | medium | limited
  final String scenario;
  final int maxBudget;
  final List<String> preferredLocations;
  final String occupationType;
  final String? roomPreference;
  final String? bathroomPreference;
  final String? propertyTypePreference;
  final String? preferredLayout;
  final String foodPreference;
  final String? desiredMoveDate;
  final String? commuteHubId;
  final int? commuteMaxMinutes;
}

/// 5 Shared Living + 5 Independent Places covering many / medium / limited.
const _auditSeekers = <_AuditSeeker>[
  // ── Shared Living ──────────────────────────────────────────────────────────
  _AuditSeeker(
    seekerId: 'SL-DUP-MANY-01',
    marketplace: 'shared_living',
    intendedVolume: 'many',
    scenario:
        'Professional · high budget · broad Dublin · private room · ensuite',
    maxBudget: 1100,
    preferredLocations: [
      'Dublin 1',
      'Dublin 2',
      'Dublin 3',
      'Dublin 4',
      'Dublin 6',
      'Dublin 7',
      'Dublin 8',
      'Dublin 12',
    ],
    occupationType: 'professional',
    roomPreference: 'private',
    bathroomPreference: 'private_bathroom',
    foodPreference: 'Non-veg',
    desiredMoveDate: '2026-09-15',
  ),
  _AuditSeeker(
    seekerId: 'SL-DUP-MED-02',
    marketplace: 'shared_living',
    intendedVolume: 'medium',
    scenario: 'Student · medium budget · southside · shared room',
    maxBudget: 650,
    preferredLocations: ['Dublin 6', 'Dublin 8', 'Dublin 12', 'Rathmines'],
    occupationType: 'student',
    roomPreference: 'shared',
    bathroomPreference: 'shared_bathroom',
    foodPreference: 'Vegetarian',
    desiredMoveDate: '2026-09-01',
    commuteHubId: 'ucd',
    commuteMaxMinutes: 45,
  ),
  _AuditSeeker(
    seekerId: 'SL-DUP-LIM-03',
    marketplace: 'shared_living',
    intendedVolume: 'limited',
    scenario: 'Professional · tight budget · narrow northside · private',
    maxBudget: 480,
    preferredLocations: ['Dublin 1', 'Dublin 7'],
    occupationType: 'professional',
    roomPreference: 'private',
    bathroomPreference: 'private_bathroom',
    foodPreference: 'Non-veg',
    desiredMoveDate: '2026-11-01',
  ),
  _AuditSeeker(
    seekerId: 'SL-DUP-MED-04',
    marketplace: 'shared_living',
    intendedVolume: 'medium',
    scenario: 'Professional · mid budget · city core · any bathroom · veg',
    maxBudget: 750,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6'],
    occupationType: 'professional',
    roomPreference: 'private',
    foodPreference: 'Veg',
    desiredMoveDate: '2026-10-01',
    commuteHubId: 'grand_canal_dock',
    commuteMaxMinutes: 60,
  ),
  _AuditSeeker(
    seekerId: 'SL-DUP-LIM-05',
    marketplace: 'shared_living',
    intendedVolume: 'limited',
    scenario: 'Student · low budget · single area · shared · no move date',
    maxBudget: 500,
    preferredLocations: ['Dublin 8'],
    occupationType: 'student',
    roomPreference: 'shared',
    bathroomPreference: 'no_preference',
    foodPreference: 'No Preference',
    desiredMoveDate: null,
  ),
  // ── Independent Places ─────────────────────────────────────────────────────
  _AuditSeeker(
    seekerId: 'IP-DUP-MANY-01',
    marketplace: 'independent_places',
    intendedVolume: 'many',
    scenario: 'Couple · premium budget · broad southside · any property',
    maxBudget: 4500,
    preferredLocations: [
      'Dublin 2',
      'Dublin 4',
      'Dublin 6',
      'Blackrock',
      'Ballsbridge',
      'Ranelagh',
    ],
    occupationType: 'couple',
    propertyTypePreference: 'any',
    preferredLayout: '2',
    desiredMoveDate: '2026-09-01',
  ),
  _AuditSeeker(
    seekerId: 'IP-DUP-MED-02',
    marketplace: 'independent_places',
    intendedVolume: 'medium',
    scenario: 'Professional · mid budget · apartment · 1+ bed · commute TCD',
    maxBudget: 2200,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 8'],
    occupationType: 'professional',
    propertyTypePreference: 'apartment',
    preferredLayout: '1',
    desiredMoveDate: '2026-10-01',
    commuteHubId: 'tcd',
    commuteMaxMinutes: 40,
  ),
  _AuditSeeker(
    seekerId: 'IP-DUP-LIM-03',
    marketplace: 'independent_places',
    intendedVolume: 'limited',
    scenario: 'Family · tight budget · house · 3+ bed · outer suburbs',
    maxBudget: 1600,
    preferredLocations: ['Dublin 15', 'Swords', 'Blanchardstown'],
    occupationType: 'family',
    propertyTypePreference: 'house',
    preferredLayout: '3',
    desiredMoveDate: '2026-11-01',
  ),
  _AuditSeeker(
    seekerId: 'IP-DUP-MED-04',
    marketplace: 'independent_places',
    intendedVolume: 'medium',
    scenario: 'Couple · upper-mid · house preferred · 2+ bed · IFSC commute',
    maxBudget: 2800,
    preferredLocations: ['Dublin 1', 'Dublin 3', 'Dublin 7', 'Dublin 9'],
    occupationType: 'couple',
    propertyTypePreference: 'house',
    preferredLayout: '2',
    desiredMoveDate: '2026-09-20',
    commuteHubId: 'ifsc_docklands',
    commuteMaxMinutes: 50,
  ),
  _AuditSeeker(
    seekerId: 'IP-DUP-LIM-05',
    marketplace: 'independent_places',
    intendedVolume: 'limited',
    scenario: 'Professional · low-mid · apartment · studio/1 · narrow area',
    maxBudget: 1500,
    preferredLocations: ['Dublin 8'],
    occupationType: 'professional',
    propertyTypePreference: 'apartment',
    preferredLayout: '1',
    desiredMoveDate: '2026-12-01',
  ),
];

// ── Session / pipeline ───────────────────────────────────────────────────────

Map<String, dynamic> _sessionFor(_AuditSeeker seeker) {
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
    'food_preference': seeker.foodPreference,
    'budget_max': seeker.maxBudget,
    'preferred_property_type': space.towerPropertyType,
    'preferred_arrangement': space.arrangementBackend,
    'active_marketplace_space': space.storageToken,
    'profile_onboarding_track': isShare
        ? 'seeker_shared_space'
        : 'seeker_entire_place',
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
  } else if (seeker.preferredLayout != null &&
      seeker.preferredLayout!.isNotEmpty) {
    session['preferred_layout'] = seeker.preferredLayout;
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
    }
  }

  if (seeker.bathroomPreference != null) {
    session[BathroomPreference.sessionKey] = seeker.bathroomPreference;
  }

  if (seeker.commuteHubId != null) {
    session['commute_destination_unknown'] = false;
    session['commute_destination_hub_id'] = seeker.commuteHubId;
    session['maximum_commute_budget_minutes'] =
        seeker.commuteMaxMinutes ?? 60;
    session['commute_method'] = 'public_transport';
  } else {
    session['commute_destination_unknown'] = true;
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

String _volumeTier(int matchCount) {
  if (matchCount >= 20) return 'many';
  if (matchCount >= 8) return 'medium';
  if (matchCount >= 1) return 'limited';
  return 'zero';
}

Map<String, dynamic> _runSeeker(
  _AuditSeeker seeker,
  List<Map<String, dynamic>> corpus,
) {
  final session = _sessionFor(seeker);
  final viewer = ViewerProfile.fromSession(session);
  final resolvedSpace = MarketplaceSpace.fromSession(session);
  final tower = resolvedSpace.towerPropertyType;
  final marketplaceRequested = seeker.marketplace;
  final marketplaceFromSession = resolvedSpace == MarketplaceSpace.sharedSpace
      ? 'shared_living'
      : 'independent_places';

  final filters = ListingSearchFilters(budgetMax: seeker.maxBudget);
  final pipeline = MarketplaceListingPipeline.runWithFilters(
    allListings: corpus,
    towerPropertyType: tower,
    filters: filters,
    userSession: session,
  );

  final top = pipeline.ranked.take(10).toList();
  final listingRows = <Map<String, dynamic>>[];

  for (final scored in top) {
    final listing = scored.listing;
    final listingId = ListingData.id(listing);
    final listingMp = ListingData.listingType(listing) == 'Share'
        ? 'shared_living'
        : 'independent_places';

    final explanations = marketplaceRequested == 'shared_living'
        ? ListingMatchEngine.sharedLivingPreferenceExplanations(
            listing,
            viewer,
            viewerSession: session,
          )
        : ListingMatchEngine.independentPlacePreferenceExplanations(
            listing,
            viewer,
            viewerSession: session,
          );

    final joined = explanations.join(' | ');
    final exactKey = _normalizeExact(joined);
    final types = _reasonTypes(explanations);
    final typeSig = (types.toList()..sort()).join('+');

    listingRows.add({
      'listing_id': listingId,
      'marketplace': listingMp,
      'title': ListingData.title(listing),
      'area': ListingData.location(listing),
      'price': ListingData.price(listing),
      'score': scored.match.score,
      'explanations': explanations,
      'joined_explanation': joined,
      'exact_key': exactKey,
      'reason_types': types.toList()..sort(),
      'reason_type_signature': typeSig,
    });
  }

  final metrics = _duplicationMetrics(listingRows);
  final bleed = [
    for (final row in listingRows)
      if (row['marketplace'] != marketplaceRequested)
        row['listing_id'] as String,
  ];

  return {
    'seeker_id': seeker.seekerId,
    'marketplace': marketplaceRequested,
    'marketplace_from_session': marketplaceFromSession,
    'marketplace_correct':
        marketplaceFromSession == marketplaceRequested && bleed.isEmpty
            ? 'YES'
            : 'NO',
    'intended_volume': seeker.intendedVolume,
    'match_volume_tier': _volumeTier(pipeline.ranked.length),
    'scenario': seeker.scenario,
    'max_budget': seeker.maxBudget,
    'preferred_locations': seeker.preferredLocations,
    'matches_returned': pipeline.ranked.length,
    'total_listings_reviewed': listingRows.length,
    'unique_explanations': metrics['unique_explanations'],
    'duplicate_explanations': metrics['duplicate_explanations'],
    'duplicate_percentage': metrics['duplicate_percentage'],
    'near_unique_signatures': metrics['near_unique_signatures'],
    'near_duplicate_percentage': metrics['near_duplicate_percentage'],
    'max_exact_cluster_size': metrics['max_exact_cluster_size'],
    'exact_clusters': metrics['exact_clusters'],
    'near_clusters': metrics['near_clusters'],
    'top_listings': listingRows,
    'pipeline_stages': {
      'corpus': corpus.length,
      'after_tower': pipeline.afterTower.length,
      'after_filters': pipeline.afterFilters.length,
      'ranked': pipeline.ranked.length,
    },
  };
}

// ── Normalization / similarity ───────────────────────────────────────────────

final _emojiOrSymbol = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\uFE0F\u200D💰🛏️📅🚆📍🏠👨👩🎓💼🏡🚿🍴✅⚠️≡ƒ]',
  unicode: true,
);

String _normalizeExact(String raw) {
  var s = raw.trim().toLowerCase();
  s = s.replaceAll(_emojiOrSymbol, '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Map preference explanation lines → stable reason-type keys.
Set<String> _reasonTypes(List<String> explanations) {
  final types = <String>{};
  for (final line in explanations) {
    final lower = line.toLowerCase();
    if (lower.contains('budget') || lower.contains('good value')) {
      types.add('budget');
    } else if (lower.contains('bedroom')) {
      types.add('bedrooms');
    } else if (lower.contains('available when you plan to move') ||
        lower.contains('plan to move')) {
      types.add('availability');
    } else if (lower.contains('commute')) {
      types.add('commute');
    } else if (lower.contains('preferred area') ||
        lower.contains('location')) {
      types.add('location');
    } else if (lower.contains('property type')) {
      types.add('property_type');
    } else if (lower.contains('household') ||
        lower.contains('student household') ||
        lower.contains('professional household') ||
        lower.contains('suitable for your household')) {
      types.add('household');
    } else if (lower.contains('private room') ||
        lower.contains('shared room')) {
      types.add('room');
    } else if (lower.contains('bathroom')) {
      types.add('bathroom');
    } else if (lower.contains('lifestyle')) {
      types.add('lifestyle');
    } else if (lower.trim().isNotEmpty) {
      types.add('other:${_normalizeExact(line)}');
    }
  }
  return types;
}

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final inter = a.intersection(b).length;
  final union = a.union(b).length;
  return union == 0 ? 0.0 : inter / union;
}

Map<String, dynamic> _duplicationMetrics(List<Map<String, dynamic>> rows) {
  final n = rows.length;
  if (n == 0) {
    return {
      'unique_explanations': 0,
      'duplicate_explanations': 0,
      'duplicate_percentage': 0.0,
      'near_unique_signatures': 0,
      'near_duplicate_percentage': 0.0,
      'max_exact_cluster_size': 0,
      'exact_clusters': <Map<String, dynamic>>[],
      'near_clusters': <Map<String, dynamic>>[],
    };
  }

  final byExact = <String, List<String>>{};
  for (final row in rows) {
    final key = row['exact_key'] as String;
    byExact.putIfAbsent(key, () => []).add(row['listing_id'] as String);
  }

  final unique = byExact.length;
  final duplicateExtras = n - unique;
  final dupPct = (duplicateExtras / n) * 100.0;
  var maxCluster = 0;
  final exactClusters = <Map<String, dynamic>>[];
  for (final e in byExact.entries) {
    maxCluster = math.max(maxCluster, e.value.length);
    if (e.value.length >= 2) {
      exactClusters.add({
        'exact_key': e.key,
        'count': e.value.length,
        'listing_ids': e.value,
        'sample_joined': rows
            .firstWhere((r) => r['exact_key'] == e.key)['joined_explanation'],
      });
    }
  }
  exactClusters.sort(
    (a, b) => (b['count'] as int).compareTo(a['count'] as int),
  );

  // Near-dup: cluster by reason-type signature; also pair Jaccard ≥ 0.8.
  final bySig = <String, List<String>>{};
  for (final row in rows) {
    final sig = row['reason_type_signature'] as String;
    bySig.putIfAbsent(sig, () => []).add(row['listing_id'] as String);
  }
  final nearUnique = bySig.length;
  final nearExtras = n - nearUnique;
  final nearPct = (nearExtras / n) * 100.0;

  final nearClusters = <Map<String, dynamic>>[];
  for (final e in bySig.entries) {
    if (e.value.length >= 2) {
      nearClusters.add({
        'reason_type_signature': e.key.isEmpty ? '(empty)' : e.key,
        'count': e.value.length,
        'listing_ids': e.value,
      });
    }
  }
  nearClusters.sort(
    (a, b) => (b['count'] as int).compareTo(a['count'] as int),
  );

  // Pairwise near-dup count (for quality notes).
  var nearPairCount = 0;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final a = (rows[i]['reason_types'] as List).cast<String>().toSet();
      final b = (rows[j]['reason_types'] as List).cast<String>().toSet();
      final exactSame =
          rows[i]['exact_key'] == rows[j]['exact_key'];
      if (!exactSame && _jaccard(a, b) >= 0.8) {
        nearPairCount++;
      }
    }
  }

  return {
    'unique_explanations': unique,
    'duplicate_explanations': duplicateExtras,
    'duplicate_percentage': double.parse(dupPct.toStringAsFixed(1)),
    'near_unique_signatures': nearUnique,
    'near_duplicate_percentage': double.parse(nearPct.toStringAsFixed(1)),
    'max_exact_cluster_size': maxCluster,
    'near_pair_count_jaccard_ge_0_8': nearPairCount,
    'exact_clusters': exactClusters,
    'near_clusters': nearClusters,
  };
}

// ── Findings ─────────────────────────────────────────────────────────────────

Map<String, List<Map<String, dynamic>>> _collectFindings(
  List<Map<String, dynamic>> seekers,
) {
  final blockers = <Map<String, dynamic>>[];
  final highs = <Map<String, dynamic>>[];
  final mediums = <Map<String, dynamic>>[];

  for (final s in seekers) {
    final id = s['seeker_id'] as String;
    final reviewed = s['total_listings_reviewed'] as int;
    final unique = s['unique_explanations'] as int;
    final dupPct = (s['duplicate_percentage'] as num).toDouble();
    final maxCluster = s['max_exact_cluster_size'] as int;
    final nearUnique = s['near_unique_signatures'] as int;

    if (reviewed >= 7 && maxCluster >= 7) {
      blockers.add({
        'seeker_id': id,
        'severity': 'blocker',
        'code': 'identical_explanations_across_many_listings',
        'detail':
            'Exact same explanation on $maxCluster of $reviewed reviewed '
            'listings (threshold ≥7).',
        'duplicate_percentage': dupPct,
      });
    } else if (reviewed >= 5 && maxCluster >= 5 && dupPct >= 70) {
      highs.add({
        'seeker_id': id,
        'severity': 'high',
        'code': 'high_exact_duplication_cluster',
        'detail':
            'Exact cluster of $maxCluster / $reviewed with '
            '${dupPct.toStringAsFixed(1)}% duplicate rate.',
        'duplicate_percentage': dupPct,
      });
    }

    if (reviewed >= 3 && unique <= 2 && nearUnique <= 2) {
      highs.add({
        'seeker_id': id,
        'severity': 'high',
        'code': 'templated_minimal_variation',
        'detail':
            'Only $unique exact unique explanation(s) and $nearUnique '
            'reason-type signature(s) across $reviewed listings — '
            'templates do not differentiate listings.',
      });
    }

    if (reviewed >= 2 && unique == 1) {
      mediums.add({
        'seeker_id': id,
        'severity': 'medium',
        'code': 'all_explanations_identical',
        'detail':
            'All $reviewed reviewed listings share one identical explanation.',
      });
    }

    // Listing-difference reflection: titles/areas differ but explanation same.
    final listings = (s['top_listings'] as List).cast<Map<String, dynamic>>();
    if (listings.length >= 2) {
      final areas = listings.map((l) => '${l['area']}').toSet();
      final prices = listings.map((l) => '${l['price']}').toSet();
      if (areas.length >= 3 && unique <= 2) {
        mediums.add({
          'seeker_id': id,
          'severity': 'medium',
          'code': 'fails_to_reflect_listing_differences',
          'detail':
              '${areas.length} distinct listing areas and ${prices.length} '
              'price strings, but only $unique unique explanation text(s). '
              'Preference labels are category templates without listing-specific '
              'tokens (area name, rent amount, beds count in copy).',
        });
      }
    }
  }

  return {
    'blocker': blockers,
    'high': highs,
    'medium': mediums,
  };
}

List<Map<String, dynamic>> _collectDuplicatePairExamples(
  List<Map<String, dynamic>> seekers,
) {
  final examples = <Map<String, dynamic>>[];
  for (final s in seekers) {
    final clusters =
        (s['exact_clusters'] as List).cast<Map<String, dynamic>>();
    for (final c in clusters.take(2)) {
      final ids = (c['listing_ids'] as List).cast<String>();
      if (ids.length < 2) continue;
      examples.add({
        'seeker_id': s['seeker_id'],
        'listing_a': ids[0],
        'listing_b': ids[1],
        'cluster_size': c['count'],
        'shared_explanation': c['sample_joined'],
        'kind': 'exact',
      });
      if (examples.length >= 8) return examples;
    }
  }
  return examples;
}

// ── Markdown ─────────────────────────────────────────────────────────────────

String _buildMarkdown(Map<String, dynamic> payload) {
  final buf = StringBuffer();
  final summary = payload['summary'] as Map<String, dynamic>;
  final findings = payload['findings'] as Map<String, dynamic>;
  final perSeeker = payload['per_seeker'] as List<dynamic>;
  final pairs = payload['duplicate_pairs_examples'] as List<dynamic>;
  final thresholds = payload['thresholds'] as Map<String, dynamic>;
  final overall = payload['overall'];
  final seekers = payload['seekers'] as List<dynamic>;

  buf.writeln('# Explanation Duplication Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  buf.writeln('**Overall: $overall**');
  buf.writeln();
  buf.writeln('| Metric | Value |');
  buf.writeln('|--------|-------|');
  buf.writeln('| Seekers tested | ${summary['seekers_tested']} |');
  buf.writeln(
    '| Avg duplicate % | ${summary['average_duplicate_percentage']}% |',
  );
  buf.writeln(
    '| Avg near-duplicate % | ${summary['average_near_duplicate_percentage']}% |',
  );
  buf.writeln(
    '| Avg unique explanations | ${summary['average_unique_explanations']} |',
  );
  buf.writeln(
    '| Seekers with identical ≥7/10 | '
    '${summary['seekers_with_identical_cluster_ge_7']} |',
  );
  final f = summary['findings'] as Map<String, dynamic>;
  buf.writeln('| Blocker findings | ${f['blocker']} |');
  buf.writeln('| High findings | ${f['high']} |');
  buf.writeln('| Medium findings | ${f['medium']} |');
  buf.writeln();

  buf.writeln('## Near-duplicate definition');
  buf.writeln();
  buf.writeln(thresholds['near_duplicate_definition']);
  buf.writeln();
  buf.writeln(
    '**Duplicate % formula:** `${thresholds['duplicate_percentage_formula']}`',
  );
  buf.writeln();
  buf.writeln('### Thresholds');
  buf.writeln();
  buf.writeln(
    '- **FAIL** if average `duplicate_percentage` > '
    '${thresholds['fail_avg_duplicate_pct_gt']}% OR '
    '≥${thresholds['fail_identical_cluster_ge_7_seekers_ge']} seekers with '
    'identical explanations on ≥7 listings',
  );
  buf.writeln(
    '- **PASS WITH WARNINGS** if moderate templating '
    '(${(thresholds['warn_avg_duplicate_pct_range'] as List)[0]}–'
    '${(thresholds['warn_avg_duplicate_pct_range'] as List)[1]}%) '
    'but some unique variation',
  );
  buf.writeln('- **PASS** if mostly unique / healthy variation');
  buf.writeln();

  buf.writeln('## PART 1 — Test seekers');
  buf.writeln();
  buf.writeln(
    '| seeker_id | marketplace | intended | observed volume | matches | scenario |',
  );
  buf.writeln(
    '|-----------|-------------|----------|-----------------|---------|----------|',
  );
  for (final raw in seekers) {
    final s = raw as Map<String, dynamic>;
    buf.writeln(
      '| `${s['seeker_id']}` | ${s['marketplace']} | '
      '${s['intended_volume']} | ${s['match_volume_tier']} | '
      '${s['matches_returned']} | ${s['scenario']} |',
    );
  }
  buf.writeln();

  buf.writeln('## PART 3 — Per seeker duplication');
  buf.writeln();
  buf.writeln(
    '| seeker_id | total_listings_reviewed | unique_explanations | '
    'duplicate_explanations | duplicate_percentage |',
  );
  buf.writeln(
    '|-----------|-------------------------|---------------------|'
    '------------------------|----------------------|',
  );
  for (final raw in perSeeker) {
    final s = raw as Map<String, dynamic>;
    buf.writeln(
      '| `${s['seeker_id']}` | ${s['total_listings_reviewed']} | '
      '${s['unique_explanations']} | ${s['duplicate_explanations']} | '
      '${s['duplicate_percentage']}% |',
    );
  }
  buf.writeln();

  buf.writeln('## PART 4 — Quality review findings');
  buf.writeln();
  for (final sev in ['blocker', 'high', 'medium']) {
    final rows = (findings[sev] as List).cast<Map<String, dynamic>>();
    buf.writeln('### ${sev[0].toUpperCase()}${sev.substring(1)}');
    buf.writeln();
    if (rows.isEmpty) {
      buf.writeln('_None_');
    } else {
      for (final r in rows) {
        buf.writeln(
          '- `${r['seeker_id']}` — **${r['code']}**: ${r['detail']}',
        );
      }
    }
    buf.writeln();
  }

  buf.writeln('## Example duplicate explanation pairs');
  buf.writeln();
  if (pairs.isEmpty) {
    buf.writeln('_None_');
  } else {
    for (final raw in pairs) {
      final p = raw as Map<String, dynamic>;
      buf.writeln(
        '- `${p['seeker_id']}`: `${p['listing_a']}` ↔ `${p['listing_b']}` '
        '(cluster ${p['cluster_size']})',
      );
      buf.writeln('  - ${p['shared_explanation']}');
    }
  }
  buf.writeln();

  // Worst seeker
  Map<String, dynamic>? worst;
  for (final raw in perSeeker) {
    final s = raw as Map<String, dynamic>;
    if (worst == null ||
        (s['duplicate_percentage'] as num) >
            (worst['duplicate_percentage'] as num)) {
      worst = s;
    }
  }
  if (worst != null) {
    buf.writeln('## Worst seeker');
    buf.writeln();
    buf.writeln(
      '`${worst['seeker_id']}` — '
      '${worst['duplicate_percentage']}% duplicate '
      '(${worst['unique_explanations']} unique / '
      '${worst['total_listings_reviewed']} reviewed; '
      'max exact cluster ${worst['max_exact_cluster_size']})',
    );
    buf.writeln();
  }

  buf.writeln('## Per-seeker explanation samples');
  buf.writeln();
  for (final raw in seekers) {
    final s = raw as Map<String, dynamic>;
    buf.writeln('### `${s['seeker_id']}`');
    buf.writeln();
    buf.writeln('- **Scenario:** ${s['scenario']}');
    buf.writeln(
      '- **Matches:** ${s['matches_returned']} '
      '(reviewed top ${s['total_listings_reviewed']})',
    );
    buf.writeln(
      '- **Unique / dup%:** ${s['unique_explanations']} / '
      '${s['duplicate_percentage']}%',
    );
    buf.writeln();
    final listings =
        (s['top_listings'] as List).cast<Map<String, dynamic>>();
    for (final l in listings.take(5)) {
      final expl = (l['explanations'] as List).join('; ');
      buf.writeln(
        '- `${l['listing_id']}` (${l['area']}, ${l['price']}): '
        '${expl.isEmpty ? '_(empty)_' : expl}',
      );
    }
    if (listings.length > 5) {
      buf.writeln('- _… ${listings.length - 5} more in JSON_');
    }
    buf.writeln();
  }

  buf.writeln('## Methodology');
  buf.writeln();
  final method = payload['methodology'] as Map<String, dynamic>;
  buf.writeln('### Code paths');
  for (final p in method['code_paths'] as List<dynamic>) {
    buf.writeln('- `$p`');
  }
  buf.writeln();
  buf.writeln('### Corpus');
  final corpus = method['listing_corpus'] as Map<String, dynamic>;
  buf.writeln(
    '- ${corpus['name']}: ${corpus['total']} listings '
    '(SL ${corpus['shared_living_count']}, IP ${corpus['independent_places_count']})',
  );
  buf.writeln('- Top N per seeker: ${method['top_n']}');
  buf.writeln();
  buf.writeln('### Limitations');
  buf.writeln();
  buf.writeln(
    '- Preference explanations are category templates (max 3 lines); '
    'they intentionally omit listing-specific tokens such as rent figures '
    'or area names in the copy itself.',
  );
  buf.writeln(
    '- Match-volume tiers are observed from pipeline ranked length; '
    'intended tiers may differ when seed supply is sparse for narrow prefs.',
  );
  buf.writeln(
    '- Audit only — production matching/ranking/explanation logic unchanged.',
  );
  buf.writeln(
    '- Location workflow files were not modified.',
  );
  buf.writeln();

  return buf.toString();
}
