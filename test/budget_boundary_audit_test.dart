import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/active_mode_service.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/utils/weighted_listing_matcher.dart';

/// Budget Boundary Audit — hard-gate at rent−1 / rent / rent+1.
///
/// Run: `flutter test test/budget_boundary_audit_test.dart`
///
/// Production path:
/// - [MarketplaceListingPipeline.runWithFilters]
/// - [WeightedListingMatcher.passesHardExclusion] via fetchScoredListings
/// - amount = [ListingData.listingPriceAmount]
/// - hardCap = (budgetMax * [WeightedListingMatcher.budgetHardCapRatio]).round()
/// - INCLUDED iff amount <= hardCap
void main() {
  test('budget boundary audit dump', () {
    final corpus = SampleListingsDublin.items;
    final sharePool = _pricedOfType(corpus, 'Share');
    final rentPool = _pricedOfType(corpus, 'Rent');

    final selectedShare = _selectDiverse(sharePool, minCount: 5);
    final selectedRent = _selectDiverse(rentPool, minCount: 5);

    expect(selectedShare.length, greaterThanOrEqualTo(5));
    expect(selectedRent.length, greaterThanOrEqualTo(5));
    expect(
      selectedShare.map((e) => e.rent).toSet().length,
      selectedShare.length,
      reason: 'Share selections must have distinct rents',
    );
    expect(
      selectedRent.map((e) => e.rent).toSet().length,
      selectedRent.length,
      reason: 'Rent selections must have distinct rents',
    );

    final cases = <Map<String, dynamic>>[
      for (final listing in [...selectedShare, ...selectedRent])
        for (final budgetCase in _budgetCases(listing.rent))
          _runCase(
            listing: listing,
            budgetTest: budgetCase.budget,
            expectedStrict: budgetCase.expectedStrict,
            corpus: corpus,
          ),
    ];

    var pass = 0;
    var fail = 0;
    var slPass = 0;
    var slFail = 0;
    var ipPass = 0;
    var ipFail = 0;
    var rentMinus1Included = 0;
    var rentEqualExcluded = 0;
    var rentPlus1Excluded = 0;

    for (final c in cases) {
      final ok = c['result'] == 'PASS';
      if (ok) {
        pass++;
      } else {
        fail++;
      }
      if (c['marketplace'] == 'shared_living') {
        if (ok) {
          slPass++;
        } else {
          slFail++;
        }
      } else {
        if (ok) {
          ipPass++;
        } else {
          ipFail++;
        }
      }

      final budgetKind = c['budget_kind'] as String;
      final actual = c['actual_result'] as String;
      if (budgetKind == 'rent_minus_1' && actual == 'INCLUDED') {
        rentMinus1Included++;
      }
      if (budgetKind == 'rent_equal' && actual == 'EXCLUDED') {
        rentEqualExcluded++;
      }
      if (budgetKind == 'rent_plus_1' && actual == 'EXCLUDED') {
        rentPlus1Excluded++;
      }
    }

    final slCases = cases.where((c) => c['marketplace'] == 'shared_living');
    final ipCases = cases.where((c) => c['marketplace'] == 'independent_places');
    final slPattern = _outcomePattern(slCases);
    final ipPattern = _outcomePattern(ipCases);
    final marketplacesConsistent = slPattern == ipPattern;

    final overallVsStrict = fail == 0;
    final productionMatchesStrict =
        WeightedListingMatcher.budgetHardCapRatio == 1.0;

    final blockers = <Map<String, dynamic>>[
      if (!productionMatchesStrict)
        {
          'id': 'HARD_CAP_1_25X_VS_STRICT_CONTRACT',
          'severity': true,
          'detail':
              'Production hard gate is amount <= round(budgetMax * '
              '${WeightedListingMatcher.budgetHardCapRatio}). User success '
              'criteria assume strict rent <= budget (no multiplier). '
              'At budget = rent - 1, rent is still typically INCLUDED because '
              'rent <= round((rent - 1) * 1.25) for all realistic Dublin rents.',
          'rent_minus_1_included_count': rentMinus1Included,
          'expected_under_strict': 'EXCLUDED',
        },
      if (rentEqualExcluded > 0)
        {
          'id': 'EXACT_RENT_EXCLUDED',
          'severity': true,
          'detail':
              'budget = rent was EXCLUDED ($rentEqualExcluded cases). '
              'Violates both production gate and strict contract.',
          'count': rentEqualExcluded,
        },
      if (rentPlus1Excluded > 0)
        {
          'id': 'RENT_PLUS_1_EXCLUDED',
          'severity': true,
          'detail':
              'budget = rent + 1 was EXCLUDED ($rentPlus1Excluded cases).',
          'count': rentPlus1Excluded,
        },
      if (!marketplacesConsistent)
        {
          'id': 'MARKETPLACE_INCONSISTENCY',
          'severity': true,
          'detail':
              'Shared Living and Independent Places outcome patterns differ.',
          'shared_living_pattern': slPattern,
          'independent_places_pattern': ipPattern,
        },
    ];

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'overall_pass': overallVsStrict,
      'overall': overallVsStrict ? 'PASS' : 'FAIL',
      'overall_vs_user_success_criteria': overallVsStrict ? 'PASS' : 'FAIL',
      'production_matches_strict_criteria': productionMatchesStrict,
      'budget_rule': {
        'formula':
            'INCLUDED iff ListingData.listingPriceAmount(listing) <= '
            '(budgetMax * WeightedListingMatcher.budgetHardCapRatio).round()',
        'budget_hard_cap_ratio': WeightedListingMatcher.budgetHardCapRatio,
        'price_field':
            'ListingData.listingPriceAmount — digits parsed from listing '
            '`price` string (monthly rent / room rent as stored)',
        'code_citations': [
          'lib/utils/weighted_listing_matcher.dart '
              '(budgetHardCapRatio=1.25, passesHardExclusion)',
          'lib/utils/listing_search_intent.dart '
              '(ListingSearchFilters._budgetHardCapRatio=1.25)',
          'lib/utils/filter_inventory_stats.dart (_listingWithinBudgetMax)',
          'lib/utils/marketplace_listing_pipeline.dart '
              '(runWithFilters → WeightedListingMatcher.fetchScoredListings)',
          'lib/services/profile_portal_inheritance_service.dart '
              '(seekerFeedDefaults.budgetMax ← roomBudget for SL, '
              'maxBudget for IP; both hydrate from session budget_max)',
        ],
        'user_success_criteria_contract':
            'INCLUDED iff rent <= budget (exact equality included; '
            'rent - 1 excluded; no multiplier)',
        'production_vs_contract': productionMatchesStrict
            ? 'MATCH'
            : 'MISMATCH — production uses 1.25× buffer',
      },
      'success_criteria': {
        'exact_rent_equals_budget_included': rentEqualExcluded == 0,
        'lower_budget_excluded': rentMinus1Included == 0,
        'higher_budget_included': rentPlus1Excluded == 0,
        'sl_ip_behavior_consistent': marketplacesConsistent,
        'all_cells_pass_strict': overallVsStrict,
      },
      'summary': {
        'total_tests': cases.length,
        'pass': pass,
        'fail': fail,
        'shared_living': {
          'listings': selectedShare.length,
          'tests': slCases.length,
          'pass': slPass,
          'fail': slFail,
        },
        'independent_places': {
          'listings': selectedRent.length,
          'tests': ipCases.length,
          'pass': ipPass,
          'fail': ipFail,
        },
        'rent_minus_1_included_under_production': rentMinus1Included,
        'rent_equal_excluded_under_production': rentEqualExcluded,
        'rent_plus_1_excluded_under_production': rentPlus1Excluded,
        'marketplaces_consistent_with_each_other': marketplacesConsistent,
        'shared_living_outcome_pattern': slPattern,
        'independent_places_outcome_pattern': ipPattern,
        'overall': overallVsStrict ? 'PASS' : 'FAIL',
      },
      'selected_listings': {
        'shared_living': [
          for (final l in selectedShare)
            {'listing_id': l.id, 'rent': l.rent, 'marketplace': l.marketplace},
        ],
        'independent_places': [
          for (final l in selectedRent)
            {'listing_id': l.id, 'rent': l.rent, 'marketplace': l.marketplace},
        ],
      },
      'methodology': {
        'active_mode': ActiveMode.explore.storageToken,
        'code_paths': [
          'MarketplaceSpace.fromSession (marketplace tower)',
          'ListingSearchFilters(budgetMax: budget_test) — budget-only hard '
              'gate isolation (no area / occupant / gender confounders)',
          'MarketplaceListingPipeline.runWithFilters '
              '(tower equality → WeightedListingMatcher hard exclusion → rank)',
          'Presence of listing_id in pipeline.ranked → INCLUDED',
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
          'shared_living_priced_count': sharePool.length,
          'independent_places_priced_count': rentPool.length,
          'total_corpus': corpus.length,
        },
        'selection':
            'At least 5 Share + 5 Rent with distinct rents; spread across '
            'low / mid / high percentiles of each marketplace pool.',
        'notes': [
          'Audit measures production hard-gate behavior AND grades each cell '
              'against the user strict contract (rent <= budget).',
          'Budget-only filters isolate the hard cap; Explore seekerFeedDefaults '
              'also forwards SL soft profile fields but budget_max hydrates the '
              'same maxBudget/roomBudget value used here.',
        ],
      },
      'blockers': blockers,
      'failing_rows_sample': [
        for (final c in cases.where((c) => c['result'] == 'FAIL').take(12))
          {
            'listing_id': c['listing_id'],
            'marketplace': c['marketplace'],
            'rent': c['rent'],
            'budget_test': c['budget_test'],
            'budget_kind': c['budget_kind'],
            'hard_cap': c['hard_cap'],
            'expected_result': c['expected_result'],
            'actual_result': c['actual_result'],
            'result': c['result'],
            'fail_reason': c['fail_reason'],
          },
      ],
      'tests': cases,
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/budget_boundary_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/budget_boundary_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'BUDGET_BOUNDARY_AUDIT overall=${overallVsStrict ? 'PASS' : 'FAIL'} '
      'tests=${cases.length} pass=$pass fail=$fail '
      'SL=$slPass/$slFail IP=$ipPass/$ipFail '
      'rent-1_included=$rentMinus1Included '
      'consistent=$marketplacesConsistent '
      'ratio=${WeightedListingMatcher.budgetHardCapRatio}',
    );

    // Harness integrity — do not assert overall PASS (expected FAIL vs strict).
    expect(cases.length, selectedShare.length * 3 + selectedRent.length * 3);
    expect(selectedShare.length, greaterThanOrEqualTo(5));
    expect(selectedRent.length, greaterThanOrEqualTo(5));
    expect(marketplacesConsistent, isTrue,
        reason: 'SL and IP must apply the same budget hard-gate formula');
  });
}

