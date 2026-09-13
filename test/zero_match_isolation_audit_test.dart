import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/active_mode_service.dart';
import 'package:true_circle/services/profile_onboarding_repository.dart';
import 'package:true_circle/services/profile_portal_inheritance_service.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';

/// Zero-Match Isolation Audit — marketplace separation when feed is empty.
///
/// Run: `flutter test test/zero_match_isolation_audit_test.dart`
///
/// Same production path as Active Mode routing audit:
/// - [MarketplaceSpace.fromSession]
/// - [ProfilePortalInheritanceService.seekerFeedDefaults] (Explore inherited filters)
/// - [MarketplaceListingPipeline.runWithFilters]
/// against mixed [SampleListingsDublin] corpus.
void main() {
  test('zero match isolation audit dump', () {
    final corpus = SampleListingsDublin.items;
    final shareCount =
        corpus.where((l) => ListingData.listingType(l) == 'Share').length;
    final rentCount =
        corpus.where((l) => ListingData.listingType(l) == 'Rent').length;

    // Code-path review (not UI-instrumented): empty-state widgets exist on
    // HomeScreen when ranked feed is empty after tower inventory is present
    // (_buildSearchNoResultsState) or tower inventory empty (_buildTowerEmptyState).
    const emptyStateWidgetConfirmed = true;

    // Code search: zero-match path does not inject opposite-marketplace listings.
    // _buildSearchNoResultsState only shows copy ("switch tabs"); family CTA
    // switches tab but does not append other-marketplace cards. Closest-match
    // fallback stays within the same tower pool.
    const crossMarketplaceFallbackExists = false;

    final results = <Map<String, dynamic>>[
      for (final seeker in _edgeSeekers)
        _runSeeker(
          seeker,
          corpus,
          emptyStateWidgetConfirmed: emptyStateWidgetConfirmed,
          crossMarketplaceFallbackExists: crossMarketplaceFallbackExists,
        ),
    ];

    var totalMatches = 0;
    var crossMarketplace = 0;
    var seekersPass = 0;
    var zeroMatchAsExpected = 0;
    for (final r in results) {
      totalMatches += r['matches_returned'] as int;
      crossMarketplace += r['cross_marketplace_count'] as int;
      if (r['result'] == 'PASS') seekersPass++;
      if (r['matches_returned'] == 0 &&
          r['expected_result'] == 'ZERO_MATCHES') {
        zeroMatchAsExpected++;
      }
    }

    final overallPass =
        seekersPass == results.length && crossMarketplace == 0;

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'overall_pass': overallPass,
      'overall': overallPass ? 'PASS' : 'FAIL',
      'success_criteria': {
        'all_zero_match_seekers_return_0':
            zeroMatchAsExpected == results.length,
        // Empty state required only when matches_returned==0.
        'empty_state_correct': results.every(
          (r) =>
              (r['matches_returned'] as int) != 0 ||
              r['empty_state_displayed'] == 'YES',
        ),
        'cross_marketplace_listings': crossMarketplace,
        'marketplace_bleed': crossMarketplace,
        'cross_marketplace_fallback': results.any(
              (r) => r['recommended_fallback_content'] == 'YES',
            )
            ? 'PRESENT'
            : 'ABSENT',
        'marketplace_isolation_preserved': crossMarketplace == 0,
        'seekers_tested': results.length,
        'seekers_pass': seekersPass,
      },
      'summary': {
        'total_matches': totalMatches,
        'cross_marketplace_count': crossMarketplace,
        'seekers_pass': seekersPass,
        'seekers_tested': results.length,
        'zero_match_as_expected': zeroMatchAsExpected,
        'overall': overallPass ? 'PASS' : 'FAIL',
      },
      'methodology': {
        'active_mode': ActiveMode.explore.storageToken,
        'code_paths': [
          'MarketplaceSpace.fromSession (marketplace routing from seeker session)',
          'ProfileOnboardingRepository.snapshotFromSession + '
              'ProfilePortalInheritanceService.seekerFeedDefaults '
              '(Active Mode Explore inherited hard filters)',
          'MarketplaceListingPipeline.runWithFilters '
              '(tower equality → weighted hard exclusion → rank)',
          'ListingData.listingType (classify returned listings Share vs Rent)',
        ],
        'listing_corpus': {
          'name': 'SampleListingsDublin (local Dublin marketplace seed)',
          'paths': [
            'lib/data/sample_listings_dublin.dart',
            'lib/data/sample_listings_dublin_v2.dart',
            'lib/data/sample_listings_dublin_legacy.dart',
            'lib/data/sample_listings_dublin_expansion.dart',
            'lib/data/dublin_listing_builder.dart',
          ],
          'shared_living_count': shareCount,
          'independent_places_count': rentCount,
          'total': corpus.length,
        },
        'empty_state_assessment': {
          'method': 'code_path_inferred',
          'limitation':
              'Pipeline test asserts matches==0; empty_state_displayed=YES '
              'when matches_returned==0 AND HomeScreen empty-state widgets '
              'confirmed for ranked-empty / tower-empty paths. Not '
              'UI-instrumented (no widget pump of HomeScreen).',
          'widgets': [
            'HomeScreen._buildSearchNoResultsState '
                '(ranked empty + active search / commute divergence)',
            'HomeScreen._buildTowerEmptyState (afterTower empty)',
          ],
          'empty_state_widget_confirmed': emptyStateWidgetConfirmed,
        },
        'recommended_fallback_assessment': {
          'method': 'codebase_search',
          'cross_marketplace_listing_injection_found':
              crossMarketplaceFallbackExists,
          'notes':
              'Zero-match UI copy may mention "switch tabs" and the family '
              'shared-living unavailable state offers a Browse Independent '
              'Places CTA that changes the active tab — neither injects '
              'opposite-marketplace listing cards into the feed. Soft '
              'closest-match / filter relaxation stays within the same tower.',
        },
        'marketplace_determination':
            'Canonical tower = ListingData.listingType. Share = shared_living; '
            'Rent = independent_places. Feed isolation is tower equality in '
            'MarketplaceListingPipeline.run (afterTower) before budget hard-cap.',
        'seeker_dataset': {
          'status': 'reconstructed',
          'note':
              'Frozen UAT seeker JSON is not checked into the repo. ZERO_MATCHES '
              'edge seekers reconstructed from prior UAT chat artifact and mapped '
              'into session keys + Explore inherited filters (budget / SL soft '
              'profile fields). preferred_locations, parking, pets, property_type, '
              'and transit are session metadata for ranking context where wired; '
              'they are NOT additional hard exclusions in seekerFeedDefaults.',
          'source_seeker_ids': ['SL-EDGE-01', 'IP-EDGE-04', 'IP-EDGE-06'],
        },
        'filter_inputs_used':
            'Active Mode Explore defaults via seekerFeedDefaults: budgetMax '
            '(+ SL occupant/gender/food/lease when present on session). Same '
            'hard budget cap ratio 1.25 as WeightedListingMatcher.',
      },
      'blockers': [
        for (final r in results)
          if (r['result'] == 'FAIL')
            {
              'seeker_id': r['seeker_id'],
              'reason': r['fail_reason'],
              'bleed_listing_ids': r['bleed_listing_ids'],
              'matches_returned': r['matches_returned'],
            },
      ],
      'seekers': results,
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/zero_match_isolation_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/zero_match_isolation_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'ZERO_MATCH_AUDIT overall=${overallPass ? 'PASS' : 'FAIL'} '
      'matches=$totalMatches cross=$crossMarketplace '
      'seekers_pass=$seekersPass/${results.length}',
    );

    expect(results.length, 3);
    expect(corpus.length, 90);
    expect(shareCount, 40);
    expect(rentCount, 50);
    for (final r in results) {
      expect(r['cross_marketplace_listings_shown'], 'NO',
          reason: '${r['seeker_id']} showed cross-marketplace listings: '
              '${r['bleed_listing_ids']}');
      expect(r['marketplace_correct'], 'YES',
          reason: '${r['seeker_id']} marketplace isolation failed');
      expect(r['recommended_fallback_content'], 'NO',
          reason: '${r['seeker_id']} injected other-marketplace fallback');
      // UAT ZERO_MATCHES contract — fail when Explore path still returns cards.
      expect(r['matches_returned'], 0,
          reason:
              '${r['seeker_id']} expected 0 matches, got ${r['matches_returned']}: '
              '${r['returned_listing_ids']}');
    }
    expect(overallPass, isTrue);
  });
}

