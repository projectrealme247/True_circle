import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/utils/listing_data.dart';

/// TRUECIRCLE UAT PHASE 6 — Deep-Link Marketplace Isolation Audit.
///
/// Run: `flutter test test/phase6_deep_link_marketplace_isolation_audit_test.dart`
///
/// Expands the prior audit (`test/deep_link_marketplace_isolation_audit_test.dart`)
/// to the full Phase 6 entry-source matrix + high-risk surface inspection.
/// Production code is not modified (audit-only).
///
/// Locked D1: Shared Living and Independent Places strictly separated.
void main() {
  test('phase 6 deep link marketplace isolation audit dump', () {
    final corpus = SampleListingsDublin.items;
    final byId = <String, Map<String, dynamic>>{
      for (final item in corpus)
        if (ListingData.id(item).isNotEmpty) ListingData.id(item): item,
    };

    final slListingId = _firstId(corpus, 'Share');
    final ipListingId = _firstId(corpus, 'Rent');
    expect(slListingId, isNotEmpty);
    expect(ipListingId, isNotEmpty);

    final scenarios = <Map<String, dynamic>>[
      // 1. Direct listing URL — harness executed (cross + same).
      _entryScenario(
        scenarioId: 'P6-01a',
        entrySource: 'Direct listing URL',
        title: 'SL session opens IP listing URL directly',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        coverage: 'harness_executed',
        channelNotes:
            'GoRoute `/listing/:id` → ListingDetailScreen(listingId); no session vs listing guard.',
      ),
      _entryScenario(
        scenarioId: 'P6-01b',
        entrySource: 'Direct listing URL',
        title: 'IP session opens SL listing URL directly',
        marketplaceContext: 'independent_places',
        listingId: slListingId,
        listingById: byId,
        coverage: 'harness_executed',
        channelNotes:
            'Same unguarded sink as P6-01a (symmetric cross-marketplace).',
      ),
      _entryScenario(
        scenarioId: 'P6-01c',
        entrySource: 'Direct listing URL',
        title: 'SL session opens SL listing URL (same marketplace control)',
        marketplaceContext: 'shared_living',
        listingId: slListingId,
        listingById: byId,
        coverage: 'harness_executed',
        channelNotes: 'Positive control — same-marketplace deep link must remain allowed.',
      ),
      // 2. Shared listing URL.
      _entryScenario(
        scenarioId: 'P6-02a',
        entrySource: 'Shared listing URL',
        title: 'Shared IP URL opened in SL session',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        coverage: 'harness_executed',
        channelNotes:
            'No dedicated share URL builder; shareable path is still `/listing/:id` '
            '(path URL strategy). Clipboard share UX not found.',
      ),
      _entryScenario(
        scenarioId: 'P6-02b',
        entrySource: 'Shared listing URL',
        title: 'Shared SL URL opened in IP session',
        marketplaceContext: 'independent_places',
        listingId: slListingId,
        listingById: byId,
        coverage: 'harness_executed',
        channelNotes: 'Same unguarded `/listing/:id` sink as P6-02a.',
      ),
      // 3. Email deep link.
      _channelAbsentOrNonListingScenario(
        scenarioId: 'P6-03',
        entrySource: 'Email deep link',
        title: 'Transactional / marketing email listing deep link',
        coverage: 'code_inferred',
        evidence:
            'ListingContactService.notifyHost logs host email in debug only; body says '
            '"Review applicants in your dashboard" — no `/listing/:id` seeker deep link. '
            'No firebase_messaging / transactional email deep-link router found.',
        residualRisk:
            'If future emails link to `/listing/:id` without a marketplace guard, '
            'bleed will match P6-01.',
        countsAsBleedIfWiredToUnguardedListingRoute: true,
      ),
      // 4. SMS / WhatsApp deep link.
      _channelAbsentOrNonListingScenario(
        scenarioId: 'P6-04',
        entrySource: 'SMS / WhatsApp deep link',
        title: 'SMS or WhatsApp listing deep link into TrueCircle',
        coverage: 'code_inferred',
        evidence:
            'ListingContactService.whatsAppHandoffUri builds wa.me contact handoff '
            '(host↔applicant viewing chat), not an in-app `/listing/:id` URL. '
            'No SMS deep-link handler found.',
        residualRisk:
            'WhatsApp handoff is off-platform contact only; does not currently '
            'enter marketplace feeds. Future TrueCircle SMS/WA listing links would '
            'hit the same unguarded sink.',
        countsAsBleedIfWiredToUnguardedListingRoute: true,
      ),
      // 5. Push notification deep link.
      _channelAbsentOrNonListingScenario(
        scenarioId: 'P6-05',
        entrySource: 'Push notification deep link',
        title: 'Push notification routes to listing detail',
        coverage: 'code_inferred',
        evidence:
            'No firebase_messaging / flutter_local_notifications / FCM payload '
            'router in pubspec or lib. No push → `/listing/:id` handler.',
        residualRisk:
            'When push is wired, payload must not open opposite-marketplace '
            '`/listing/:id` without a guard.',
        countsAsBleedIfWiredToUnguardedListingRoute: true,
      ),
      // 6. Saved / Favourite listing deep link.
      _channelAbsentOrNonListingScenario(
        scenarioId: 'P6-06',
        entrySource: 'Saved/Favourite listing deep link',
        title: 'Saved or favourite listing re-opens detail',
        coverage: 'code_inferred',
        evidence:
            'No saved-listings / favourites store for marketplace listings. '
            'DiscoverScreen.onFavorite is a stub on people cards (no navigation). '
            'No favourite → `/listing/:id` path.',
        residualRisk:
            'Future saved-listing deep links must compare listing tower to session '
            'active_marketplace_space before render.',
        countsAsBleedIfWiredToUnguardedListingRoute: true,
      ),
      // 7. Browser history deep link.
      _entryScenario(
        scenarioId: 'P6-07',
        entrySource: 'Browser history deep link',
        title: 'Back/forward/refresh or history entry to cross-marketplace listing',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        coverage: 'code_inferred_plus_harness',
        channelNotes:
            'usePathUrlStrategy() makes `/listing/:id` history-addressable. '
            'Refresh re-runs getById with no marketplace gate. Back to `/` restores '
            'HomeScreen session activeSpace (not mutated by detail). Forward re-enters '
            'unguarded detail.',
        backNavigationOverride:
            'pop → prior route OR go("/") → Home uses session active_marketplace_space '
            '(session preserved; detail UI had followed listing)',
      ),
      // 8. Search engine indexed deep link.
      _entryScenario(
        scenarioId: 'P6-08',
        entrySource: 'Search engine indexed deep link',
        title: 'Indexed /listing/:id cold open (SPA SEO residual)',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        coverage: 'code_inferred_plus_harness',
        channelNotes:
            'No per-listing SEO landing routes or sitemap. web/index.html has generic '
            'meta description only. Path URLs remain crawlable in principle; any indexed '
            '`/listing/:id` cold-opens the same unguarded detail builder.',
      ),
    ];

    final highRisk = _highRiskInspection();

    final matrixRows = scenarios.map(_matrixRow).toList();

    final bleedEvents = scenarios
        .where((s) => s['cross_marketplace_exposure'] == 'Y')
        .length;
    final routingDefects = scenarios
        .where((s) => s['routing_defect'] == true)
        .length;
    final fallbackDefects = scenarios
        .where((s) => s['fallback_behaviour_detected'] == 'Y')
        .length;
    final crossRecBleed = highRisk
        .where((h) => h['cross_marketplace_recs_or_related'] == true)
        .length;

    final passCount =
        scenarios.where((s) => s['result'] == 'PASS').length;
    final failCount =
        scenarios.where((s) => s['result'] == 'FAIL').length;
    final naCount =
        scenarios.where((s) => s['result'] == 'N/A').length;

    final overallPass = bleedEvents == 0 &&
        routingDefects == 0 &&
        fallbackDefects == 0 &&
        crossRecBleed == 0 &&
        failCount == 0;

    final assessment = overallPass
        ? 'PASS'
        : (failCount > 0 || bleedEvents > 0 || routingDefects > 0
            ? 'FAIL'
            : 'PASS WITH WARNINGS');

    final closePhase6 = overallPass;
    final auditedAt = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'audit_id': 'TRUECIRCLE_UAT_PHASE_6',
      'audit_version': '6.0',
      'title': 'Deep-Link Marketplace Isolation Audit',
      'audited_at': auditedAt,
      'locked_decision': 'D1 — Shared Living and Independent Places strictly separated; '
          'no cross-marketplace feeds; no fallback; no marketplace bleed',
      'prior_audit': {
        'path_md': 'docs/uat/v1/deep_link_marketplace_isolation_audit.md',
        'path_json': 'docs/uat/v1/deep_link_marketplace_isolation_audit.json',
        'verdict': 'FAIL',
        'note': 'Prior FAIL on `/listing/:id` with no session-vs-listing guard — '
            're-verified unchanged; Phase 6 expands to full entry-source matrix.',
      },
      'final_assessment': assessment,
      'overall_pass': overallPass,
      'phase6_close_recommendation': {
        'can_close_and_move_to_oa07': closePhase6,
        'answer': closePhase6 ? 'YES' : 'NO',
        'rationale': closePhase6
            ? 'Zero bleed, routing, fallback, and cross-marketplace rec defects.'
            : 'Cannot close Phase 6: unguarded `/listing/:id` allows cross-marketplace '
                'detail content (D1 navigation bypass). Fix detail-entry marketplace '
                'guard before OA-07 Trust Layer Separation Impact Analysis.',
        'next': 'OA-07 Trust Layer Separation Impact Analysis',
      },
      'executive_summary': {
        'total_scenarios_tested': scenarios.length,
        'passes': passCount,
        'failures': failCount,
        'not_applicable_channels': naCount,
        'marketplace_bleed_events': bleedEvents,
        'routing_defects': routingDefects,
        'fallback_defects': fallbackDefects,
        'cross_marketplace_recommendation_or_related_bleeds': crossRecBleed,
        'detail_entry_guard_exists': _detailEntryGuardExists,
        'silent_session_marketplace_switch': false,
        'production_code_modified': false,
      },
      'success_criteria': {
        'zero_bleed': bleedEvents == 0,
        'zero_cross_marketplace_recs': crossRecBleed == 0,
        'zero_routing_defects': routingDefects == 0,
        'zero_fallback': fallbackDefects == 0,
        'detail_entry_guard_exists': _detailEntryGuardExists,
      },
      'scenario_matrix': matrixRows,
      'scenarios': scenarios,
      'high_risk_inspection': highRisk,
      'defects': _defects(scenarios, highRisk),
      'guards': {
        'router_redirect_compares_listing_vs_session': false,
        'listing_detail_blocks_cross_marketplace': false,
        'listing_detail_redirects_cross_marketplace': false,
        'listing_detail_warns_cross_marketplace': false,
        'getById_filters_by_tower': false,
        'url_carries_marketplace_query_param': false,
        'detail_derives_ui_space_from_listing': true,
        'detail_calls_setActiveSpace': false,
        'home_feed_tower_filtered': true,
        'search_suggestions_tower_scoped': true,
      },
      'methodology': {
        'browser_automation': 'unavailable — static code-path analysis + Dart harness',
        'executed': [
          'MarketplaceSpace session vs listing tower compare (simulated detail gate)',
          'SampleListingsDublin id resolution (SL/IP probes)',
          'Corpus listing marketplace classification via ListingData.propertyType',
        ],
        'code_inferred': [
          'GoRouter redirect / `/listing/:id` builder (app_router.dart)',
          'ListingDetailScreen._resolveListing / _listingSpace',
          'ListingsStorageService.getById (id-only)',
          'HomeScreen tower filter + back navigation session preservation',
          'ListingContactService email/WhatsApp (no listing deep links)',
          'Absence of push / saved-listings / similar / recently-viewed modules',
          'web/index.html SEO meta + path URL strategy crawl residual',
        ],
        'files_cited': _filesCited,
        'listing_corpus': {
          'name': 'SampleListingsDublin',
          'shared_living_probe_id': slListingId,
          'independent_places_probe_id': ipListingId,
          'total': corpus.length,
        },
        'production_code_modified': false,
      },
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/phase6_deep_link_marketplace_isolation_audit.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/phase6_deep_link_marketplace_isolation_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'PHASE6_DEEP_LINK_AUDIT assessment=$assessment '
      'bleed=$bleedEvents routing=$routingDefects fallback=$fallbackDefects '
      'pass=$passCount fail=$failCount na=$naCount close=${closePhase6 ? 'YES' : 'NO'}',
    );

    expect(_detailEntryGuardExists, isFalse,
        reason: 'Audit assumes no detail-entry marketplace guard; '
            'update harness if a guard is added.');
    expect(assessment, 'FAIL');
    expect(closePhase6, isFalse);
    expect(bleedEvents, greaterThan(0));
    expect(failCount, greaterThan(0));

    for (final s in scenarios) {
      if (s['is_cross_marketplace'] == true &&
          s['channel_status'] == 'active') {
        expect(s['result'], 'FAIL');
        expect(s['cross_marketplace_exposure'], 'Y');
      }
      if (s['is_cross_marketplace'] == false &&
          s['channel_status'] == 'active') {
        expect(s['result'], 'PASS');
        expect(s['cross_marketplace_exposure'], 'N');
      }
    }
  });
}