class _PricedListing {
  const _PricedListing({
    required this.id,
    required this.rent,
    required this.marketplace,
    required this.tower,
  });

  final String id;
  final int rent;
  final String marketplace;
  final String tower;
}

class _BudgetCase {
  const _BudgetCase({
    required this.budget,
    required this.kind,
    required this.expectedStrict,
  });

  final int budget;
  final String kind;
  final String expectedStrict;
}

List<_BudgetCase> _budgetCases(int rent) => [
      _BudgetCase(
        budget: rent - 1,
        kind: 'rent_minus_1',
        expectedStrict: 'EXCLUDED',
      ),
      _BudgetCase(
        budget: rent,
        kind: 'rent_equal',
        expectedStrict: 'INCLUDED',
      ),
      _BudgetCase(
        budget: rent + 1,
        kind: 'rent_plus_1',
        expectedStrict: 'INCLUDED',
      ),
    ];

List<_PricedListing> _pricedOfType(
  List<Map<String, dynamic>> corpus,
  String listingType,
) {
  final out = <_PricedListing>[];
  for (final listing in corpus) {
    if (ListingData.listingType(listing) != listingType) continue;
    final rent = ListingData.listingPriceAmount(listing);
    if (rent == null || rent <= 0) continue;
    final isShare = listingType == 'Share';
    out.add(
      _PricedListing(
        id: ListingData.id(listing),
        rent: rent,
        marketplace: isShare ? 'shared_living' : 'independent_places',
        tower: listingType,
      ),
    );
  }
  out.sort((a, b) => a.rent.compareTo(b.rent));
  return out;
}

