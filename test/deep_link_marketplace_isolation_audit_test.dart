import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/utils/listing_data.dart';

/// Deep-Link Marketplace Isolation Audit — navigation isolation for direct URLs.
///
/// Run: `flutter test test/deep_link_marketplace_isolation_audit_test.dart`
///
/// Static + harness verification (no browser automation). Documents exact code
/// paths for each scenario and asserts gate behaviour against the isolation
/// contract: SL context must not surface IP listings (and vice versa).
///
/// Production code paths inspected (read-only):
/// - [GoRouter] `/listing/:id` in `lib/router/app_router.dart` (no marketplace
///   query param; no redirect comparing listing tower vs session)
/// - `ListingDetailScreen._resolveListing` / `_listingSpace` (loads by id;
///   derives UI space from listing, not session)
/// - `MarketplaceContextNotifier.setActiveSpace` (not invoked from detail entry)
/// - `ListingsStorageService.getById` (id lookup only; no tower filter)
void main() {
  test('deep link marketplace isolation audit dump', () {
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
      _scenario(
        scenarioId: 'DL-01',
        title: 'SL seeker opens IP listing URL directly',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        entry: 'direct_url',
      ),
      _scenario(
        scenarioId: 'DL-02',
        title: 'IP seeker opens SL listing URL directly',
        marketplaceContext: 'independent_places',
        listingId: slListingId,
        listingById: byId,
        entry: 'direct_url',
      ),
      _scenario(
        scenarioId: 'DL-03a',
        title: 'Shared link: copy SL URL, open in IP context',
        marketplaceContext: 'independent_places',
        listingId: slListingId,
        listingById: byId,
        entry: 'shared_link',
      ),
      _scenario(
        scenarioId: 'DL-03b',
        title: 'Shared link: copy IP URL, open in SL context',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        entry: 'shared_link',
      ),
      _browserNavScenario(
        scenarioId: 'DL-04',
        title: 'Browser Back / Forward / Refresh',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
      ),
      _scenario(
        scenarioId: 'DL-05',
        title: 'Bookmark entry to listing detail',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
        entry: 'bookmark',
      ),
      _urlManipulationScenario(
        scenarioId: 'DL-06',
        marketplaceContext: 'shared_living',
        listingId: ipListingId,
        listingById: byId,
      ),
      // Positive control — same-marketplace deep link must remain allowed.
      _scenario(
        scenarioId: 'DL-07',
        title: 'SL seeker opens SL listing URL (same marketplace)',
        marketplaceContext: 'shared_living',
        listingId: slListingId,
        listingById: byId,
        entry: 'direct_url',
      ),
    ];

    final crossFails = scenarios
        .where((s) =>
            s['is_cross_marketplace'] == true && s['result'] == 'FAIL')
        .length;
    final sameMarketPass = scenarios
        .where((s) =>
            s['is_cross_marketplace'] == false && s['result'] == 'PASS')
        .length;
    final overallPass = crossFails == 0 &&
        scenarios.every((s) =>
            s['is_cross_marketplace'] == false || s['result'] == 'PASS');

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'overall_pass': overallPass,
      'success_criteria': {
        'cross_marketplace_deep_links_blocked_or_redirected': crossFails == 0,
        'no_silent_marketplace_switch_on_detail_entry': true,
        'same_marketplace_deep_link_allowed': sameMarketPass >= 1,
        'detail_entry_guard_exists': _detailEntryGuardExists,
        'scenarios_pass':
            scenarios.where((s) => s['result'] == 'PASS').length,
        'scenarios_fail':
            scenarios.where((s) => s['result'] == 'FAIL').length,
      },
      'summary': {
        'overall': overallPass ? 'PASS' : 'FAIL',
        'cross_marketplace_failures': crossFails,
        'detail_entry_guard_exists': _detailEntryGuardExists,
        'silent_session_space_switch': false,
        'executed_vs_inferred': {
          'executed': [
            'MarketplaceSpace.fromSession / fromStorageToken (session context)',
            'MarketplaceSpace.fromTowerPropertyType + ListingData.propertyType '
                '(listing marketplace)',
            'Simulated deep-link entry gate mirroring ListingDetailScreen + '
                'app_router behaviour',
            'Corpus id resolution via SampleListingsDublin',
          ],
          'code_inferred_not_browser_automated': [
            'GoRouter browser back/forward/refresh (path URL strategy)',
            'Bookmark cold open of /listing/:id',
            'Clipboard shared-link UX (no dedicated share URL builder found)',
            'HomeScreen return after context.pop / context.go("/")',
          ],
        },
      },
      'guards': {
        'router_redirect_compares_listing_vs_session': false,
        'listing_detail_blocks_cross_marketplace': false,
        'listing_detail_redirects_cross_marketplace': false,
        'listing_detail_warns_cross_marketplace': false,
        'getById_filters_by_tower': false,
        'url_carries_marketplace_query_param': false,
        'detail_derives_ui_space_from_listing': true,
        'detail_calls_setActiveSpace': false,
        'files_cited': [
          'lib/router/app_router.dart',
          'lib/router/app_routes.dart',
          'lib/screens/listing_detail_screen.dart',
          'lib/widgets/listing_detail_page_layout.dart',
          'lib/models/marketplace_space.dart',
          'lib/services/marketplace_context_notifier.dart',
          'lib/services/listings_storage_service.dart',
          'lib/utils/listing_data.dart',
          'lib/screens/home_screen.dart',
          'lib/main.dart',
        ],
      },
      'methodology': {
        'browser_automation': 'unavailable — static + harness only',
        'code_paths': [
          'appRouter GoRoute path=/listing/:id → ListingDetailScreen(listingId) '
              '(lib/router/app_router.dart) — no marketplace path/query param; '
              'GoRouter.redirect has no listing-tower check',
          'ListingDetailScreen._resolveListing: GoRouter.state.extra map OR '
              'ListingsStorageService.getById(id) — no active_marketplace_space gate',
          'ListingDetailScreen._listingSpace = MarketplaceSpace.fromTowerPropertyType('
              'ListingData.propertyType(listing)) — UI/explanations follow listing',
          'ListingDetailPageLayout(space: _listingSpace) — SL vs IP layout from listing',
          'MarketplaceContextNotifier.setActiveSpace not called on detail entry — '
              'session active_marketplace_space unchanged (no silent switch)',
          'Home feed isolation remains tower-filtered; this audit is detail entry only',
        ],
        'listing_corpus': {
          'name': 'SampleListingsDublin',
          'shared_living_probe_id': slListingId,
          'independent_places_probe_id': ipListingId,
          'total': corpus.length,
        },
        'production_code_modified': false,
      },
      'scenarios': scenarios,
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/deep_link_marketplace_isolation_audit.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/deep_link_marketplace_isolation_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'DEEP_LINK_AUDIT overall=${overallPass ? 'PASS' : 'FAIL'} '
      'cross_fails=$crossFails guard=$_detailEntryGuardExists '
      'scenarios=${scenarios.length}',
    );

    // Harness correctness: isolation contract is violated today.
    expect(_detailEntryGuardExists, isFalse,
        reason: 'Audit assumes no detail-entry marketplace guard; '
            'update harness if a guard is added.');
    expect(overallPass, isFalse,
        reason: 'Cross-marketplace deep links are allowed — overall must FAIL '
            'until a detail-entry guard exists.');
    for (final s in scenarios) {
      if (s['is_cross_marketplace'] == true) {
        expect(s['result'], 'FAIL',
            reason: '${s['scenario_id']} must FAIL while guard is absent');
        expect(s['behaviour'], contains('allowed'));
      } else {
        expect(s['result'], 'PASS');
      }
    }
  });
}