/// Mirrors observed production behaviour: no guard comparing session space to
/// listing tower on `/listing/:id` entry.
const _detailEntryGuardExists = false;

const _filesCited = [
  'lib/router/app_router.dart',
  'lib/router/app_routes.dart',
  'lib/screens/listing_detail_screen.dart',
  'lib/widgets/listing_detail_page_layout.dart',
  'lib/models/marketplace_space.dart',
  'lib/services/marketplace_context_notifier.dart',
  'lib/services/listings_storage_service.dart',
  'lib/services/listing_contact_service.dart',
  'lib/utils/listing_data.dart',
  'lib/screens/home_screen.dart',
  'lib/screens/discover_screen.dart',
  'lib/screens/user_profile_screen.dart',
  'lib/screens/space_gateway_screen.dart',
  'lib/main.dart',
  'web/index.html',
  'pubspec.yaml',
];

String _firstId(List<Map<String, dynamic>> corpus, String tower) {
  for (final item in corpus) {
    if (ListingData.listingType(item) == tower) {
      return ListingData.id(item);
    }
  }
  return '';
}

MarketplaceSpace _sessionSpace(String marketplaceContext) {
  return marketplaceContext == 'shared_living'
      ? MarketplaceSpace.sharedSpace
      : MarketplaceSpace.fullRental;
}