/// Pick distinct-rent listings spanning low / mid / high of the pool.
List<_PricedListing> _selectDiverse(
  List<_PricedListing> sorted,
  {required int minCount}
) {
  if (sorted.isEmpty) return const [];

  // Deduplicate by rent, keep first id at each rent.
  final byRent = <int, _PricedListing>{};
  for (final item in sorted) {
    byRent.putIfAbsent(item.rent, () => item);
  }
  final unique = byRent.values.toList()
    ..sort((a, b) => a.rent.compareTo(b.rent));

  if (unique.length <= minCount) return unique;

  final last = unique.length - 1;
  final indices = <int>{
    0, // lowest
    (last * 0.25).round(),
    (last * 0.50).round(),
    (last * 0.75).round(),
    last, // highest
  };

  // If collisions shrunk the set, fill from remaining mid points.
  var step = 1;
  while (indices.length < minCount && step < unique.length) {
    for (var i = step; i < unique.length && indices.length < minCount; i += 2) {
      indices.add(i);
    }
    step++;
  }

  final picked = [for (final i in indices.toList()..sort()) unique[i]];
  return picked;
}

Map<String, dynamic> _sessionFor({
  required String marketplace,
  required int budgetMax,
  required String listingId,
}) {
  final isShare = marketplace == 'shared_living';
  final space =
      isShare ? MarketplaceSpace.sharedSpace : MarketplaceSpace.fullRental;
  final now = DateTime.now().toUtc().toIso8601String();
  return <String, dynamic>{
    'email': 'budget-boundary-$listingId@uat.truecircle.dev',
    'full_name': 'Budget Boundary $listingId',
    'detected_city': 'Dublin',
    'mother_tongue': 'English',
    'spoken_languages': ['English'],
    'food_preference': 'No Preference',
    'occupant_type': 'Working Professionals',
    'budget_max': budgetMax,
    'preferred_property_type': space.towerPropertyType,
    'preferred_arrangement': space.arrangementBackend,
    'active_marketplace_space': space.storageToken,
    'profile_onboarding_track': isShare
        ? 'seeker_shared_space'
        : 'seeker_entire_place',
    'trust_stage': 2,
    ActiveModeService.lastActiveModeKey: ActiveMode.explore.storageToken,
    ActiveModeService.lastModeUpdatedAtKey: now,
  };
}

