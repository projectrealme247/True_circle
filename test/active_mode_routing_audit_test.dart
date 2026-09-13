import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/services/active_mode_service.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';

/// Active Mode Routing Audit — marketplace isolation for sentinel seekers.
///
/// Run: `flutter test test/active_mode_routing_audit_test.dart`
///
/// Invokes production routing + match path:
/// - [MarketplaceSpace.fromSession] (Active Mode Explore marketplace resolve)
/// - [MarketplaceListingPipeline.runWithFilters] (tower filter → rank)
/// against mixed [SampleListingsDublin] corpus (~40 Share + ~50 Rent).
void main() {
  test('active mode routing audit dump', () {
    final corpus = SampleListingsDublin.items;
    final shareCount =
        corpus.where((l) => ListingData.listingType(l) == 'Share').length;
    final rentCount =
        corpus.where((l) => ListingData.listingType(l) == 'Rent').length;

    final results = <Map<String, dynamic>>[
      for (final seeker in _sentinelSeekers) _runSeeker(seeker, corpus),
    ];

    var totalMatches = 0;
    var crossMarketplace = 0;
    var seekersPass = 0;
    for (final r in results) {
      totalMatches += r['matches_returned'] as int;
      crossMarketplace += r['cross_marketplace_count'] as int;
      if (r['marketplace_correct'] == 'YES') seekersPass++;
    }

    final overallPass =
        seekersPass == results.length && crossMarketplace == 0;

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'overall_pass': overallPass,
      'success_criteria': {
        'marketplace_isolation_100pct': overallPass,
        'cross_marketplace_listings': crossMarketplace,
        'marketplace_bleed': crossMarketplace,
        'seekers_tested': results.length,
        'seekers_pass': seekersPass,
      },
      'summary': {
        'total_matches': totalMatches,
        'cross_marketplace_count': crossMarketplace,
        'overall': overallPass ? 'PASS' : 'FAIL',
      },
      'methodology': {
        'active_mode': ActiveMode.explore.storageToken,
        'code_paths': [
          'MarketplaceSpace.fromSession (marketplace routing from seeker session)',
          'MarketplaceSpace.towerPropertyType (Share vs Rent tower token)',
          'MarketplaceListingPipeline.runWithFilters '
              '(tower equality filter → weighted pool → ListingMatchEngine.rank)',
          'ListingData.listingType / MarketplaceSpace.fromTowerPropertyType '
              '(classify returned listings)',
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
        'marketplace_determination':
            'Canonical tower = ListingData.listingType (listing_type → type → '
            'marketplace_category). Share = shared_living; Rent = independent_places. '
            'Feed isolation is tower equality only in MarketplaceListingPipeline.run '
            '(afterTower).',
        'seeker_dataset': {
          'status': 'reconstructed',
          'note':
              'Frozen UAT seeker JSON is not checked into the repo. Sentinel '
              'preference fields reconstructed from prior UAT chat artifact '
              '(SL-MARKET-01 / IP-MARKET-01) and mapped into app session keys.',
          'source_seeker_ids': ['SL-MARKET-01', 'IP-MARKET-01'],
        },
      },
      'seekers': results,
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/active_mode_routing_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/active_mode_routing_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'ROUTING_AUDIT overall=${overallPass ? 'PASS' : 'FAIL'} '
      'matches=$totalMatches cross=$crossMarketplace '
      'seekers_pass=$seekersPass/${results.length}',
    );

    expect(results.length, 2);
    expect(corpus.length, 90);
    expect(shareCount, 40);
    expect(rentCount, 50);
    for (final r in results) {
      expect(r['marketplace_correct'], 'YES',
          reason:
              '${r['seeker_id']} marketplace isolation failed: '
              'bleed=${r['bleed_listing_ids']}');
    }
    expect(overallPass, isTrue);
  });
}

class _UatSeeker {
  const _UatSeeker({
    required this.seekerId,
    required this.uatScenario,
    required this.marketplace,
    required this.maxBudget,
    required this.preferredLocations,
    required this.occupationType,
    this.roomPreference,
    this.propertyTypePreference,
  });

  final String seekerId;
  final String uatScenario;
  final String marketplace; // shared_living | independent_places
  final int maxBudget;
  final List<String> preferredLocations;
  final String occupationType;
  final String? roomPreference;
  final String? propertyTypePreference;
}