String _spaceLabel(MarketplaceSpace space) =>
    space == MarketplaceSpace.sharedSpace
        ? 'shared_living'
        : 'independent_places';

Map<String, dynamic> _simulateDetailEntry({
  required MarketplaceSpace sessionSpace,
  required Map<String, dynamic> listing,
}) {
  final listingSpace = MarketplaceSpace.fromTowerPropertyType(
    ListingData.propertyType(listing),
  );
  final cross = listingSpace != sessionSpace;
  final surfacesOpposite = cross;
  const silentSwitch = false;
  final result = (!surfacesOpposite && !silentSwitch) ? 'PASS' : 'FAIL';

  return {
    'listing_marketplace': _spaceLabel(listingSpace),
    'listing_tower': listingSpace.towerPropertyType,
    'marketplace_returned': _spaceLabel(listingSpace),
    'marketplace_expected': _spaceLabel(sessionSpace),
    'is_cross_marketplace': cross,
    'behaviour': 'allowed',
    'blocked': false,
    'redirected': false,
    'warning_shown': false,
    'session_space_after': _spaceLabel(sessionSpace),
    'silent_marketplace_switch': silentSwitch,
    'surfaces_opposite_marketplace_content': surfacesOpposite,
    'ui_space_source': 'listing',
    'related_listings_marketplace': 'N/A — no similar/related module on detail',
    'recommendation_marketplace':
        'N/A — no listing recommendation rail on detail',
    'cross_marketplace_exposure': surfacesOpposite ? 'Y' : 'N',
    'fallback_behaviour_detected': 'N',
    'routing_defect': surfacesOpposite,
    'result': result,
    'fail_reason': surfacesOpposite
        ? 'Detail entry surfaces ${_spaceLabel(listingSpace)} listing while '
            'session marketplace is ${_spaceLabel(sessionSpace)}; no guard on '
            'ListingDetailScreen / GoRouter /listing/:id'
        : null,
  };
}