/// Mirrors observed production behaviour: no guard comparing session space to
/// listing tower on `/listing/:id` entry.
const _detailEntryGuardExists = false;

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

/// Simulates deep-link / bookmark / shared-link entry as implemented today.
Map<String, dynamic> _simulateDetailEntry({
  required MarketplaceSpace sessionSpace,
  required Map<String, dynamic> listing,
}) {
  // Router: path `/listing/:id` only — no marketplace query consumed.
  // Detail: resolve by id (already have listing), derive UI from listing.
  final listingSpace = MarketplaceSpace.fromTowerPropertyType(
    ListingData.propertyType(listing),
  );
  final cross = listingSpace != sessionSpace;

  // Observed: allowed; no block / redirect / warning; session not switched.
  const behaviour = 'allowed';
  final surfacesOpposite = cross;
  final silentSwitch = false;
  final result = (!surfacesOpposite && !silentSwitch) ? 'PASS' : 'FAIL';

  return {
    'listing_marketplace': _spaceLabel(listingSpace),
    'listing_tower': listingSpace.towerPropertyType,
    'is_cross_marketplace': cross,
    'behaviour': behaviour,
    'blocked': false,
    'redirected': false,
    'warning_shown': false,
    'session_space_after': _spaceLabel(sessionSpace),
    'silent_marketplace_switch': silentSwitch,
    'surfaces_opposite_marketplace_content': surfacesOpposite,
    'ui_space_source': 'listing',
    'result': result,
    'fail_reason': surfacesOpposite
        ? 'Detail entry surfaces ${_spaceLabel(listingSpace)} listing while '
            'session marketplace is ${_spaceLabel(sessionSpace)}; no guard on '
            'ListingDetailScreen / GoRouter /listing/:id'
        : null,
  };
}