Map<String, dynamic> _runCase({
  required _PricedListing listing,
  required int budgetTest,
  required String expectedStrict,
  required List<Map<String, dynamic>> corpus,
}) {
  final hardCap =
      (budgetTest * WeightedListingMatcher.budgetHardCapRatio).round();
  final productionWouldInclude = listing.rent <= hardCap;

  final session = _sessionFor(
    marketplace: listing.marketplace,
    budgetMax: budgetTest,
    listingId: listing.id,
  );
  final space = MarketplaceSpace.fromSession(session);
  final tower = space.towerPropertyType;

  // Budget-only Explore filters — same hard-gate entry as Active Mode routing
  // audit; isolates budget from area / lifestyle confounders.
  final filters = ListingSearchFilters(budgetMax: budgetTest);

  final pipeline = MarketplaceListingPipeline.runWithFilters(
    allListings: corpus,
    towerPropertyType: tower,
    filters: filters,
    userSession: session,
  );

  final rankedIds = {
    for (final scored in pipeline.ranked) ListingData.id(scored.listing),
  };
  final afterFilterIds = {
    for (final item in pipeline.afterFilters) ListingData.id(item),
  };

  final inRanked = rankedIds.contains(listing.id);
  final inAfterFilters = afterFilterIds.contains(listing.id);
  final actual = inRanked ? 'INCLUDED' : 'EXCLUDED';

  // Cross-check direct hard-exclusion API used by the pipeline.
  final criteria = WeightedFilterCriteria.fromSearchContext(
    filters: filters,
    userSession: session,
    towerPropertyType: tower,
  );
  final listingMap = corpus.firstWhere(
    (l) => ListingData.id(l) == listing.id,
  );
  final directPass = WeightedListingMatcher.passesHardExclusion(
    listingMap,
    criteria,
    filters,
    towerPropertyType: tower,
  );

  final failReasons = <String>[];
  if (actual != expectedStrict) {
    failReasons.add(
      'strict_contract expected $expectedStrict but actual=$actual '
      '(hardCap=$hardCap, rent=${listing.rent}, ratio='
      '${WeightedListingMatcher.budgetHardCapRatio})',
    );
  }
  if (inRanked != productionWouldInclude) {
    failReasons.add(
      'pipeline ranked presence ($inRanked) disagrees with formula '
      'rent<=hardCap ($productionWouldInclude)',
    );
  }
  if (directPass != productionWouldInclude) {
    failReasons.add(
      'passesHardExclusion ($directPass) disagrees with formula '
      '($productionWouldInclude)',
    );
  }
  if (inAfterFilters != inRanked && inRanked) {
    // Ranked subset of afterFilters — ranked without afterFilters is impossible.
    failReasons.add('ranked without afterFilters membership');
  }

  final budgetKind = budgetTest == listing.rent - 1
      ? 'rent_minus_1'
      : budgetTest == listing.rent
          ? 'rent_equal'
          : 'rent_plus_1';

  return {
    'listing_id': listing.id,
    'marketplace': listing.marketplace,
    'tower_property_type': tower,
    'rent': listing.rent,
    'budget_test': budgetTest,
    'budget_kind': budgetKind,
    'hard_cap': hardCap,
    'budget_hard_cap_ratio': WeightedListingMatcher.budgetHardCapRatio,
    'expected_result': expectedStrict,
    'expected_under_production_gate':
        productionWouldInclude ? 'INCLUDED' : 'EXCLUDED',
    'actual_result': actual,
    'in_after_filters': inAfterFilters,
    'in_ranked': inRanked,
    'direct_passes_hard_exclusion': directPass,
    'result': failReasons.isEmpty ? 'PASS' : 'FAIL',
    'fail_reason': failReasons.isEmpty ? '' : failReasons.join('; '),
    'pipeline_stages': {
      'corpus': corpus.length,
      'after_tower': pipeline.afterTower.length,
      'after_filters': pipeline.afterFilters.length,
      'ranked': pipeline.ranked.length,
    },
  };
}