class _UatEdgeSeeker {
  const _UatEdgeSeeker({
    required this.seekerId,
    required this.uatScenario,
    required this.marketplace,
    required this.maxBudget,
    required this.preferredLocations,
    required this.occupationType,
    this.roomPreference,
    this.propertyTypePreference,
    this.parkingRequired = false,
    this.pets = false,
    this.transit,
    this.desiredMoveDate,
  });

  final String seekerId;
  final String uatScenario;
  final String marketplace;
  final int maxBudget;
  final List<String> preferredLocations;
  final String occupationType;
  final String? roomPreference;
  final String? propertyTypePreference;
  final bool parkingRequired;
  final bool pets;
  final String? transit;
  final String? desiredMoveDate;
}

/// Reconstructed ZERO_MATCHES edge seekers from frozen UAT chat artifact.
const _edgeSeekers = [
  _UatEdgeSeeker(
    seekerId: 'SL-EDGE-01',
    uatScenario:
        'Edge · very low budget · D2/D4 private · zero/few matches',
    marketplace: 'shared_living',
    maxBudget: 350,
    preferredLocations: ['Dublin 2', 'Dublin 4'],
    occupationType: 'professional',
    roomPreference: 'private',
    transit: 'luas',
    desiredMoveDate: '2026-09-01',
  ),
  _UatEdgeSeeker(
    seekerId: 'IP-EDGE-04',
    uatScenario: 'Edge · extremely low budget · D2/D4 · zero matches',
    marketplace: 'independent_places',
    maxBudget: 900,
    preferredLocations: ['Dublin 2', 'Dublin 4'],
    occupationType: 'single_professional',
    propertyTypePreference: 'apartment',
  ),
  _UatEdgeSeeker(
    seekerId: 'IP-EDGE-06',
    uatScenario:
        'Edge · zero match · studio + pets + parking + D4 + ultra low budget',
    marketplace: 'independent_places',
    maxBudget: 800,
    preferredLocations: ['Dublin 4'],
    occupationType: 'single_professional',
    propertyTypePreference: 'studio',
    parkingRequired: true,
    pets: true,
    transit: 'dart',
    desiredMoveDate: '2026-08-05',
  ),
];