Map<String, dynamic> _entryScenario({
  required String scenarioId,
  required String entrySource,
  required String title,
  required String marketplaceContext,
  required String listingId,
  required Map<String, Map<String, dynamic>> listingById,
  required String coverage,
  required String channelNotes,
  String? backNavigationOverride,
}) {
  final listing = listingById[listingId]!;
  final sessionSpace = _sessionSpace(marketplaceContext);
  final sim = _simulateDetailEntry(
    sessionSpace: sessionSpace,
    listing: listing,
  );

  return {
    'scenario_id': scenarioId,
    'entry_source': entrySource,
    'title': title,
    'marketplace_context': marketplaceContext,
    'listing_id': listingId,
    'entry_url_route': '/listing/$listingId',
    'coverage': coverage,
    'channel_status': 'active',
    'channel_notes': channelNotes,
    'back_navigation_behaviour': backNavigationOverride ??
        'IconButton: canPop ? pop : go("/"); Home uses session '
            'active_marketplace_space (unchanged by detail)',
    ...sim,
  };
}

Map<String, dynamic> _channelAbsentOrNonListingScenario({
  required String scenarioId,
  required String entrySource,
  required String title,
  required String coverage,
  required String evidence,
  required String residualRisk,
  required bool countsAsBleedIfWiredToUnguardedListingRoute,
}) {
  return {
    'scenario_id': scenarioId,
    'entry_source': entrySource,
    'title': title,
    'marketplace_context': 'N/A',
    'listing_id': null,
    'entry_url_route': 'N/A — channel does not emit /listing/:id',
    'coverage': coverage,
    'channel_status': 'absent_or_non_listing',
    'channel_notes': evidence,
    'residual_risk': residualRisk,
    'counts_as_bleed_if_wired_to_unguarded_listing_route':
        countsAsBleedIfWiredToUnguardedListingRoute,
    'listing_marketplace': 'N/A',
    'listing_tower': null,
    'marketplace_returned': 'N/A',
    'marketplace_expected': 'N/A',
    'is_cross_marketplace': false,
    'behaviour': 'channel_not_applicable',
    'blocked': false,
    'redirected': false,
    'warning_shown': false,
    'session_space_after': 'unchanged',
    'silent_marketplace_switch': false,
    'surfaces_opposite_marketplace_content': false,
    'ui_space_source': 'N/A',
    'related_listings_marketplace': 'N/A',
    'recommendation_marketplace': 'N/A',
    'back_navigation_behaviour': 'N/A — no listing deep-link entry',
    'cross_marketplace_exposure': 'N',
    'fallback_behaviour_detected': 'N',
    'routing_defect': false,
    'result': 'N/A',
    'fail_reason': null,
  };
}