Map<String, dynamic> _scenario({
  required String scenarioId,
  required String title,
  required String marketplaceContext,
  required String listingId,
  required Map<String, Map<String, dynamic>> listingById,
  required String entry,
}) {
  final listing = listingById[listingId]!;
  final sessionSpace = _sessionSpace(marketplaceContext);
  final sim = _simulateDetailEntry(
    sessionSpace: sessionSpace,
    listing: listing,
  );

  return {
    'scenario_id': scenarioId,
    'title': title,
    'marketplace_context': marketplaceContext,
    'listing_id': listingId,
    'deep_link_path': '/listing/$listingId',
    'entry': entry,
    'coverage': 'harness_executed',
    ...sim,
  };
}

Map<String, dynamic> _browserNavScenario({
  required String scenarioId,
  required String title,
  required String marketplaceContext,
  required String listingId,
  required Map<String, Map<String, dynamic>> listingById,
}) {
  final listing = listingById[listingId]!;
  final sessionSpace = _sessionSpace(marketplaceContext);
  final sim = _simulateDetailEntry(
    sessionSpace: sessionSpace,
    listing: listing,
  );

  // Refresh on /listing/:id re-enters the same unguarded path.
  // Back to `/` restores HomeScreen with marketplaceContextNotifier from
  // session storage — active space unchanged (code-inferred).
  return {
    'scenario_id': scenarioId,
    'title': title,
    'marketplace_context': marketplaceContext,
    'listing_id': listingId,
    'deep_link_path': '/listing/$listingId',
    'entry': 'browser_nav',
    'coverage': 'code_inferred_plus_harness',
    'browser_notes': {
      'refresh_on_detail':
          'Re-runs ListingDetailScreen._resolveListing via getById; still no '
          'marketplace gate; UI space from listing',
      'back_to_home':
          'context.pop or context.go("/") → HomeScreen uses '
          'marketplaceContextNotifier.activeSpace from session '
          '(active_marketplace_space); session not mutated by detail',
      'forward_to_detail': 'Same unguarded /listing/:id entry as direct URL',
      'path_url_strategy': 'lib/main.dart usePathUrlStrategy() — bookmarkable paths',
    },
    'session_marketplace_preserved_on_home_return': true,
    ...sim,
    // Isolation fails because refresh/forward still surfaces opposite content.
    'result': sim['is_cross_marketplace'] == true ? 'FAIL' : 'PASS',
  };
}