/// Reconstructed from frozen UAT chat artifact (not checked into repo).
const _sentinelSeekers = [
  _UatSeeker(
    seekerId: 'SL-MARKET-01',
    uatScenario:
        'Marketplace Separation Validation — Shared Living Sentinel',
    marketplace: 'shared_living',
    maxBudget: 1000,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6', 'Dublin 8'],
    occupationType: 'professional',
    roomPreference: 'private',
  ),
  _UatSeeker(
    seekerId: 'IP-MARKET-01',
    uatScenario:
        'Marketplace Separation Validation — Independent Places Sentinel',
    marketplace: 'independent_places',
    maxBudget: 2500,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6', 'Dublin 8'],
    occupationType: 'single_professional',
    propertyTypePreference: 'apartment',
  ),
];

Map<String, dynamic> _sessionFor(_UatSeeker seeker) {
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
    'preferred_locations': seeker.preferredLocations,
    if (seeker.roomPreference != null)
      'share_room_layout': seeker.roomPreference == 'private'
          ? 'private_room'
          : 'shared_room',
    if (seeker.propertyTypePreference != null)
      'preferred_layout': seeker.propertyTypePreference,
    'trust_stage': 2,
    ActiveModeService.lastActiveModeKey: ActiveMode.explore.storageToken,
    ActiveModeService.lastModeUpdatedAtKey: now,
  };
}