Map<String, dynamic> _matrixRow(Map<String, dynamic> s) {
  return {
    'Entry Source': s['entry_source'],
    'Entry URL/Route': s['entry_url_route'],
    'Marketplace Expected': s['marketplace_expected'],
    'Marketplace Returned': s['marketplace_returned'],
    'Listing Marketplace': s['listing_marketplace'],
    'Related Listings Marketplace': s['related_listings_marketplace'],
    'Recommendation Marketplace': s['recommendation_marketplace'],
    'Back Navigation Behaviour': s['back_navigation_behaviour'],
    'Cross-Marketplace Exposure (Y/N)': s['cross_marketplace_exposure'],
    'Fallback Behaviour Detected (Y/N)': s['fallback_behaviour_detected'],
    'Result (PASS/FAIL)': s['result'],
    'scenario_id': s['scenario_id'],
  };
}

List<Map<String, dynamic>> _highRiskInspection() {
  return [
    {
      'priority': 1,
      'surface': 'Similar Listings modules',
      'status': 'not_present',
      'coverage': 'code_inferred',
      'evidence':
          'No similar/related listings widget or query on ListingDetailScreen / '
          'ListingDetailPageLayout.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No bleed vector from this surface today.',
    },
    {
      'priority': 2,
      'surface': 'Recommendation modules',
      'status': 'not_on_listing_detail',
      'coverage': 'code_inferred',
      'evidence':
          'District recommendation ranker/explainer used in seeker onboarding '
          'areas, not as a listing-detail recommendation rail. Landlord '
          'recommendation chips are applicant-queue triage, not seeker listing recs.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No cross-marketplace listing recs on detail entry.',
    },
    {
      'priority': 3,
      'surface': 'Recently Viewed',
      'status': 'not_present',
      'coverage': 'code_inferred',
      'evidence': 'No recently-viewed / view-history store or UI for listings.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No bleed vector.',
    },
    {
      'priority': 4,
      'surface': 'Saved Listings',
      'status': 'not_present',
      'coverage': 'code_inferred',
      'evidence':
          'No favourites store for listings; DiscoverScreen favorite stub does '
          'not navigate.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No bleed vector today; residual if wired to unguarded detail.',
    },
    {
      'priority': 5,
      'surface': 'Search Re-entry',
      'status': 'tower_scoped_on_home',
      'coverage': 'code_inferred',
      'evidence':
          'HomeScreen `_towerListings` filters `ListingData.listingType == '
          '_selectedPropertyType` from activeSpace. Search suggestions use '
          '_towerListings only.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact':
          'Feed/search isolation intact (D1). Does not mitigate unguarded '
          'deep-link detail entry.',
    },
    {
      'priority': 6,
      'surface': 'SEO Landing Pages',
      'status': 'no_dedicated_seo_landings',
      'coverage': 'code_inferred',
      'evidence':
          'Generic web/index.html meta; no sitemap/per-listing SEO routes. '
          'Path `/listing/:id` remains cold-openable if indexed.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact':
          'Residual: indexed deep links hit same FAIL as direct URL (P6-08).',
    },
    {
      'priority': 7,
      'surface': 'Email Notifications',
      'status': 'debug_host_notify_only',
      'coverage': 'code_inferred',
      'evidence':
          'ListingContactService.notifyHost — no seeker listing deep link URL.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No current email listing deep-link bleed.',
    },
    {
      'priority': 8,
      'surface': 'Push Notification Routing',
      'status': 'not_present',
      'coverage': 'code_inferred',
      'evidence': 'No FCM / local-notification deep-link router in dependencies.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No current push bleed; residual when implemented.',
    },
    {
      'priority': 9,
      'surface': 'User Profile Listing Galleries',
      'status': 'count_only_no_gallery_nav',
      'coverage': 'code_inferred',
      'evidence':
          'UserProfileScreen loads owned listing count via '
          'ListingsStorageService.ownedByCurrentUser; no gallery navigation to '
          '`/listing/:id` found.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact': 'No seeker profile gallery bleed vector.',
    },
    {
      'priority': 10,
      'surface': 'Internal Deep-Link Handlers',
      'status': 'unguarded_listing_route',
      'coverage': 'harness_executed_plus_code_inferred',
      'evidence':
          'Sole listing deep-link handler: GoRoute path=/listing/:id builds '
          'ListingDetailScreen(listingId) with no marketplace compare. '
          'redirect handles auth/role aliases only. getById is id-only. '
          'Home in-app push passes extra map (already tower-filtered feed). '
          'pubspec includes app_links but no AppLinks / uriLinkStream usage in lib/.',
      'cross_marketplace_recs_or_related': false,
      'isolation_impact':
          'PRIMARY DEFECT — any entry source that resolves to `/listing/:id` '
          'can surface opposite marketplace content.',
      'defect': true,
    },
  ];
}