String _outcomePattern(Iterable<Map<String, dynamic>> cases) {
  final parts = <String>[];
  for (final kind in ['rent_minus_1', 'rent_equal', 'rent_plus_1']) {
    final subset = cases.where((c) => c['budget_kind'] == kind).toList();
    if (subset.isEmpty) {
      parts.add('$kind:n/a');
      continue;
    }
    final included = subset.where((c) => c['actual_result'] == 'INCLUDED').length;
    final excluded = subset.length - included;
    parts.add('$kind:INC=$included/EXC=$excluded');
  }
  return parts.join(' | ');
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final summary = payload['summary'] as Map<String, dynamic>;
  final rule = payload['budget_rule'] as Map<String, dynamic>;
  final criteria = payload['success_criteria'] as Map<String, dynamic>;
  final blockers = payload['blockers'] as List<dynamic>;
  final tests = payload['tests'] as List<dynamic>;
  final selected = payload['selected_listings'] as Map<String, dynamic>;
  final failingSample = payload['failing_rows_sample'] as List<dynamic>;
  final sl = summary['shared_living'] as Map<String, dynamic>;
  final ip = summary['independent_places'] as Map<String, dynamic>;

  final buf = StringBuffer();
  buf.writeln('# Budget Boundary Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  buf.writeln(
    '**Overall vs user success criteria: ${payload['overall_vs_user_success_criteria']}**',
  );
  buf.writeln();
  buf.writeln(
    'Production matches strict `rent ≤ budget` contract: '
    '**${payload['production_matches_strict_criteria']}**',
  );
  buf.writeln();
  buf.writeln('| Metric | Value |');
  buf.writeln('|--------|-------|');
  buf.writeln('| Total tests | ${summary['total_tests']} |');
  buf.writeln('| PASS (strict) | ${summary['pass']} |');
  buf.writeln('| FAIL (strict) | ${summary['fail']} |');
  buf.writeln(
    '| Shared Living | pass ${sl['pass']} / fail ${sl['fail']} '
    '(${sl['listings']} listings, ${sl['tests']} tests) |',
  );
  buf.writeln(
    '| Independent Places | pass ${ip['pass']} / fail ${ip['fail']} '
    '(${ip['listings']} listings, ${ip['tests']} tests) |',
  );
  buf.writeln(
    '| SL/IP consistent with each other | '
    '${summary['marketplaces_consistent_with_each_other']} |',
  );
  buf.writeln(
    '| rent−1 INCLUDED under production | '
    '${summary['rent_minus_1_included_under_production']} |',
  );
  buf.writeln();
  buf.writeln('## Exact production budget rule');
  buf.writeln();
  buf.writeln('```');
  buf.writeln(rule['formula']);
  buf.writeln('```');
  buf.writeln();
  buf.writeln(
    '- **Ratio:** `${rule['budget_hard_cap_ratio']}` '
    '(`WeightedListingMatcher.budgetHardCapRatio`)',
  );
  buf.writeln('- **Price field:** ${rule['price_field']}');
  buf.writeln('- **Production vs contract:** ${rule['production_vs_contract']}');
  buf.writeln('- **User contract:** ${rule['user_success_criteria_contract']}');
  buf.writeln();
  buf.writeln('### Code citations');
  buf.writeln();
  for (final cite in rule['code_citations'] as List<dynamic>) {
    buf.writeln('- `$cite`');
  }
  buf.writeln();
  buf.writeln('## Success criteria checklist');
  buf.writeln();
  buf.writeln('| Criterion | Met? |');
  buf.writeln('|-----------|------|');
  buf.writeln(
    '| Exact rent = budget → INCLUDED | '
    '${criteria['exact_rent_equals_budget_included']} |',
  );
  buf.writeln(
    '| budget = rent − 1 → EXCLUDED | '
    '${criteria['lower_budget_excluded']} |',
  );
  buf.writeln(
    '| budget = rent + 1 → INCLUDED | '
    '${criteria['higher_budget_included']} |',
  );
  buf.writeln(
    '| SL and IP consistent | '
    '${criteria['sl_ip_behavior_consistent']} |',
  );
  buf.writeln(
    '| All cells pass strict contract | '
    '${criteria['all_cells_pass_strict']} |',
  );
  buf.writeln();
  buf.writeln('## Selected listings');
  buf.writeln();
  buf.writeln('### Shared Living');
  buf.writeln();
  buf.writeln('| listing_id | rent |');
  buf.writeln('|------------|------|');
  for (final row in selected['shared_living'] as List<dynamic>) {
    final m = row as Map<String, dynamic>;
    buf.writeln('| `${m['listing_id']}` | ${m['rent']} |');
  }
  buf.writeln();
  buf.writeln('### Independent Places');
  buf.writeln();
  buf.writeln('| listing_id | rent |');
  buf.writeln('|------------|------|');
  for (final row in selected['independent_places'] as List<dynamic>) {
    final m = row as Map<String, dynamic>;
    buf.writeln('| `${m['listing_id']}` | ${m['rent']} |');
  }
  buf.writeln();
  buf.writeln('## Blockers');
  buf.writeln();
  if (blockers.isEmpty) {
    buf.writeln('_None._');
  } else {
    for (final b in blockers) {
      final m = b as Map<String, dynamic>;
      buf.writeln('### `${m['id']}`');
      buf.writeln();
      buf.writeln(m['detail']);
      buf.writeln();
    }
  }
  buf.writeln('## Full results matrix');
  buf.writeln();
  buf.writeln(
    '| listing_id | marketplace | rent | budget_test | '
    'expected_result | actual_result | hard_cap | result |',
  );
  buf.writeln(
    '|------------|-------------|------|-------------|'
    '-----------------|---------------|----------|--------|',
  );
  for (final row in tests) {
    final m = row as Map<String, dynamic>;
    buf.writeln(
      '| `${m['listing_id']}` | ${m['marketplace']} | ${m['rent']} | '
      '${m['budget_test']} | ${m['expected_result']} | ${m['actual_result']} | '
      '${m['hard_cap']} | **${m['result']}** |',
    );
  }
  buf.writeln();
  buf.writeln('## Failing rows sample');
  buf.writeln();
  if (failingSample.isEmpty) {
    buf.writeln('_None._');
  } else {
    buf.writeln(
      '| listing_id | marketplace | rent | budget_test | expected | actual | result |',
    );
    buf.writeln(
      '|------------|-------------|------|-------------|----------|--------|--------|',
    );
    for (final row in failingSample) {
      final m = row as Map<String, dynamic>;
      buf.writeln(
        '| `${m['listing_id']}` | ${m['marketplace']} | ${m['rent']} | '
        '${m['budget_test']} | ${m['expected_result']} | ${m['actual_result']} | '
        '**${m['result']}** |',
      );
    }
  }
  buf.writeln();
  buf.writeln('## Marketplace consistency');
  buf.writeln();
  buf.writeln('- SL pattern: `${summary['shared_living_outcome_pattern']}`');
  buf.writeln(
    '- IP pattern: `${summary['independent_places_outcome_pattern']}`',
  );
  buf.writeln(
    '- Consistent: **${summary['marketplaces_consistent_with_each_other']}**',
  );
  buf.writeln();
  buf.writeln(
    '_Generated by `test/budget_boundary_audit_test.dart`. Audit only — '
    'no production budget logic changes._',
  );
  buf.writeln();
  return buf.toString();
}