Map<String, dynamic> _runSeeker(
  _UatSeeker seeker,
  List<Map<String, dynamic>> corpus,
) {
  final session = _sessionFor(seeker);
  final resolvedSpace = MarketplaceSpace.fromSession(session);
  final tower = resolvedSpace.towerPropertyType;
  final marketplaceRequested = seeker.marketplace;
  final marketplaceFromSession = resolvedSpace == MarketplaceSpace.sharedSpace
      ? 'shared_living'
      : 'independent_places';

  // Broad Dublin Active Mode Explore defaults: budget only (no area hard filter).
  final filters = ListingSearchFilters(budgetMax: seeker.maxBudget);

  final pipeline = MarketplaceListingPipeline.runWithFilters(
    allListings: corpus, // mixed Share + Rent — isolation must hold here
    towerPropertyType: tower,
    filters: filters,
    userSession: session,
  );

  // User-visible Active Mode feed = ranked matches (same as home Explore).
  final returned = [
    for (final scored in pipeline.ranked) scored.listing,
  ];

  var slCount = 0;
  var ipCount = 0;
  final returnedIds = <String>[];
  final bleedIds = <String>[];
  final classifications = <Map<String, dynamic>>[];

  for (final listing in returned) {
    final id = ListingData.id(listing);
    final listingMarketplace = _marketplaceOf(listing);
    returnedIds.add(id);
    if (listingMarketplace == 'shared_living') {
      slCount++;
    } else {
      ipCount++;
    }
    final isBleed = listingMarketplace != marketplaceRequested;
    if (isBleed) bleedIds.add(id);
    classifications.add({
      'listing_id': id,
      'marketplace': listingMarketplace,
      'listing_type': ListingData.listingType(listing),
      'title': ListingData.title(listing),
      'is_cross_marketplace': isBleed,
    });
  }

  final marketplaceReturned = returned.isEmpty
      ? marketplaceRequested // empty feed still correctly scoped
      : (slCount > 0 && ipCount > 0)
          ? 'mixed'
          : (slCount > 0 ? 'shared_living' : 'independent_places');

  final marketplaceCorrect = marketplaceFromSession == marketplaceRequested &&
          marketplaceReturned == marketplaceRequested &&
          bleedIds.isEmpty
      ? 'YES'
      : 'NO';

  return {
    'seeker_id': seeker.seekerId,
    'uat_scenario': seeker.uatScenario,
    'marketplace_requested': marketplaceRequested,
    'marketplace_from_session': marketplaceFromSession,
    'tower_property_type': tower,
    'active_mode': ActiveMode.explore.storageToken,
    'marketplace_returned': marketplaceReturned,
    'matches_returned': returned.length,
    'shared_living_count': slCount,
    'independent_places_count': ipCount,
    'cross_marketplace_count': bleedIds.length,
    'marketplace_correct': marketplaceCorrect,
    'returned_listing_ids': returnedIds,
    'bleed_listing_ids': bleedIds,
    'pipeline_stages': {
      'corpus': corpus.length,
      'after_tower': pipeline.afterTower.length,
      'after_filters': pipeline.afterFilters.length,
      'ranked': pipeline.ranked.length,
      'requires_onboarding': pipeline.requiresOnboarding,
    },
    'classifications': classifications,
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
  final overall = summary['overall'];
  final buf = StringBuffer();

  buf.writeln('# Active Mode Routing Audit — TrueCircle V1');
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
    '| 100% marketplace isolation | '
    '${criteria['marketplace_isolation_100pct'] == true ? 'YES' : 'NO'} |',
  );
  buf.writeln(
    '| Cross-marketplace listings | ${criteria['cross_marketplace_listings']} |',
  );
  buf.writeln('| Marketplace bleed | ${criteria['marketplace_bleed']} |');
  buf.writeln(
    '| Seekers pass | ${criteria['seekers_pass']}/${criteria['seekers_tested']} |',
  );
  buf.writeln('| Total matches returned | ${summary['total_matches']} |');
  buf.writeln();

  buf.writeln('## Per-seeker results');
  buf.writeln();
  buf.writeln(
    '| seeker_id | marketplace_requested | marketplace_returned | '
    'matches_returned | shared_living_count | independent_places_count | '
    'marketplace_correct |',
  );
  buf.writeln(
    '|-----------|----------------------|---------------------|'
    '------------------|---------------------|--------------------------|'
    '--------------------|',
  );
  for (final raw in seekers) {
    final r = raw as Map<String, dynamic>;
    buf.writeln(
      '| `${r['seeker_id']}` | ${r['marketplace_requested']} | '
      '${r['marketplace_returned']} | ${r['matches_returned']} | '
      '${r['shared_living_count']} | ${r['independent_places_count']} | '
      '**${r['marketplace_correct']}** |',
    );
  }
  buf.writeln();

  for (final raw in seekers) {
    final r = raw as Map<String, dynamic>;
    final stages = r['pipeline_stages'] as Map<String, dynamic>;
    final ids = (r['returned_listing_ids'] as List<dynamic>).cast<String>();
    final bleed = (r['bleed_listing_ids'] as List<dynamic>).cast<String>();
    buf.writeln('### `${r['seeker_id']}`');
    buf.writeln();
    buf.writeln('- **Scenario:** ${r['uat_scenario']}');
    buf.writeln('- **Active mode:** `${r['active_mode']}`');
    buf.writeln('- **Session marketplace:** `${r['marketplace_from_session']}`');
    buf.writeln('- **Tower token:** `${r['tower_property_type']}`');
    buf.writeln(
      '- **Pipeline:** corpus ${stages['corpus']} → afterTower '
      '${stages['after_tower']} → afterFilters ${stages['after_filters']} → '
      'ranked ${stages['ranked']}',
    );
    buf.writeln('- **marketplace_correct:** **${r['marketplace_correct']}**');
    if (bleed.isNotEmpty) {
      buf.writeln('- **Bleed listing IDs:** ${bleed.map((e) => '`$e`').join(', ')}');
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
  buf.writeln('- **Paths:**');
  for (final p in corpus['paths'] as List<dynamic>) {
    buf.writeln('  - `$p`');
  }
  buf.writeln();
  buf.writeln('### Marketplace determination');
  buf.writeln();
  buf.writeln(methodology['marketplace_determination']);
  buf.writeln();
  buf.writeln('### Seeker dataset');
  buf.writeln();
  final seekerDs = methodology['seeker_dataset'] as Map<String, dynamic>;
  buf.writeln('- **Status:** ${seekerDs['status']}');
  buf.writeln('- **Note:** ${seekerDs['note']}');
  buf.writeln();
  buf.writeln('### Failure conditions checked');
  buf.writeln();
  buf.writeln('- Shared Living seeker receives any Independent Places listings');
  buf.writeln('- Independent Places seeker receives any Shared Living listings');
  buf.writeln('- Marketplace returned differs from marketplace requested');
  buf.writeln();
  buf.writeln(
    'Overall **PASS** only if both sentinels pass with 0 cross-marketplace '
    'listings and 0 marketplace bleed.',
  );
  buf.writeln();

  return buf.toString();
}
