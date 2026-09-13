import 'dart:convert';
import 'dart:io';

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

/// Blank-Field Explanation Audit — "Why this could work for you" must not
/// cite seeker fields that were left blank / unspecified.
///
/// Run: `flutter test test/blank_field_explanation_audit_test.dart`
///
/// Production paths:
/// - [MarketplaceListingPipeline.runWithFilters] (top listings)
/// - [ListingMatchEngine.sharedLivingPreferenceExplanations]
/// - [ListingMatchEngine.independentPlacePreferenceExplanations]
///   (same APIs as listing_detail_screen preference fit labels)
void main() {
  test('blank field explanation audit dump', () {
    final corpus = SampleListingsDublin.items;
    final shareCount =
        corpus.where((l) => ListingData.listingType(l) == 'Share').length;
    final rentCount =
        corpus.where((l) => ListingData.listingType(l) == 'Rent').length;

    final seekerResults = <Map<String, dynamic>>[
      for (final seeker in _selectedPartialSeekers) _runSeeker(seeker, corpus),
    ];

    final invalidRows = <Map<String, dynamic>>[];
    final terminologyRows = <Map<String, dynamic>>[];
    for (final s in seekerResults) {
      invalidRows.addAll(
        (s['invalid_references'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
      terminologyRows.addAll(
        (s['terminology_violations'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );
    }

    final byType = <String, int>{};
    final bySeverity = <String, int>{
      'blocker': 0,
      'high': 0,
      'medium': 0,
    };
    for (final row in invalidRows) {
      final t = row['invalid_reference'] as String;
      byType[t] = (byType[t] ?? 0) + 1;
      final sev = row['severity'] as String;
      bySeverity[sev] = (bySeverity[sev] ?? 0) + 1;
    }

    final blockerCount = bySeverity['blocker']!;
    final highCount = bySeverity['high']!;
    final mediumCount = bySeverity['medium']!;
    final termCount = terminologyRows.length;

    final String overall;
    if (blockerCount > 0 || highCount > 0 || termCount > 0) {
      overall = 'FAIL';
    } else if (mediumCount > 0) {
      overall = 'PASS WITH WARNINGS';
    } else {
      overall = 'PASS';
    }

    final successCriteria = {
      'explanations_only_reference_completed_inputs':
          blockerCount == 0 && highCount == 0,
      'no_fabricated_reasons': blockerCount == 0,
      'no_null_field_references': blockerCount == 0 && highCount == 0,
      'no_cross_marketplace_terminology': termCount == 0,
      'no_misleading_explanation_content':
          blockerCount == 0 && highCount == 0,
      'met': overall == 'PASS',
    };

    final auditedAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'audit_version': '1.0',
      'audited_at': auditedAt,
      'overall': overall,
      'overall_pass': overall == 'PASS',
      'product_rule': {
        'title':
            'Listing-fact-only vs seeker-preference match framing',
        'rule':
            'Preference-fit explanations ("Why this could work for you") must '
            'only claim a seeker preference match when the seeker explicitly '
            'provided that preference. Neutral listing facts may appear '
            'elsewhere on the detail page, but must not be framed as '
            '"matches your preference" when the field is blank / any / '
            'no_preference.',
        'code_observation':
            'Explanation generators gate preference-framed copy on explicit '
            'seeker prefs: SL room requires non-empty roomFromSeeker; bathroom '
            'requires non-empty/non-no_preference bath token; household uses '
            'occupantMatch/studentMatch only (not roommateTypeMatch alone); '
            'availability requires SeekerMoveInWindow.fromSession != null; '
            'lifestyle requires explicit food preference. Matching blank-compat '
            '(roomCompatible/bathroomCompatible/flexible timing) is unchanged. '
            'IP property-type/bedrooms already gated; commute on hasCommuteIntent.',
        'classification_guidance':
            'Preference-framed copy from a null/blank seeker field = blocker '
            'or high. Soft listing-only facts framed neutrally = out of scope '
            'for this card (not emitted by these APIs today).',
      },
      'success_criteria': successCriteria,
      'summary': {
        'overall': overall,
        'seekers_tested': seekerResults.length,
        'invalid_reference_rows': invalidRows.length,
        'terminology_violation_rows': termCount,
        'by_severity': bySeverity,
        'by_invalid_reference_type': byType,
      },
      'selected_seekers': [
        for (final s in _selectedPartialSeekers)
          {
            'seeker_id': s.seekerId,
            'marketplace': s.marketplace,
            'uat_scenario': s.uatScenario,
            'blank_fields': s.blankFields,
            'provided_fields': s.providedFields,
            'synthetic_variant': s.syntheticVariant,
            'source_seeker_id': s.sourceSeekerId,
          },
      ],
      'invalid_references': invalidRows,
      'terminology_violations': terminologyRows,
      'blockers': [
        for (final r in invalidRows)
          if (r['severity'] == 'blocker') r,
      ],
      'high': [
        for (final r in invalidRows)
          if (r['severity'] == 'high') r,
      ],
      'medium': [
        for (final r in invalidRows)
          if (r['severity'] == 'medium') r,
      ],
      'seekers': seekerResults,
      'methodology': {
        'active_mode': ActiveMode.explore.storageToken,
        'code_paths': [
          'MarketplaceSpace.fromSession',
          'MarketplaceListingPipeline.runWithFilters (tower → rank)',
          'ListingMatchEngine.sharedLivingPreferenceExplanations',
          'ListingMatchEngine.independentPlacePreferenceExplanations',
          'listing_detail_screen._preferenceFitLabels (wrapper)',
        ],
        'listing_corpus': {
          'name': 'SampleListingsDublin',
          'shared_living_count': shareCount,
          'independent_places_count': rentCount,
          'total': corpus.length,
        },
        'seeker_dataset': {
          'status': 'reconstructed',
          'note':
              'Frozen UAT seeker JSON is not checked into the repo. Partial '
              'seekers reconstructed from prior UAT chat artifact (66 seekers '
              'with uat_validation_points). Blank-move / blank-household '
              'variants are synthetic derivatives of UAT rows to cover '
              'dimensions absent from the frozen set (all 66 had '
              'desired_move_date; all had occupation_type).',
          'session_key_mapping': {
            'room_preference (SL)':
                'preferred_layout = private_room | shared_room '
                '(roomFromSeeker). Omitted when any/blank.',
            'property_type (IP)':
                'property_type_preference session key '
                '(PropertyTypePreference.fromSession). any → no_preference.',
            'move_date':
                'desired_move_date → earliest_move_in_date '
                '(MoveInTimingMigration → move_in_window).',
            'commute_blank':
                'commute_destination_unknown=true; no commute profiles; '
                'no maximum_commute_budget_minutes.',
            'bathroom_blank': 'bathroom_preference omitted',
          },
        },
        'top_n': 5,
      },
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/blank_field_explanation_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/blank_field_explanation_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // ignore: avoid_print
    print(
      'BLANK_FIELD_EXPLANATION_AUDIT overall=$overall '
      'invalid=${invalidRows.length} term=$termCount '
      'blocker=$blockerCount high=$highCount medium=$mediumCount '
      'seekers=${seekerResults.length}',
    );

    expect(seekerResults.length, _selectedPartialSeekers.length);
    expect(corpus.length, 90);
    for (final s in seekerResults) {
      expect(s['marketplace_correct'], 'YES',
          reason: '${s['seeker_id']} marketplace isolation failed');
    }
  });
}

class _PartialSeeker {
  const _PartialSeeker({
    required this.seekerId,
    required this.uatScenario,
    required this.marketplace,
    required this.maxBudget,
    required this.preferredLocations,
    required this.occupationType,
    required this.blankFields,
    required this.providedFields,
    this.roomPreference,
    this.propertyTypePreference,
    this.transit,
    this.commutePriority,
    this.desiredMoveDate,
    this.bathroomPreference,
    this.omitOccupantType = false,
    this.syntheticVariant = false,
    this.sourceSeekerId,
  });

  final String seekerId;
  final String uatScenario;
  final String marketplace;
  final int maxBudget;
  final List<String> preferredLocations;
  final String occupationType;
  final List<String> blankFields;
  final List<String> providedFields;
  final String? roomPreference;
  final String? propertyTypePreference;
  final String? transit;
  final String? commutePriority;
  final String? desiredMoveDate;
  final String? bathroomPreference;
  final bool omitOccupantType;
  final bool syntheticVariant;
  final String? sourceSeekerId;
}

/// Representative partial seekers covering blank dimensions across SL + IP.
const _selectedPartialSeekers = [
  _PartialSeeker(
    seekerId: 'SL-EDGE-05',
    uatScenario: 'Edge · broad criteria · many matches',
    marketplace: 'shared_living',
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
    roomPreference: 'any',
    transit: 'none',
    commutePriority: 'low',
    desiredMoveDate: '2026-10-01',
    blankFields: [
      'room_preference',
      'property_type_preference',
      'transit_preference',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'SL-STU-10',
    uatScenario:
        'Student · shared · medium budget · no transit preference · broad',
    marketplace: 'shared_living',
    maxBudget: 620,
    preferredLocations: ['Dublin 6', 'Dublin 8', 'Dublin 12', 'Dublin 14'],
    occupationType: 'student',
    roomPreference: 'shared',
    transit: 'none',
    commutePriority: 'low',
    desiredMoveDate: '2026-09-01',
    blankFields: [
      'property_type_preference',
      'transit_preference',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'room_preference',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'SL-PRO-08',
    uatScenario:
        'Professional · shared · medium budget · hybrid · no parking',
    marketplace: 'shared_living',
    maxBudget: 800,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6', 'Dublin 8'],
    occupationType: 'professional',
    roomPreference: 'shared',
    transit: 'any',
    commutePriority: 'low',
    desiredMoveDate: '2026-11-01',
    blankFields: [
      'property_type_preference',
      'commute_destination',
      'bathroom_preference',
      'transit_preference_specific',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'room_preference',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'SL-EDGE-05-BLANK-MOVE',
    sourceSeekerId: 'SL-EDGE-05',
    syntheticVariant: true,
    uatScenario:
        'Synthetic · SL-EDGE-05 with desired_move_date stripped',
    marketplace: 'shared_living',
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
    roomPreference: 'any',
    transit: 'none',
    commutePriority: 'low',
    desiredMoveDate: null,
    blankFields: [
      'room_preference',
      'desired_move_date',
      'transit_preference',
      'commute_destination',
      'bathroom_preference',
      'property_type_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
    ],
  ),
  _PartialSeeker(
    seekerId: 'SL-EDGE-05-BLANK-HH',
    sourceSeekerId: 'SL-EDGE-05',
    syntheticVariant: true,
    uatScenario:
        'Synthetic · SL-EDGE-05 with occupant_type omitted',
    marketplace: 'shared_living',
    maxBudget: 1100,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6', 'Dublin 8'],
    occupationType: 'professional',
    omitOccupantType: true,
    roomPreference: 'any',
    transit: 'none',
    commutePriority: 'low',
    desiredMoveDate: '2026-10-01',
    blankFields: [
      'room_preference',
      'household_preference',
      'transit_preference',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'IP-EDGE-03',
    uatScenario: 'Edge · premium budget · broad · many matches',
    marketplace: 'independent_places',
    maxBudget: 5000,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6', 'Blackrock'],
    occupationType: 'couple',
    propertyTypePreference: 'any',
    transit: 'any',
    commutePriority: 'low',
    desiredMoveDate: '2026-09-01',
    blankFields: [
      'property_type_preference',
      'bedroom_layout',
      'room_preference',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'IP-EDGE-07',
    uatScenario: 'Edge · broad any property · high budget · many matches',
    marketplace: 'independent_places',
    maxBudget: 3600,
    preferredLocations: [
      'Dublin 1',
      'Dublin 2',
      'Dublin 3',
      'Dublin 4',
      'Dublin 6',
      'Dublin 7',
      'Dublin 8',
      'Dublin 14',
    ],
    occupationType: 'couple',
    propertyTypePreference: 'any',
    transit: 'any',
    commutePriority: 'low',
    desiredMoveDate: '2026-09-01',
    blankFields: [
      'property_type_preference',
      'bedroom_layout',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'IP-EDGE-05',
    uatScenario: 'Edge · parking above all else · medium budget suburbs',
    marketplace: 'independent_places',
    maxBudget: 2000,
    preferredLocations: ['Dublin 14', 'Dublin 15', 'Dublin 16', 'Swords'],
    occupationType: 'single_professional',
    propertyTypePreference: 'apartment',
    transit: 'none',
    commutePriority: 'low',
    desiredMoveDate: '2026-09-05',
    blankFields: [
      'transit_preference',
      'commute_destination',
      'bedroom_layout',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'property_type_preference',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'IP-CPL-02',
    uatScenario: 'Couple · premium budget · city/southside',
    marketplace: 'independent_places',
    maxBudget: 3500,
    preferredLocations: [
      'Dublin 2',
      'Dublin 4',
      'Ranelagh',
      'Ballsbridge',
    ],
    occupationType: 'couple',
    propertyTypePreference: 'apartment',
    transit: 'any',
    commutePriority: 'low',
    desiredMoveDate: '2026-10-01',
    blankFields: [
      'commute_destination',
      'bedroom_layout',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
      'property_type_preference',
      'desired_move_date',
    ],
  ),
  _PartialSeeker(
    seekerId: 'IP-EDGE-03-BLANK-MOVE',
    sourceSeekerId: 'IP-EDGE-03',
    syntheticVariant: true,
    uatScenario:
        'Synthetic · IP-EDGE-03 with desired_move_date stripped',
    marketplace: 'independent_places',
    maxBudget: 5000,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6', 'Blackrock'],
    occupationType: 'couple',
    propertyTypePreference: 'any',
    transit: 'any',
    commutePriority: 'low',
    desiredMoveDate: null,
    blankFields: [
      'property_type_preference',
      'bedroom_layout',
      'desired_move_date',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'occupation_type',
    ],
  ),
  _PartialSeeker(
    seekerId: 'IP-EDGE-03-BLANK-HH',
    sourceSeekerId: 'IP-EDGE-03',
    syntheticVariant: true,
    uatScenario:
        'Synthetic · IP-EDGE-03 with occupant_type omitted',
    marketplace: 'independent_places',
    maxBudget: 5000,
    preferredLocations: ['Dublin 2', 'Dublin 4', 'Dublin 6'],
    occupationType: 'couple',
    omitOccupantType: true,
    propertyTypePreference: 'any',
    transit: 'any',
    commutePriority: 'low',
    desiredMoveDate: '2026-09-01',
    blankFields: [
      'property_type_preference',
      'bedroom_layout',
      'household_preference',
      'commute_destination',
      'bathroom_preference',
    ],
    providedFields: [
      'max_budget',
      'preferred_locations',
      'desired_move_date',
    ],
  ),
];

Map<String, dynamic> _sessionFor(_PartialSeeker seeker) {
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
    'profile_onboarding_track': isShare
        ? 'seeker_shared_space'
        : 'seeker_entire_place',
    'preferred_locations': seeker.preferredLocations,
    'trust_stage': 2,
    ActiveModeService.lastActiveModeKey: ActiveMode.explore.storageToken,
    ActiveModeService.lastModeUpdatedAtKey: now,
  };

  if (!seeker.omitOccupantType) {
    session['occupant_type'] = _occupantToken(seeker.occupationType);
  }

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
    } else if (prop == 'house' ||
        prop == 'detached_house' ||
        prop.contains('house')) {
      session[PropertyTypePreference.sessionKey] =
          PropertyTypePreference.house.storageToken;
    } else if (prop == 'apartment' || prop == 'studio') {
      session[PropertyTypePreference.sessionKey] =
          PropertyTypePreference.apartment.storageToken;
      if (prop == 'studio') {
        session['preferred_layout'] = 'Studio';
      }
    }
  }

  if (seeker.bathroomPreference != null) {
    session['bathroom_preference'] = seeker.bathroomPreference;
  }

  final commuteBlank = seeker.blankFields.contains('commute_destination') ||
      seeker.commutePriority == 'low' ||
      seeker.commutePriority == 'none' ||
      seeker.transit == 'none' ||
      seeker.transit == null;
  if (commuteBlank) {
    session['commute_destination_unknown'] = true;
  }

  if (seeker.transit != null &&
      seeker.transit != 'none' &&
      seeker.transit != 'any') {
    session['preferred_transit'] = seeker.transit;
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
  if (o.contains('family')) return 'Family';
  if (o.contains('couple')) return 'Family';
  return 'Working Professionals';
}

Map<String, dynamic> _runSeeker(
  _PartialSeeker seeker,
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

  final top = pipeline.ranked.take(5).toList();
  final listingRows = <Map<String, dynamic>>[];
  final invalidRefs = <Map<String, dynamic>>[];
  final termViolations = <Map<String, dynamic>>[];

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

    final signals = <String>[];
    for (final text in explanations) {
      signals.addAll(_extractSignals(text));
      for (final issue in _validateExplanation(
        seeker: seeker,
        listingId: listingId,
        explanation: text,
      )) {
        invalidRefs.add(issue);
      }
      for (final term in _validateTerminology(
        seeker: seeker,
        listingId: listingId,
        explanation: text,
      )) {
        termViolations.add(term);
      }
    }

    listingRows.add({
      'listing_id': listingId,
      'marketplace': listingMp,
      'title': ListingData.title(listing),
      'explanations': explanations,
      'referenced_signals': signals.toSet().toList()..sort(),
    });
  }

  final bleed = [
    for (final row in listingRows)
      if (row['marketplace'] != marketplaceRequested)
        row['listing_id'] as String,
  ];

  return {
    'seeker_id': seeker.seekerId,
    'source_seeker_id': seeker.sourceSeekerId,
    'synthetic_variant': seeker.syntheticVariant,
    'uat_scenario': seeker.uatScenario,
    'marketplace_requested': marketplaceRequested,
    'marketplace_from_session': marketplaceFromSession,
    'marketplace_correct':
        marketplaceFromSession == marketplaceRequested && bleed.isEmpty
            ? 'YES'
            : 'NO',
    'blank_fields': seeker.blankFields,
    'provided_fields': seeker.providedFields,
    'matches_returned': pipeline.ranked.length,
    'top_listing_ids': [
      for (final row in listingRows) row['listing_id'],
    ],
    'top_listings': listingRows,
    'invalid_references': invalidRefs,
    'terminology_violations': termViolations,
    'pipeline_stages': {
      'corpus': corpus.length,
      'after_tower': pipeline.afterTower.length,
      'after_filters': pipeline.afterFilters.length,
      'ranked': pipeline.ranked.length,
    },
  };
}

List<String> _extractSignals(String text) {
  final lower = text.toLowerCase();
  final signals = <String>[];
  if (lower.contains('budget')) signals.add('budget');
  if (lower.contains('bedroom')) signals.add('bedrooms');
  if (lower.contains('available when you plan to move') ||
      lower.contains('availability')) {
    signals.add('availability');
  }
  if (lower.contains('commute')) signals.add('commute');
  if (lower.contains('preferred area') || lower.contains('location')) {
    signals.add('location');
  }
  if (lower.contains('property type')) signals.add('property_type');
  if (lower.contains('private room') || lower.contains('shared room')) {
    signals.add('room_type');
  }
  if (lower.contains('bathroom')) signals.add('bathroom');
  if (lower.contains('household') ||
      lower.contains('student household') ||
      lower.contains('professional household')) {
    signals.add('household');
  }
  if (lower.contains('lifestyle')) signals.add('lifestyle');
  if (lower.contains('parking')) signals.add('parking');
  return signals;
}

List<Map<String, dynamic>> _validateExplanation({
  required _PartialSeeker seeker,
  required String listingId,
  required String explanation,
}) {
  final lower = explanation.toLowerCase();
  final blanks = seeker.blankFields.toSet();
  final issues = <Map<String, dynamic>>[];

  void flag(String type, String severity, String note) {
    issues.add({
      'listing_id': listingId,
      'seeker_id': seeker.seekerId,
      'explanation_text': explanation,
      'invalid_reference': type,
      'severity': severity,
      'note': note,
    });
  }

  if (lower.contains('commute') &&
      (blanks.contains('commute_destination') ||
          seeker.commutePriority == 'low' ||
          seeker.commutePriority == 'none' ||
          seeker.transit == 'none')) {
    flag(
      'commute_without_seeker_commute',
      'blocker',
      'Commute referenced while seeker has no commute destination / low-none priority',
    );
  }

  if ((lower.contains('available when you plan to move') ||
          lower.contains('plan to move')) &&
      (blanks.contains('desired_move_date') ||
          seeker.desiredMoveDate == null ||
          seeker.desiredMoveDate!.isEmpty)) {
    flag(
      'availability_without_move_date',
      'blocker',
      'Availability timing framed as seeker plan with blank move date',
    );
  }

  if ((lower.contains('room matches your preference') ||
          lower.contains('private room matches') ||
          lower.contains('shared room matches')) &&
      (blanks.contains('room_preference') ||
          seeker.roomPreference == null ||
          seeker.roomPreference == 'any' ||
          seeker.roomPreference == 'no_preference')) {
    flag(
      'room_preference_without_seeker_input',
      'blocker',
      'Room preference claim with room_preference blank/any',
    );
  }

  if (lower.contains('preferred property type') &&
      (blanks.contains('property_type_preference') ||
          seeker.propertyTypePreference == null ||
          seeker.propertyTypePreference == 'any')) {
    flag(
      'property_type_without_seeker_input',
      'blocker',
      'Property type preference claim with blank/any property type',
    );
  }

  if ((lower.contains('household') ||
          lower.contains('student household') ||
          lower.contains('professional household')) &&
      (blanks.contains('household_preference') || seeker.omitOccupantType)) {
    flag(
      'household_without_seeker_input',
      'blocker',
      'Household preference claim with occupant_type omitted',
    );
  }

  if (lower.contains('bathroom') &&
      lower.contains('preference') &&
      (blanks.contains('bathroom_preference') ||
          seeker.bathroomPreference == null)) {
    flag(
      'bathroom_without_seeker_input',
      'blocker',
      'Bathroom preference claim with bathroom_preference blank',
    );
  }

  if (lower.contains('bedroom') &&
      (blanks.contains('bedroom_layout') ||
          (seeker.marketplace == 'independent_places' &&
              (seeker.propertyTypePreference == 'any' ||
                  seeker.propertyTypePreference == null)))) {
    if (lower.contains('your needs') || lower.contains('match')) {
      flag(
        'bedrooms_without_seeker_layout',
        'blocker',
        'Bedroom preference claim without preferred_layout bed requirement',
      );
    }
  }

  if (lower.contains('lifestyle') && seeker.marketplace == 'shared_living') {
    flag(
      'lifestyle_without_seeker_lifestyle_prefs',
      'high',
      'Lifestyle compatibility claimed; UAT seekers only set food=No Preference',
    );
  }

  if (lower.contains('preferred area') &&
      seeker.preferredLocations.isNotEmpty) {
    flag(
      'location_copy_vs_city_match',
      'medium',
      'Copy says preferred area; _locationMatch uses detected_city (Dublin), '
          'not preferred_locations list',
    );
  }

  return issues;
}

List<Map<String, dynamic>> _validateTerminology({
  required _PartialSeeker seeker,
  required String listingId,
  required String explanation,
}) {
  final lower = explanation.toLowerCase();
  final issues = <Map<String, dynamic>>[];

  void flag(String type) {
    issues.add({
      'listing_id': listingId,
      'seeker_id': seeker.seekerId,
      'explanation_text': explanation,
      'invalid_reference': type,
      'severity': 'high',
      'note': 'Cross-marketplace terminology',
    });
  }

  if (seeker.marketplace == 'shared_living') {
    if (lower.contains('bedroom') ||
        lower.contains('entire') ||
        lower.contains('property type') ||
        lower.contains('bedrooms match')) {
      flag('sl_references_ip_terminology');
    }
  } else {
    if (lower.contains('private room') ||
        lower.contains('shared room') ||
        lower.contains('household culture') ||
        lower.contains('lifestyle looks compatible') ||
        lower.contains('household lifestyle') ||
        lower.contains('bathroom setup matches')) {
      flag('ip_references_sl_terminology');
    }
  }

  return issues;
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final buf = StringBuffer();
  final summary = payload['summary'] as Map<String, dynamic>;
  final bySev = summary['by_severity'] as Map<String, dynamic>;
  final byType = summary['by_invalid_reference_type'] as Map<String, dynamic>;
  final criteria = payload['success_criteria'] as Map<String, dynamic>;
  final productRule = payload['product_rule'] as Map<String, dynamic>;
  final selected = payload['selected_seekers'] as List<dynamic>;
  final terms = payload['terminology_violations'] as List<dynamic>;
  final seekers = payload['seekers'] as List<dynamic>;
  final overall = payload['overall'];

  buf.writeln('# Blank-Field Explanation Audit — TrueCircle V1');
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
    '| Invalid reference rows | ${summary['invalid_reference_rows']} |',
  );
  buf.writeln(
    '| Terminology violations | ${summary['terminology_violation_rows']} |',
  );
  buf.writeln('| Blocker | ${bySev['blocker']} |');
  buf.writeln('| High | ${bySev['high']} |');
  buf.writeln('| Medium | ${bySev['medium']} |');
  buf.writeln();

  buf.writeln('## Success criteria');
  buf.writeln();
  buf.writeln('| Criterion | Met? |');
  buf.writeln('|-----------|------|');
  for (final e in criteria.entries) {
    if (e.key == 'met') continue;
    buf.writeln('| ${e.key} | ${e.value} |');
  }
  buf.writeln();

  buf.writeln('## Product rule — listing facts vs preference matches');
  buf.writeln();
  buf.writeln(productRule['rule']);
  buf.writeln();
  buf.writeln('**Code observation:** ${productRule['code_observation']}');
  buf.writeln();
  buf.writeln(
    '**Classification guidance:** ${productRule['classification_guidance']}',
  );
  buf.writeln();

  buf.writeln('## PART 1 — Selected partial seekers');
  buf.writeln();
  buf.writeln(
    '| seeker_id | marketplace | blank_fields | synthetic |',
  );
  buf.writeln('|-----------|-------------|--------------|-----------|');
  for (final raw in selected) {
    final s = raw as Map<String, dynamic>;
    final blanks = (s['blank_fields'] as List<dynamic>).join(', ');
    buf.writeln(
      '| `${s['seeker_id']}` | ${s['marketplace']} | $blanks | '
      '${s['synthetic_variant'] == true ? 'YES' : 'NO'} |',
    );
  }
  buf.writeln();

  buf.writeln('## Invalid references by type');
  buf.writeln();
  if (byType.isEmpty) {
    buf.writeln('_None_');
  } else {
    buf.writeln('| type | count |');
    buf.writeln('|------|-------|');
    final entries = byType.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    for (final e in entries) {
      buf.writeln('| `${e.key}` | ${e.value} |');
    }
  }
  buf.writeln();

  buf.writeln('## Blockers');
  buf.writeln();
  final blockers = payload['blockers'] as List<dynamic>;
  if (blockers.isEmpty) {
    buf.writeln('_None_');
  } else {
    buf.writeln(
      '| listing_id | seeker_id | invalid_reference | explanation |',
    );
    buf.writeln(
      '|------------|-----------|-------------------|-------------|',
    );
    for (final raw in blockers.take(40)) {
      final r = raw as Map<String, dynamic>;
      final expl = (r['explanation_text'] as String).replaceAll('|', '\\|');
      buf.writeln(
        '| `${r['listing_id']}` | `${r['seeker_id']}` | '
        '`${r['invalid_reference']}` | $expl |',
      );
    }
    if (blockers.length > 40) {
      buf.writeln();
      buf.writeln('_… ${blockers.length - 40} more blocker rows in JSON_');
    }
  }
  buf.writeln();

  buf.writeln('## High');
  buf.writeln();
  final highs = payload['high'] as List<dynamic>;
  if (highs.isEmpty) {
    buf.writeln('_None_');
  } else {
    for (final raw in highs.take(20)) {
      final r = raw as Map<String, dynamic>;
      buf.writeln(
        '- `${r['seeker_id']}` / `${r['listing_id']}` — '
        '**${r['invalid_reference']}**: ${r['explanation_text']}',
      );
    }
  }
  buf.writeln();

  buf.writeln('## Medium');
  buf.writeln();
  final mediums = payload['medium'] as List<dynamic>;
  if (mediums.isEmpty) {
    buf.writeln('_None_');
  } else {
    buf.writeln(
      'Count: ${mediums.length} (location copy vs city-match soft warnings). '
      'See JSON for full rows.',
    );
  }
  buf.writeln();

  buf.writeln('## Marketplace terminology violations');
  buf.writeln();
  if (terms.isEmpty) {
    buf.writeln('_None_');
  } else {
    for (final raw in terms) {
      final r = raw as Map<String, dynamic>;
      buf.writeln(
        '- `${r['seeker_id']}` / `${r['listing_id']}` — '
        '`${r['invalid_reference']}`: ${r['explanation_text']}',
      );
    }
  }
  buf.writeln();

  buf.writeln('## Per-seeker top listings + explanations');
  buf.writeln();
  for (final raw in seekers) {
    final s = raw as Map<String, dynamic>;
    buf.writeln('### `${s['seeker_id']}`');
    buf.writeln();
    buf.writeln('- **Scenario:** ${s['uat_scenario']}');
    buf.writeln('- **Blank fields:** ${(s['blank_fields'] as List).join(', ')}');
    buf.writeln(
      '- **Matches returned:** ${s['matches_returned']} '
      '(showing top ${(s['top_listings'] as List).length})',
    );
    buf.writeln(
      '- **Invalid refs:** ${(s['invalid_references'] as List).length}',
    );
    buf.writeln();
    for (final lr in (s['top_listings'] as List<dynamic>)) {
      final l = lr as Map<String, dynamic>;
      final expl = (l['explanations'] as List<dynamic>);
      buf.writeln('#### `${l['listing_id']}` — ${l['title']}');
      if (expl.isEmpty) {
        buf.writeln('- _(no explanations)_');
      } else {
        for (final e in expl) {
          buf.writeln('- $e');
        }
      }
      buf.writeln();
    }
  }

  buf.writeln('## Methodology');
  buf.writeln();
  final method = payload['methodology'] as Map<String, dynamic>;
  buf.writeln('### Code paths');
  for (final p in method['code_paths'] as List<dynamic>) {
    buf.writeln('- `$p`');
  }
  buf.writeln();
  final ds = method['seeker_dataset'] as Map<String, dynamic>;
  buf.writeln('### Seeker dataset');
  buf.writeln();
  buf.writeln(ds['note']);
  buf.writeln();
  buf.writeln('### Session key mapping');
  buf.writeln();
  final mapping = ds['session_key_mapping'] as Map<String, dynamic>;
  for (final e in mapping.entries) {
    buf.writeln('- **${e.key}:** ${e.value}');
  }
  buf.writeln();
  buf.writeln('### Limitations');
  buf.writeln();
  buf.writeln(
    '- Frozen UAT JSON not in repo; reconstructed from prior chat artifact.',
  );
  buf.writeln(
    '- No UAT seeker lacked `desired_move_date` or `occupation_type`; '
    'BLANK-MOVE / BLANK-HH variants are synthetic.',
  );
  buf.writeln(
    '- Lifestyle high findings assume food="No Preference" is not a '
    'positive lifestyle preference (UAT reconstruction default).',
  );
  buf.writeln(
    '- Audit only — production explanation logic unchanged.',
  );
  buf.writeln();

  return buf.toString();
}