List<Map<String, dynamic>> _defects(
  List<Map<String, dynamic>> scenarios,
  List<Map<String, dynamic>> highRisk,
) {
  final defects = <Map<String, dynamic>>[];

  defects.add({
    'id': 'P6-DEF-01',
    'severity': 'Critical',
    'title': 'No marketplace guard on `/listing/:id` detail entry',
    'reproduction_path':
        'Set session active_marketplace_space=shared_space; open '
        '/listing/<independent_places_id> (direct, shared, history, or SEO).',
    'expected':
        'Block, redirect to matching marketplace, or refuse to render opposite '
        'marketplace listing while session is SL (and vice versa).',
    'actual':
        'Listing loads via getById; UI space derived from listing '
        '(_listingSpace); opposite marketplace content shown; session not switched.',
    'marketplace_impact':
        'D1 navigation bypass — SL seeker can view full IP listing detail '
        '(and vice versa) including layout, apply scoring, preference explanations.',
    'scenario_ids': [
      for (final s in scenarios)
        if (s['result'] == 'FAIL') s['scenario_id'],
    ],
  });

  defects.add({
    'id': 'P6-DEF-02',
    'severity': 'High',
    'title': 'Listing detail treated as global id-keyed resource',
    'reproduction_path':
        'Swap only the listing id in `/listing/:id` while keeping session space.',
    'expected':
        'URL or resolve path carries marketplace dimension, or resolve filters '
        'by tower vs session.',
    'actual':
        'Path has id only; marketplace query params ignored; getById has no '
        'tower filter.',
    'marketplace_impact':
        'Trivial URL manipulation surfaces the other marketplace.',
    'scenario_ids': ['P6-01a', 'P6-01b', 'P6-02a', 'P6-02b', 'P6-07', 'P6-08'],
  });

  final primaryHandler = highRisk.firstWhere(
    (h) => h['surface'] == 'Internal Deep-Link Handlers',
  );
  if (primaryHandler['defect'] == true) {
    defects.add({
      'id': 'P6-DEF-03',
      'severity': 'High',
      'title': 'Internal deep-link handler lacks session-vs-listing compare',
      'reproduction_path': primaryHandler['evidence'],
      'expected':
          'GoRouter redirect or ListingDetailScreen gate compares '
          'marketplaceContextNotifier.activeSpace to listing tower.',
      'actual': 'No compare; builder only passes listingId.',
      'marketplace_impact':
          'All future channels (email/push/saved) that target `/listing/:id` '
          'inherit the bleed until a guard is added.',
      'scenario_ids': ['P6-03', 'P6-04', 'P6-05', 'P6-06'],
    });
  }

  return defects;
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final buf = StringBuffer();
  final exec = payload['executive_summary'] as Map<String, dynamic>;
  final close = payload['phase6_close_recommendation'] as Map<String, dynamic>;
  final criteria = payload['success_criteria'] as Map<String, dynamic>;
  final prior = payload['prior_audit'] as Map<String, dynamic>;
  final methodology = payload['methodology'] as Map<String, dynamic>;
  final scenarios = payload['scenarios'] as List<dynamic>;
  final matrix = payload['scenario_matrix'] as List<dynamic>;
  final highRisk = payload['high_risk_inspection'] as List<dynamic>;
  final defects = payload['defects'] as List<dynamic>;
  final guards = payload['guards'] as Map<String, dynamic>;

  buf.writeln('# TRUECIRCLE UAT PHASE 6 — Deep-Link Marketplace Isolation Audit');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('**Locked decision (D1):** ${payload['locked_decision']}');
  buf.writeln();
  buf.writeln(
      '**Prior audit:** `${prior['path_md']}` — verdict **${prior['verdict']}**. '
      '${prior['note']}');
  buf.writeln();

  buf.writeln('## Executive Summary');
  buf.writeln();
  buf.writeln('| Metric | Count |');
  buf.writeln('|--------|------:|');
  buf.writeln('| Total Scenarios Tested | ${exec['total_scenarios_tested']} |');
  buf.writeln('| Passes | ${exec['passes']} |');
  buf.writeln('| Failures | ${exec['failures']} |');
  buf.writeln('| N/A channels | ${exec['not_applicable_channels']} |');
  buf.writeln('| Marketplace Bleed Events | ${exec['marketplace_bleed_events']} |');
  buf.writeln('| Routing Defects | ${exec['routing_defects']} |');
  buf.writeln('| Fallback Defects | ${exec['fallback_defects']} |');
  buf.writeln(
      '| Cross-marketplace rec/related bleeds | ${exec['cross_marketplace_recommendation_or_related_bleeds']} |');
  buf.writeln(
      '| Detail-entry guard exists | ${exec['detail_entry_guard_exists'] == true ? 'YES' : 'NO'} |');
  buf.writeln(
      '| Silent session marketplace switch | ${exec['silent_session_marketplace_switch'] == true ? 'YES' : 'NO'} |');
  buf.writeln(
      '| Production code modified | ${exec['production_code_modified'] == true ? 'YES' : 'NO'} |');
  buf.writeln();
  buf.writeln('### Success criteria');
  buf.writeln();
  buf.writeln('| Criterion | Met |');
  buf.writeln('|-----------|-----|');
  for (final e in criteria.entries) {
    buf.writeln(
        '| `${e.key}` | ${e.value == true ? 'YES' : 'NO'} |');
  }
  buf.writeln();

  buf.writeln('## Scenario matrix');
  buf.writeln();
  buf.writeln(
      '| Entry Source | Entry URL/Route | Marketplace Expected | Marketplace Returned | Listing Marketplace | Related Listings Marketplace | Recommendation Marketplace | Back Navigation Behaviour | Cross-Marketplace Exposure (Y/N) | Fallback Behaviour Detected (Y/N) | Result (PASS/FAIL) |');
  buf.writeln(
      '|---|---|---|---|---|---|---|---|---|---|---|');
  for (final raw in matrix) {
    final r = raw as Map<String, dynamic>;
    buf.writeln(
      '| ${r['Entry Source']} | `${r['Entry URL/Route']}` | '
      '`${r['Marketplace Expected']}` | `${r['Marketplace Returned']}` | '
      '`${r['Listing Marketplace']}` | ${r['Related Listings Marketplace']} | '
      '${r['Recommendation Marketplace']} | ${r['Back Navigation Behaviour']} | '
      '**${r['Cross-Marketplace Exposure (Y/N)']}** | '
      '${r['Fallback Behaviour Detected (Y/N)']} | '
      '**${r['Result (PASS/FAIL)']}** |',
    );
  }
  buf.writeln();

  buf.writeln('## Detailed Findings');
  buf.writeln();
  for (final raw in scenarios) {
    final s = raw as Map<String, dynamic>;
    buf.writeln('### `${s['scenario_id']}` — ${s['title']}');
    buf.writeln();
    buf.writeln('- **Entry Source:** ${s['entry_source']}');
    buf.writeln('- **Entry URL/Route:** `${s['entry_url_route']}`');
    buf.writeln('- **Coverage:** `${s['coverage']}` (channel: `${s['channel_status']}`)');
    buf.writeln('- **Marketplace Expected:** `${s['marketplace_expected']}`');
    buf.writeln('- **Marketplace Returned:** `${s['marketplace_returned']}`');
    buf.writeln('- **Listing Marketplace:** `${s['listing_marketplace']}`');
    buf.writeln(
        '- **Related Listings Marketplace:** ${s['related_listings_marketplace']}');
    buf.writeln(
        '- **Recommendation Marketplace:** ${s['recommendation_marketplace']}');
    buf.writeln(
        '- **Back Navigation Behaviour:** ${s['back_navigation_behaviour']}');
    buf.writeln(
        '- **Cross-Marketplace Exposure:** ${s['cross_marketplace_exposure']}');
    buf.writeln(
        '- **Fallback Behaviour Detected:** ${s['fallback_behaviour_detected']}');
    buf.writeln('- **Result:** **${s['result']}**');
    if (s['channel_notes'] != null) {
      buf.writeln('- **Evidence:** ${s['channel_notes']}');
    }
    if (s['residual_risk'] != null) {
      buf.writeln('- **Residual risk:** ${s['residual_risk']}');
    }
    if (s['fail_reason'] != null) {
      buf.writeln('- **Fail reason:** ${s['fail_reason']}');
    }
    if (s['listing_id'] != null) {
      buf.writeln('- **Listing id:** `${s['listing_id']}`');
      buf.writeln('- **Session after entry:** `${s['session_space_after']}`');
      buf.writeln(
          '- **Silent marketplace switch:** ${s['silent_marketplace_switch']}');
    }
    buf.writeln();
  }

  buf.writeln('## High-risk inspection');
  buf.writeln();
  buf.writeln('| # | Surface | Status | Cross-marketplace rec/related | Impact |');
  buf.writeln('|---|---------|--------|-------------------------------|--------|');
  for (final raw in highRisk) {
    final h = raw as Map<String, dynamic>;
    buf.writeln(
      '| ${h['priority']} | ${h['surface']} | `${h['status']}` | '
      '${h['cross_marketplace_recs_or_related'] == true ? 'Y' : 'N'} | '
      '${h['isolation_impact']} |',
    );
  }
  buf.writeln();
  for (final raw in highRisk) {
    final h = raw as Map<String, dynamic>;
    buf.writeln('### ${h['priority']}. ${h['surface']}');
    buf.writeln();
    buf.writeln('- **Coverage:** `${h['coverage']}`');
    buf.writeln('- **Evidence:** ${h['evidence']}');
    buf.writeln('- **Isolation impact:** ${h['isolation_impact']}');
    buf.writeln();
  }

  buf.writeln('## Defects');
  buf.writeln();
  for (final raw in defects) {
    final d = raw as Map<String, dynamic>;
    buf.writeln('### `${d['id']}` — ${d['title']}');
    buf.writeln();
    buf.writeln('- **Severity:** ${d['severity']}');
    buf.writeln('- **Reproduction Path:** ${d['reproduction_path']}');
    buf.writeln('- **Expected:** ${d['expected']}');
    buf.writeln('- **Actual:** ${d['actual']}');
    buf.writeln('- **Marketplace Impact:** ${d['marketplace_impact']}');
    buf.writeln(
        '- **Related scenarios:** ${(d['scenario_ids'] as List).map((e) => '`$e`').join(', ')}');
    buf.writeln();
  }

  buf.writeln('## Guards checklist');
  buf.writeln();
  buf.writeln('| Guard | Present |');
  buf.writeln('|-------|---------|');
  for (final e in guards.entries) {
    buf.writeln(
        '| `${e.key}` | ${e.value == true ? 'YES' : (e.value == false ? 'NO' : '${e.value}')} |');
  }
  buf.writeln();

  buf.writeln('## Methodology');
  buf.writeln();
  buf.writeln('- **Browser automation:** ${methodology['browser_automation']}');
  buf.writeln('- **Harness-executed:**');
  for (final p in methodology['executed'] as List) {
    buf.writeln('  - $p');
  }
  buf.writeln('- **Code-inferred:**');
  for (final p in methodology['code_inferred'] as List) {
    buf.writeln('  - $p');
  }
  buf.writeln('- **Files cited:**');
  for (final f in methodology['files_cited'] as List) {
    buf.writeln('  - `$f`');
  }
  buf.writeln();

  buf.writeln('## Final Assessment');
  buf.writeln();
  buf.writeln('**${payload['final_assessment']}**');
  buf.writeln();
  buf.writeln(
      'PASS criteria: 0 bleed, 0 cross-marketplace recs, 0 routing defects, '
      '0 fallback — **not met**.');
  buf.writeln();
  buf.writeln('### Phase 6 close recommendation');
  buf.writeln();
  buf.writeln(
      'Can Phase 6 close and move to OA-07 Trust Layer Separation Impact Analysis? '
      '**${close['answer']}**');
  buf.writeln();
  buf.writeln('${close['rationale']}');
  buf.writeln();

  return buf.toString();
}