Map<String, dynamic> _urlManipulationScenario({
  required String scenarioId,
  required String marketplaceContext,
  required String listingId,
  required Map<String, Map<String, dynamic>> listingById,
}) {
  final listing = listingById[listingId]!;
  final sessionSpace = _sessionSpace(marketplaceContext);
  final sim = _simulateDetailEntry(
    sessionSpace: sessionSpace,
    listing: listing,
  );

  return {
    'scenario_id': scenarioId,
    'title': 'URL manipulation — marketplace param / listing type / listing-id',
    'marketplace_context': marketplaceContext,
    'listing_id': listingId,
    'deep_link_path': '/listing/$listingId',
    'entry': 'url_manipulation',
    'coverage': 'code_inferred_plus_harness',
    'manipulation_notes': {
      'marketplace_query_param':
          'Not defined on /listing/:id; ?active_marketplace_space= / ?space= '
          'ignored by route builder (only path param id used)',
      'listing_type_in_url':
          'Not present; tower taken from stored listing fields after load',
      'direct_listing_id':
          'Any known id resolves via getById regardless of session tower — '
          'wrong marketplace can be surfaced by swapping id only',
    },
    'wrong_marketplace_surface_possible': true,
    ...sim,
  };
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final buf = StringBuffer();
  final criteria = payload['success_criteria'] as Map<String, dynamic>;
  final summary = payload['summary'] as Map<String, dynamic>;
  final guards = payload['guards'] as Map<String, dynamic>;
  final methodology = payload['methodology'] as Map<String, dynamic>;
  final scenarios = payload['scenarios'] as List<dynamic>;
  final executed =
      (summary['executed_vs_inferred'] as Map)['executed'] as List;
  final inferred = (summary['executed_vs_inferred']
      as Map)['code_inferred_not_browser_automated'] as List;

  buf.writeln('# Deep-Link Marketplace Isolation Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  buf.writeln('**Overall: ${summary['overall']}**');
  buf.writeln();
  buf.writeln('| Criterion | Result |');
  buf.writeln('|-----------|--------|');
  buf.writeln(
      '| Cross-marketplace deep links blocked/redirected | '
      '${criteria['cross_marketplace_deep_links_blocked_or_redirected'] == true ? 'YES' : 'NO'} |');
  buf.writeln(
      '| Detail-entry marketplace guard exists | '
      '${criteria['detail_entry_guard_exists'] == true ? 'YES' : 'NO'} |');
  buf.writeln(
      '| Silent session marketplace switch on detail | '
      '${summary['silent_session_space_switch'] == true ? 'YES' : 'NO'} |');
  buf.writeln(
      '| Same-marketplace deep link allowed | '
      '${criteria['same_marketplace_deep_link_allowed'] == true ? 'YES' : 'NO'} |');
  buf.writeln(
      '| Scenarios PASS / FAIL | '
      '${criteria['scenarios_pass']} / ${criteria['scenarios_fail']} |');
  buf.writeln(
      '| Production code modified | '
      '${methodology['production_code_modified'] == true ? 'YES' : 'NO'} |');
  buf.writeln();
  buf.writeln('## Scenario matrix');
  buf.writeln();
  buf.writeln(
      '| scenario_id | marketplace_context | listing_marketplace | behaviour | result |');
  buf.writeln(
      '|-------------|---------------------|---------------------|-----------|--------|');
  for (final raw in scenarios) {
    final s = raw as Map<String, dynamic>;
    buf.writeln(
      '| `${s['scenario_id']}` | `${s['marketplace_context']}` | '
      '`${s['listing_marketplace']}` | ${s['behaviour']} | '
      '**${s['result']}** |',
    );
  }
  buf.writeln();

  for (final raw in scenarios) {
    final s = raw as Map<String, dynamic>;
    buf.writeln('### `${s['scenario_id']}` — ${s['title']}');
    buf.writeln();
    buf.writeln('- **marketplace_context:** `${s['marketplace_context']}`');
    buf.writeln('- **listing_marketplace:** `${s['listing_marketplace']}`');
    buf.writeln('- **listing_id:** `${s['listing_id']}`');
    buf.writeln('- **deep_link_path:** `${s['deep_link_path']}`');
    buf.writeln('- **entry:** `${s['entry']}`');
    buf.writeln('- **coverage:** `${s['coverage']}`');
    buf.writeln('- **behaviour:** ${s['behaviour']}');
    buf.writeln(
        '- **blocked / redirected / warning:** '
        '${s['blocked']} / ${s['redirected']} / ${s['warning_shown']}');
    buf.writeln(
        '- **silent_marketplace_switch:** ${s['silent_marketplace_switch']}');
    buf.writeln(
        '- **surfaces_opposite_marketplace_content:** '
        '${s['surfaces_opposite_marketplace_content']}');
    buf.writeln('- **ui_space_source:** `${s['ui_space_source']}`');
    buf.writeln(
        '- **session_space_after:** `${s['session_space_after']}`');
    buf.writeln('- **result:** **${s['result']}**');
    if (s['fail_reason'] != null) {
      buf.writeln('- **fail_reason:** ${s['fail_reason']}');
    }
    if (s['browser_notes'] != null) {
      buf.writeln('- **browser_notes:**');
      final notes = s['browser_notes'] as Map<String, dynamic>;
      for (final e in notes.entries) {
        buf.writeln('  - **${e.key}:** ${e.value}');
      }
    }
    if (s['manipulation_notes'] != null) {
      buf.writeln('- **manipulation_notes:**');
      final notes = s['manipulation_notes'] as Map<String, dynamic>;
      for (final e in notes.entries) {
        buf.writeln('  - **${e.key}:** ${e.value}');
      }
    }
    buf.writeln();
  }

  buf.writeln('## Guards on detail entry');
  buf.writeln();
  buf.writeln('| Guard | Present |');
  buf.writeln('|-------|---------|');
  for (final e in guards.entries) {
    if (e.key == 'files_cited') continue;
    final present = e.value == true
        ? 'YES'
        : (e.value == false ? 'NO' : '${e.value}');
    buf.writeln('| `${e.key}` | $present |');
  }
  buf.writeln();
  buf.writeln('### Files cited');
  buf.writeln();
  for (final f in guards['files_cited'] as List) {
    buf.writeln('- `$f`');
  }
  buf.writeln();

  buf.writeln('## Key findings');
  buf.writeln();
  buf.writeln(
      '1. **No marketplace guard on `/listing/:id`.** '
      '`app_router.dart` builds `ListingDetailScreen(listingId: id)` only. '
      '`GoRouter.redirect` handles auth/role aliases, not listing tower vs '
      'session space.');
  buf.writeln(
      '2. **Detail UI follows the listing, not the session.** '
      '`_listingSpace` uses `ListingData.propertyType` → '
      '`MarketplaceSpace.fromTowerPropertyType`, so an SL seeker who opens an '
      'IP URL sees Independent Places layout, apply scoring, and preference '
      'explanations.');
  buf.writeln(
      '3. **Session marketplace is not silently switched.** '
      '`setActiveSpace` is not called on detail entry; returning to `/` keeps '
      'the prior `active_marketplace_space`. Isolation still fails because '
      'opposite-marketplace *content* is shown.');
  buf.writeln(
      '4. **URL has no marketplace dimension.** Path is `/listing/:id` only '
      '(`usePathUrlStrategy`). Swapping the id is enough to surface the other '
      'marketplace; marketplace query params are ignored.');
  buf.writeln(
      '5. **Feed isolation is unrelated and remains intact** (prior Active Mode '
      '/ zero-match audits). This failure is **navigation / deep-link entry**.');
  buf.writeln();
  buf.writeln('## Root cause (FAIL)');
  buf.writeln();
  buf.writeln(
      'Listing detail is treated as a global resource keyed only by listing id. '
      'There is no compare of `marketplaceContextNotifier.activeSpace` / session '
      '`active_marketplace_space` against the resolved listing tower before '
      'rendering. Cross-marketplace deep links, shared links, bookmarks, and '
      'URL id swaps are therefore **allowed**.');
  buf.writeln();

  buf.writeln('## Methodology');
  buf.writeln();
  buf.writeln(
      '- **Browser automation:** ${methodology['browser_automation']}');
  buf.writeln('- **Code paths:**');
  for (final p in methodology['code_paths'] as List) {
    buf.writeln('  - $p');
  }
  buf.writeln('- **Executed (harness):**');
  for (final p in executed) {
    buf.writeln('  - $p');
  }
  buf.writeln('- **Code-inferred (not browser-automated):**');
  for (final p in inferred) {
    buf.writeln('  - $p');
  }
  buf.writeln();
  buf.writeln('## Failure conditions checked');
  buf.writeln();
  buf.writeln('- SL context can surface IP listings (or vice versa)');
  buf.writeln('- Silent marketplace switch');
  buf.writeln('- Wrong marketplace content');
  buf.writeln('- Navigation bypasses separation');
  buf.writeln();
  buf.writeln('## Success criteria');
  buf.writeln();
  buf.writeln(
      'Separation intact for deep links, direct URLs, bookmarks, browser nav, '
      'refresh — **not met** while detail entry remains unguarded.');
  buf.writeln();

  return buf.toString();
}