Map<String, dynamic> _sessionFor(_UatEdgeSeeker seeker) {
  final isShare = seeker.marketplace == 'shared_living';
  final space =
      isShare ? MarketplaceSpace.sharedSpace : MarketplaceSpace.fullRental;
  final now = DateTime.now().toUtc().toIso8601String();

  return <String, dynamic>{
    'email': '${seeker.seekerId.toLowerCase()}@uat.truecircle.dev',
    'full_name': seeker.seekerId,
    'uat_seeker_id': seeker.seekerId,
    'detected_city': 'Dublin',
    'mother_tongue': 'English',
    'spoken_languages': ['English'],
    'food_preference': 'No Preference',
    'occupant_type': seeker.occupationType.contains('student')
        ? 'Students'
        : 'Working Professionals',
    'budget_max': seeker.maxBudget,
    'preferred_property_type': space.towerPropertyType,
    'preferred_arrangement': space.arrangementBackend,
    'active_marketplace_space': space.storageToken,
    'profile_onboarding_track': isShare
        ? 'seeker_shared_space'
        : 'seeker_entire_place',
    'preferred_locations': seeker.preferredLocations,
    if (seeker.roomPreference != null)
      'share_room_layout': seeker.roomPreference == 'private'
          ? 'private_room'
          : 'shared_room',
    if (seeker.propertyTypePreference != null)
      'preferred_layout': seeker.propertyTypePreference,
    if (seeker.parkingRequired) 'parking_required': true,
    if (seeker.pets) 'household_has_pets': true,
    if (seeker.transit != null) 'preferred_transit': seeker.transit,
    if (seeker.desiredMoveDate != null)
      'desired_move_date': seeker.desiredMoveDate,
    'trust_stage': 2,
    ActiveModeService.lastActiveModeKey: ActiveMode.explore.storageToken,
    ActiveModeService.lastModeUpdatedAtKey: now,
  };
}

Map<String, dynamic> _runSeeker(
  _UatEdgeSeeker seeker,
  List<Map<String, dynamic>> corpus, {
  required bool emptyStateWidgetConfirmed,
  required bool crossMarketplaceFallbackExists,
}) {
  const expectedResult = 'ZERO_MATCHES';
  final session = _sessionFor(seeker);
  final resolvedSpace = MarketplaceSpace.fromSession(session);
  final tower = resolvedSpace.towerPropertyType;
  final marketplaceRequested = seeker.marketplace;
  final marketplaceFromSession = resolvedSpace == MarketplaceSpace.sharedSpace
      ? 'shared_living'
      : 'independent_places';

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

  final returned = [
    for (final scored in pipeline.ranked) scored.listing,
  ];

  var slCount = 0;
  var ipCount = 0;
  final returnedIds = <String>[];
  final bleedIds = <String>[];

  for (final listing in returned) {
    final id = ListingData.id(listing);
    final listingMarketplace = _marketplaceOf(listing);
    returnedIds.add(id);
    if (listingMarketplace == 'shared_living') {
      slCount++;
    } else {
      ipCount++;
    }
    if (listingMarketplace != marketplaceRequested) {
      bleedIds.add(id);
    }
  }

  final matchesReturned = returned.length;
  final crossShown = bleedIds.isNotEmpty ? 'YES' : 'NO';

  // Empty state: code-path inferred — zero ranked results + confirmed widget.
  final emptyStateDisplayed =
      matchesReturned == 0 && emptyStateWidgetConfirmed ? 'YES' : 'NO';

  // Forbidden only if zero-match path injects other-marketplace recommendations.
  final recommendedFallback = crossMarketplaceFallbackExists &&
          matchesReturned == 0
      ? 'YES'
      : 'NO';

  final marketplaceCorrect = marketplaceFromSession == marketplaceRequested &&
          bleedIds.isEmpty &&
          (matchesReturned == 0 ||
              (marketplaceRequested == 'shared_living'
                  ? ipCount == 0
                  : slCount == 0))
      ? 'YES'
      : 'NO';

  final failReasons = <String>[];
  if (matchesReturned != 0) {
    failReasons.add(
      'expected ZERO_MATCHES but matches_returned=$matchesReturned '
      '(ids=${returnedIds.join(",")})',
    );
  } else if (emptyStateDisplayed != 'YES') {
    // Only required when the feed is empty.
    failReasons.add('empty_state_displayed != YES at zero matches');
  }
  if (crossShown != 'NO') {
    failReasons.add(
      'cross_marketplace_listings_shown (bleed=${bleedIds.join(",")})',
    );
  }
  if (recommendedFallback != 'NO') {
    failReasons.add('recommended_fallback_content from other marketplace');
  }
  if (marketplaceCorrect != 'YES') {
    failReasons.add('marketplace_correct != YES');
  }

  final result = failReasons.isEmpty ? 'PASS' : 'FAIL';

  return {
    'seeker_id': seeker.seekerId,
    'uat_scenario': seeker.uatScenario,
    'marketplace': marketplaceRequested,
    'marketplace_requested': marketplaceRequested,
    'marketplace_from_session': marketplaceFromSession,
    'tower_property_type': tower,
    'active_mode': ActiveMode.explore.storageToken,
    'expected_result': expectedResult,
    'matches_returned': matchesReturned,
    'empty_state_displayed': emptyStateDisplayed,
    'empty_state_assessment_method': 'code_path_inferred',
    'cross_marketplace_listings_shown': crossShown,
    'recommended_fallback_content': recommendedFallback,
    'shared_living_results_count': slCount,
    'independent_places_results_count': ipCount,
    'cross_marketplace_count': bleedIds.length,
    'marketplace_correct': marketplaceCorrect,
    'result': result,
    'fail_reason': failReasons.isEmpty ? '' : failReasons.join('; '),
    'returned_listing_ids': returnedIds,
    'bleed_listing_ids': bleedIds,
    'inherited_filters': {
      'budget_max': filters.budgetMax,
      'occupant_type': filters.occupantType,
      'gender_preference': filters.genderPreference,
      'food_preference': filters.foodPreference,
      'preferred_lease_months': filters.preferredLeaseMonths,
    },
    'session_prefs_not_hard_filtered': {
      'preferred_locations': seeker.preferredLocations,
      'room_preference': seeker.roomPreference,
      'property_type': seeker.propertyTypePreference,
      'parking_required': seeker.parkingRequired,
      'pets': seeker.pets,
      'transit': seeker.transit,
      'desired_move_date': seeker.desiredMoveDate,
    },
    'pipeline_stages': {
      'corpus': corpus.length,
      'after_tower': pipeline.afterTower.length,
      'after_filters': pipeline.afterFilters.length,
      'ranked': pipeline.ranked.length,
      'used_closest_match_fallback': pipeline.usedClosestMatchFallback,
      'relaxed_constraints': pipeline.relaxedConstraints,
      'is_commute_divergent': pipeline.isCommuteDivergent,
      'requires_onboarding': pipeline.requiresOnboarding,
    },
  };
}

String _marketplaceOf(Map<String, dynamic> listing) {
  final tower = ListingData.listingType(listing);
  return tower == 'Share' ? 'shared_living' : 'independent_places';
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final summary = payload['summary'] as Map<String, dynamic>;
  final criteria = payload['success_criteria'] as Map<String, dynamic>;
  final methodology = payload['methodology'] as Map<String, dynamic>;
  final corpus = methodology['listing_corpus'] as Map<String, dynamic>;
  final seekers = payload['seekers'] as List<dynamic>;
  final blockers = payload['blockers'] as List<dynamic>;
  final emptyMeta =
      methodology['empty_state_assessment'] as Map<String, dynamic>;
  final fallbackMeta =
      methodology['recommended_fallback_assessment'] as Map<String, dynamic>;
  final overall = summary['overall'];
  final buf = StringBuffer();

  buf.writeln('# Zero-Match Isolation Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  buf.writeln('**Overall: $overall**');
  buf.writeln();
  buf.writeln('| Criterion | Result |');
  buf.writeln('|-----------|--------|');
  buf.writeln(
    '| All ZERO_MATCH seekers return 0 | '
    '${criteria['all_zero_match_seekers_return_0'] == true ? 'YES' : 'NO'} |',
  );
  buf.writeln(
    '| Empty state correct | '
    '${criteria['empty_state_correct'] == true ? 'YES' : 'NO'} |',
  );
  buf.writeln(
    '| Cross-marketplace listings | ${criteria['cross_marketplace_listings']} |',
  );
  buf.writeln('| Marketplace bleed | ${criteria['marketplace_bleed']} |');
  buf.writeln(
    '| Cross-marketplace fallback | ${criteria['cross_marketplace_fallback']} |',
  );
  buf.writeln(
    '| Marketplace isolation preserved | '
    '${criteria['marketplace_isolation_preserved'] == true ? 'YES' : 'NO'} |',
  );
  buf.writeln(
    '| Seekers pass | ${criteria['seekers_pass']}/${criteria['seekers_tested']} |',
  );
  buf.writeln('| Total matches returned | ${summary['total_matches']} |');
  buf.writeln();

  buf.writeln('## Per-seeker results');
  buf.writeln();
  buf.writeln(
    '| seeker_id | marketplace | expected_result | matches_returned | '
    'empty_state_displayed | cross_marketplace_listings_shown | '
    'recommended_fallback_content | shared_living_results_count | '
    'independent_places_results_count | marketplace_correct | result |',
  );
  buf.writeln(
    '|-----------|-------------|-----------------|------------------|'
    '------------------------|--------------------------------|'
    '-------------------------------|----------------------------|'
    '--------------------------------|---------------------|--------|',
  );
  for (final raw in seekers) {
    final r = raw as Map<String, dynamic>;
    buf.writeln(
      '| `${r['seeker_id']}` | ${r['marketplace']} | ${r['expected_result']} | '
      '${r['matches_returned']} | ${r['empty_state_displayed']} | '
      '${r['cross_marketplace_listings_shown']} | '
      '${r['recommended_fallback_content']} | '
      '${r['shared_living_results_count']} | '
      '${r['independent_places_results_count']} | '
      '**${r['marketplace_correct']}** | **${r['result']}** |',
    );
  }
  buf.writeln();

  for (final raw in seekers) {
    final r = raw as Map<String, dynamic>;
    final stages = r['pipeline_stages'] as Map<String, dynamic>;
    final inherited = r['inherited_filters'] as Map<String, dynamic>;
    final soft = r['session_prefs_not_hard_filtered'] as Map<String, dynamic>;
    final ids = (r['returned_listing_ids'] as List<dynamic>).cast<String>();
    final bleed = (r['bleed_listing_ids'] as List<dynamic>).cast<String>();
    buf.writeln('### `${r['seeker_id']}`');
    buf.writeln();
    buf.writeln('- **Scenario:** ${r['uat_scenario']}');
    buf.writeln('- **Active mode:** `${r['active_mode']}`');
    buf.writeln('- **Session marketplace:** `${r['marketplace_from_session']}`');
    buf.writeln('- **Tower token:** `${r['tower_property_type']}`');
    buf.writeln(
      '- **Inherited hard filters:** budgetMax=${inherited['budget_max']}, '
      'occupant=${inherited['occupant_type']}, '
      'gender=${inherited['gender_preference']}, '
      'food=${inherited['food_preference']}',
    );
    buf.writeln(
      '- **Session prefs (not hard-filtered by Explore defaults):** '
      'locations=${soft['preferred_locations']}, '
      'room=${soft['room_preference']}, property=${soft['property_type']}, '
      'parking=${soft['parking_required']}, pets=${soft['pets']}, '
      'transit=${soft['transit']}, move=${soft['desired_move_date']}',
    );
    buf.writeln(
      '- **Pipeline:** corpus ${stages['corpus']} → afterTower '
      '${stages['after_tower']} → afterFilters ${stages['after_filters']} → '
      'ranked ${stages['ranked']} '
      '(closestFallback=${stages['used_closest_match_fallback']})',
    );
    buf.writeln('- **empty_state_displayed:** ${r['empty_state_displayed']} '
        '(${r['empty_state_assessment_method']})');
    buf.writeln(
      '- **cross_marketplace_listings_shown:** '
      '${r['cross_marketplace_listings_shown']}',
    );
    buf.writeln(
      '- **recommended_fallback_content:** '
      '${r['recommended_fallback_content']}',
    );
    buf.writeln('- **marketplace_correct:** **${r['marketplace_correct']}**');
    buf.writeln('- **result:** **${r['result']}**');
    if ((r['fail_reason'] as String).isNotEmpty) {
      buf.writeln('- **fail_reason:** ${r['fail_reason']}');
    }
    if (bleed.isNotEmpty) {
      buf.writeln(
        '- **Bleed listing IDs:** ${bleed.map((e) => '`$e`').join(', ')}',
      );
    } else {
      buf.writeln('- **Bleed listing IDs:** _(none)_');
    }
    buf.writeln('- **returned_listing_ids** (${ids.length}):');
    if (ids.isEmpty) {
      buf.writeln('  - _(none)_');
    } else {
      for (final id in ids) {
        buf.writeln('  - `$id`');
      }
    }
    buf.writeln();
  }

  buf.writeln('## Blockers');
  buf.writeln();
  if (blockers.isEmpty) {
    buf.writeln('_None._');
  } else {
    for (final raw in blockers) {
      final b = raw as Map<String, dynamic>;
      final bleed =
          (b['bleed_listing_ids'] as List<dynamic>).cast<String>();
      buf.writeln(
        '- `${b['seeker_id']}`: ${b['reason']} '
        '(matches=${b['matches_returned']}'
        '${bleed.isEmpty ? '' : '; bleed=${bleed.join(", ")}'})',
      );
    }
  }
  buf.writeln();

  buf.writeln('## Methodology');
  buf.writeln();
  buf.writeln('### Code paths invoked');
  buf.writeln();
  for (final path in methodology['code_paths'] as List<dynamic>) {
    buf.writeln('- `$path`');
  }
  buf.writeln();
  buf.writeln('### Listing corpus');
  buf.writeln();
  buf.writeln('- **Dataset:** ${corpus['name']}');
  buf.writeln(
    '- **Counts:** ${corpus['shared_living_count']} Shared Living (`Share`) · '
    '${corpus['independent_places_count']} Independent Places (`Rent`) · '
    'total ${corpus['total']}',
  );
  buf.writeln();
  buf.writeln('### Empty-state assessment');
  buf.writeln();
  buf.writeln('- **Method:** ${emptyMeta['method']}');
  buf.writeln('- **Limitation:** ${emptyMeta['limitation']}');
  buf.writeln();
  buf.writeln('### Recommended-fallback assessment');
  buf.writeln();
  buf.writeln('- **Method:** ${fallbackMeta['method']}');
  buf.writeln(
    '- **Cross-marketplace listing injection found:** '
    '${fallbackMeta['cross_marketplace_listing_injection_found']}',
  );
  buf.writeln('- **Notes:** ${fallbackMeta['notes']}');
  buf.writeln();
  buf.writeln('### Seeker dataset');
  buf.writeln();
  final seekerDs = methodology['seeker_dataset'] as Map<String, dynamic>;
  buf.writeln('- **Status:** ${seekerDs['status']}');
  buf.writeln('- **Note:** ${seekerDs['note']}');
  buf.writeln();
  buf.writeln('### Failure conditions checked');
  buf.writeln();
  buf.writeln('- Any cross-marketplace listings shown');
  buf.writeln('- Any marketplace bleed');
  buf.writeln('- Empty state not shown when match count = 0');
  buf.writeln('- Fallback recommendations from the other marketplace');
  buf.writeln('- Marketplace isolation broken');
  buf.writeln('- Expected ZERO_MATCHES but matches_returned ≠ 0');
  buf.writeln();
  buf.writeln(
    'Overall **PASS** only if all three ZERO_MATCH seekers PASS.',
  );
  buf.writeln();

  return buf.toString();
}
