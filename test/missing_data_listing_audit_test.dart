import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';
import 'package:true_circle/utils/address_privacy.dart';
import 'package:true_circle/utils/listing_commute_display.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/listing_property_highlights.dart';
import 'package:true_circle/utils/shared_living_match_tokens.dart';
import 'package:true_circle/utils/viewer_profile.dart';
import 'package:true_circle/widgets/property_card.dart';

/// Missing-Data Listing Audit — completeness + UI/match resilience.
///
/// Run: `flutter test test/missing_data_listing_audit_test.dart`
///
/// Writes:
/// - `docs/uat/v1/missing_data_listing_audit.json`
/// - `docs/uat/v1/missing_data_listing_audit.md`
void main() {
  late List<Map<String, dynamic>> items;
  late List<_ScoredListing> scored;
  late _ScoredListing leastSl;
  late _ScoredListing mostSl;
  late _ScoredListing leastIp;
  late _ScoredListing mostIp;
  late Map<String, dynamic> auditPayload;

  setUpAll(() {
    items = SampleListingsDublin.items;
    scored = items.map(_scoreListing).toList();
    final sl = scored.where((s) => s.marketplace == 'shared_living').toList()
      ..sort((a, b) {
        final c = a.completenessScore.compareTo(b.completenessScore);
        if (c != 0) return c;
        return a.listingId.compareTo(b.listingId);
      });
    final ip = scored
        .where((s) => s.marketplace == 'independent_places')
        .toList()
      ..sort((a, b) {
        final c = a.completenessScore.compareTo(b.completenessScore);
        if (c != 0) return c;
        return a.listingId.compareTo(b.listingId);
      });

    leastSl = sl.first;
    mostSl = sl.last;
    leastIp = ip.first;
    mostIp = ip.last;
  });

  test('missing-data listing audit dump + resilience', () {
    expect(items.length, 90);
    expect(
      scored.where((s) => s.marketplace == 'shared_living').length,
      40,
    );
    expect(
      scored.where((s) => s.marketplace == 'independent_places').length,
      50,
    );

    final slResilience = _runResilience(
      leastSl,
      marketplace: 'shared_living',
    );
    final ipResilience = _runResilience(
      leastIp,
      marketplace: 'independent_places',
    );
    final emptyMapResilience = _runSyntheticEmptyResilience();

    final findings = _collectFindings(
      scored: scored,
      leastSl: leastSl,
      leastIp: leastIp,
      slResilience: slResilience,
      ipResilience: ipResilience,
      emptyMapResilience: emptyMapResilience,
    );

    final overall = _overallVerdict(findings);
    final success = _successCriteria(
      findings: findings,
      slResilience: slResilience,
      ipResilience: ipResilience,
      emptyMapResilience: emptyMapResilience,
    );

    auditPayload = {
      'audit_version': '1.0',
      'audited_at': DateTime.now().toUtc().toIso8601String(),
      'source': {
        'name': 'SampleListingsDublin (local Dublin marketplace seed)',
        'paths': [
          'lib/data/sample_listings_dublin.dart',
          'lib/data/sample_listings_dublin_v2.dart',
          'lib/data/sample_listings_dublin_legacy.dart',
          'lib/data/sample_listings_dublin_expansion.dart',
          'lib/data/dublin_listing_builder.dart',
        ],
        'notes':
            'Same corpus as prior UAT audits (~40 Share + ~50 Rent). '
            'App feed bootstraps via ListingsStorageService.',
        'shared_living_count': 40,
        'independent_places_count': 50,
        'total': scored.length,
      },
      'field_checklists': {
        'shared_living': _slFieldDefs,
        'independent_places': _ipFieldDefs,
        'scoring':
            'completeness_score = present_usable_fields / relevant_field_set '
            '(rounded to 4 decimals). Presence uses the same ListingData / '
            'ListingPropertyHighlights / SharedLivingMatchTokens helpers the UI '
            'and match engine consume.',
      },
      'extremes': {
        'shared_living': {
          'most_complete': mostSl.toJson(),
          'least_complete': leastSl.toJson(),
        },
        'independent_places': {
          'most_complete': mostIp.toJson(),
          'least_complete': leastIp.toJson(),
        },
      },
      'completeness_summary': {
        'shared_living': _marketplaceCompletenessSummary(
          scored.where((s) => s.marketplace == 'shared_living'),
        ),
        'independent_places': _marketplaceCompletenessSummary(
          scored.where((s) => s.marketplace == 'independent_places'),
        ),
      },
      'resilience': {
        'shared_living_least_complete': slResilience,
        'independent_places_least_complete': ipResilience,
        'synthetic_empty_maps': emptyMapResilience,
      },
      'empty_data_handling': _emptyDataHandlingNotes(),
      'findings': findings,
      'overall': overall,
      'success_criteria': success,
      'listings': scored.map((s) => s.toJson()).toList(),
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/missing_data_listing_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(auditPayload),
    );
    File('docs/uat/v1/missing_data_listing_audit.md')
        .writeAsStringSync(_buildMarkdown(auditPayload));

    // ignore: avoid_print
    print(
      'MISSING_DATA_AUDIT overall=${overall['verdict']} '
      'SL least=${leastSl.listingId}(${leastSl.completenessScore}) '
      'SL most=${mostSl.listingId}(${mostSl.completenessScore}) '
      'IP least=${leastIp.listingId}(${leastIp.completenessScore}) '
      'IP most=${mostIp.listingId}(${mostIp.completenessScore})',
    );

    expect(overall['verdict'], isNot(equals('FAIL')));
    expect(success['success_criteria_met'], isTrue);
  });

  testWidgets('least-complete cards render without throw', (tester) async {
    const match = ListingMatchResult(
      score: 40,
      maxScore: 100,
      percentage: 40,
      label: 'Fair Match',
      reasons: [],
      excluded: false,
      tower: MatchTower.share,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  width: 280,
                  height: PropertyCard.gridMainAxisExtent,
                  child: PropertyCard(
                    listing: Map<String, dynamic>.from(leastSl.item),
                    match: match,
                    activeSpace: MarketplaceSpace.sharedSpace,
                    onTap: () {},
                  ),
                ),
                SizedBox(
                  width: 280,
                  height: PropertyCard.gridMainAxisExtent,
                  child: PropertyCard(
                    listing: Map<String, dynamic>.from(leastIp.item),
                    match: match,
                    activeSpace: MarketplaceSpace.fullRental,
                    onTap: () {},
                  ),
                ),
                SizedBox(
                  width: 280,
                  height: PropertyCard.gridMainAxisExtent,
                  child: PropertyCard(
                    listing: const {
                      'id': 'synthetic-empty-share',
                      'type': 'Share',
                    },
                    match: match,
                    activeSpace: MarketplaceSpace.sharedSpace,
                    onTap: () {},
                  ),
                ),
                SizedBox(
                  width: 280,
                  height: PropertyCard.gridMainAxisExtent,
                  child: PropertyCard(
                    listing: const {
                      'id': 'synthetic-empty-rent',
                      'type': 'Rent',
                    },
                    match: match,
                    activeSpace: MarketplaceSpace.fullRental,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(PropertyCard), findsNWidgets(4));
  });
}

// ── Field checklists ─────────────────────────────────────────────────────────

const _slFieldDefs = <Map<String, String>>[
  {
    'id': 'room_type',
    'label': 'Room type',
    'surfaces': 'Room Snapshot, card chips, ListingMatchEngine share room',
  },
  {
    'id': 'bathroom',
    'label': 'Bathroom',
    'surfaces': 'Room Snapshot, ListingMatchEngine share bathroom',
  },
  {
    'id': 'rent',
    'label': 'Rent / price',
    'surfaces': 'Room Snapshot, cards, ranking budget',
  },
  {
    'id': 'availability',
    'label': 'Availability / move-in',
    'surfaces': 'Room Snapshot, card chips, timing match',
  },
  {
    'id': 'household_type',
    'label': 'Household type',
    'surfaces': 'Household Snapshot, card chips, occupant match',
  },
  {
    'id': 'occupants',
    'label': 'Current occupants',
    'surfaces': 'Household Snapshot',
  },
  {
    'id': 'culture_languages',
    'label': 'Culture · languages',
    'surfaces': 'Household Culture (hide-if-empty)',
  },
  {
    'id': 'culture_kitchen',
    'label': 'Culture · kitchen / food',
    'surfaces': 'Household Culture (hide-if-empty)',
  },
  {
    'id': 'culture_pets_smoking',
    'label': 'Culture · pets / smoking',
    'surfaces': 'Household Culture lifestyle flags',
  },
  {
    'id': 'property_type',
    'label': 'Property type',
    'surfaces': 'Property Details',
  },
  {
    'id': 'furnishing',
    'label': 'Furnishing',
    'surfaces': 'Property Details',
  },
  {
    'id': 'parking',
    'label': 'Parking',
    'surfaces': 'Property Details (incl. explicit No Parking)',
  },
  {
    'id': 'bike',
    'label': 'Bike storage',
    'surfaces': 'Property Details / activeHighlights',
  },
  {
    'id': 'ber',
    'label': 'BER',
    'surfaces': 'Property Details',
  },
  {
    'id': 'transit',
    'label': 'Transit / proximity',
    'surfaces': 'Transit & Commute, card commute chip',
  },
  {
    'id': 'title',
    'label': 'Title',
    'surfaces': 'Detail hero, cards',
  },
  {
    'id': 'location',
    'label': 'Location / area',
    'surfaces': 'Detail subtitle, cards, location match',
  },
  {
    'id': 'photos',
    'label': 'Photos',
    'surfaces': 'ListingPhotoGallery / PropertyCard cover',
  },
  {
    'id': 'description',
    'label': 'Description',
    'surfaces': 'Detail DESCRIPTION (placeholder if empty)',
  },
  {
    'id': 'host',
    'label': 'Host',
    'surfaces': 'HOSTED BY / card trust line',
  },
];

const _ipFieldDefs = <Map<String, String>>[
  {
    'id': 'bedrooms',
    'label': 'Bedrooms',
    'surfaces': 'Property Highlights, card chips, bed match',
  },
  {
    'id': 'bathrooms',
    'label': 'Bathrooms',
    'surfaces': 'Property Highlights',
  },
  {
    'id': 'property_type',
    'label': 'Property type',
    'surfaces': 'Property Highlights',
  },
  {
    'id': 'furnishing',
    'label': 'Furnishing',
    'surfaces': 'Property Highlights',
  },
  {
    'id': 'availability',
    'label': 'Availability',
    'surfaces': 'Property Highlights, card chips',
  },
  {
    'id': 'parking',
    'label': 'Parking',
    'surfaces': 'Property Highlights',
  },
  {
    'id': 'pets',
    'label': 'Pets policy',
    'surfaces': 'Property Highlights',
  },
  {
    'id': 'lease',
    'label': 'Lease / tenure',
    'surfaces': 'Property Highlights (agreement_type)',
  },
  {
    'id': 'ber',
    'label': 'BER',
    'surfaces': 'Property Highlights',
  },
  {
    'id': 'transit',
    'label': 'Transit / proximity',
    'surfaces': 'Transit & Commute, card commute chip',
  },
  {
    'id': 'rent',
    'label': 'Rent / price',
    'surfaces': 'Cards, ranking budget (not in highlight grid)',
  },
  {
    'id': 'title',
    'label': 'Title',
    'surfaces': 'Detail hero, cards',
  },
  {
    'id': 'location',
    'label': 'Location / area',
    'surfaces': 'Detail subtitle, cards',
  },
  {
    'id': 'photos',
    'label': 'Photos',
    'surfaces': 'ListingPhotoGallery / PropertyCard cover',
  },
  {
    'id': 'description',
    'label': 'Description',
    'surfaces': 'Detail DESCRIPTION (placeholder if empty)',
  },
  {
    'id': 'host',
    'label': 'Host',
    'surfaces': 'HOSTED BY / card trust line',
  },
];

// ── Scoring ──────────────────────────────────────────────────────────────────

class _ScoredListing {
  _ScoredListing({
    required this.listingId,
    required this.marketplace,
    required this.completenessScore,
    required this.missingFields,
    required this.availableFields,
    required this.presentCount,
    required this.fieldCount,
    required this.item,
  });

  final String listingId;
  final String marketplace;
  final double completenessScore;
  final List<String> missingFields;
  final List<String> availableFields;
  final int presentCount;
  final int fieldCount;
  final Map<String, dynamic> item;

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'marketplace': marketplace,
        'completeness_score': completenessScore,
        'present_count': presentCount,
        'field_count': fieldCount,
        'missing_fields': missingFields,
        'available_fields': availableFields,
      };
}

_ScoredListing _scoreListing(Map<String, dynamic> item) {
  final tower = ListingData.listingType(item);
  final marketplace =
      tower == 'Share' ? 'shared_living' : 'independent_places';
  final presence = marketplace == 'shared_living'
      ? _slPresence(item)
      : _ipPresence(item);
  final available = <String>[];
  final missing = <String>[];
  for (final entry in presence.entries) {
    if (entry.value) {
      available.add(entry.key);
    } else {
      missing.add(entry.key);
    }
  }
  final score = presence.isEmpty
      ? 0.0
      : double.parse(
          (available.length / presence.length).toStringAsFixed(4),
        );
  return _ScoredListing(
    listingId: ListingData.id(item),
    marketplace: marketplace,
    completenessScore: score,
    missingFields: missing,
    availableFields: available,
    presentCount: available.length,
    fieldCount: presence.length,
    item: item,
  );
}

Map<String, bool> _slPresence(Map<String, dynamic> item) {
  final roomCells =
      ListingPropertyHighlights.sharedLivingRoomSnapshotCells(item);
  final householdCells =
      ListingPropertyHighlights.sharedLivingHouseholdSnapshotCells(item);
  final cultureCells =
      ListingPropertyHighlights.sharedLivingCultureCells(item);
  final propertyCells =
      ListingPropertyHighlights.sharedLivingPropertyDetailCells(item);

  final roomLabel = SharedLivingMatchTokens.roomFromListing(item);
  final hasRoom = roomLabel.isNotEmpty ||
      roomCells.any((c) =>
          c.label.contains('Private') || c.label.contains('Shared'));

  final hasBath = roomCells.any((c) => c.label.contains('Bathroom')) ||
      SharedLivingMatchTokens.bathroomFromListing(item).isNotEmpty;

  final hasRent = ListingData.listingPriceAmount(item) != null ||
      ListingData.price(item).trim().isNotEmpty;

  final hasAvailability =
      ListingData.availableFromDisplayLabel(item).isNotEmpty;

  final hasHousehold = householdCells.any((c) =>
          !c.label.toLowerCase().contains('occupant')) ||
      _shortHouseholdPresent(item);

  final hasOccupants = ListingData.currentOccupants(item) > 0 ||
      householdCells.any((c) => c.label.toLowerCase().contains('occupant'));

  final langs = ListingData.languagesSpokenInHouse(item);
  final hasLangs = langs.isNotEmpty ||
      ListingData.hostLanguage(item).trim().isNotEmpty ||
      cultureCells.any((c) => c.icon == Icons.language_outlined);

  final hasKitchen = cultureCells.any((c) =>
          c.label.toLowerCase().contains('kitchen') ||
          c.label.toLowerCase().contains('vegetarian')) ||
      ListingData.foodPreferenceToken(item).isNotEmpty;

  final hasPetsSmoking = cultureCells.any((c) =>
          c.label == 'No Pets' ||
          c.label == 'Pets Allowed' ||
          c.label == 'No Smoking' ||
          c.label == 'Quiet Hours') ||
      _petsSmokingDeclared(item);

  final hasPropertyType =
      ListingData.propertyCategory(item).trim().isNotEmpty ||
          ListingData.text(item['property_sub_type']).trim().isNotEmpty ||
          propertyCells.any((c) =>
              c.label == 'House' ||
              c.label == 'Apartment' ||
              c.label == 'Villa' ||
              c.label == 'Plot');

  final hasFurnishing = ListingData.furnishing(item).trim().isNotEmpty;
  final hasParking = _parkingDeclared(item);
  final hasBike = _bikeDeclared(item);
  final hasBer = ListingData.text(item['ber_rating']).isNotEmpty;
  final hasTransit = _transitDeclared(item);
  final hasTitle = _rawTitlePresent(item);
  final hasLocation = _rawLocationPresent(item);
  final hasPhotos = _photosPresent(item);
  final hasDescription = ListingData.description(item).trim().isNotEmpty;
  final hasHost = _rawHostPresent(item);

  return {
    'room_type': hasRoom,
    'bathroom': hasBath,
    'rent': hasRent,
    'availability': hasAvailability,
    'household_type': hasHousehold,
    'occupants': hasOccupants,
    'culture_languages': hasLangs,
    'culture_kitchen': hasKitchen,
    'culture_pets_smoking': hasPetsSmoking,
    'property_type': hasPropertyType,
    'furnishing': hasFurnishing,
    'parking': hasParking,
    'bike': hasBike,
    'ber': hasBer,
    'transit': hasTransit,
    'title': hasTitle,
    'location': hasLocation,
    'photos': hasPhotos,
    'description': hasDescription,
    'host': hasHost,
  };
}

Map<String, bool> _ipPresence(Map<String, dynamic> item) {
  final cells = ListingPropertyHighlights.independentPlaceFactCells(item);

  final hasBeds = ListingData.bedsHighlightLabel(item) !=
          'Bedroom Count Not Listed' ||
      ListingData.bedCount(item) != null;

  final hasBaths = cells.any((c) =>
          c.label.toLowerCase().contains('bath')) ||
      ListingData.bathrooms(item).trim().isNotEmpty;

  final hasPropertyType =
      ListingData.propertyCategory(item).trim().isNotEmpty ||
          ListingData.text(item['property_sub_type']).trim().isNotEmpty;

  final hasFurnishing = ListingData.furnishing(item).trim().isNotEmpty;
  final hasAvailability =
      ListingData.availableFromDisplayLabel(item).isNotEmpty;
  final hasParking = _parkingDeclared(item);
  final hasPets = _petsDeclared(item);
  final hasLease = TenurePreference.fromListing(item) != null;
  final hasBer = ListingData.text(item['ber_rating']).isNotEmpty;
  final hasTransit = _transitDeclared(item);
  final hasRent = ListingData.listingPriceAmount(item) != null ||
      ListingData.price(item).trim().isNotEmpty;
  final hasTitle = _rawTitlePresent(item);
  final hasLocation = _rawLocationPresent(item);
  final hasPhotos = _photosPresent(item);
  final hasDescription = ListingData.description(item).trim().isNotEmpty;
  final hasHost = _rawHostPresent(item);

  return {
    'bedrooms': hasBeds,
    'bathrooms': hasBaths,
    'property_type': hasPropertyType,
    'furnishing': hasFurnishing,
    'availability': hasAvailability,
    'parking': hasParking,
    'pets': hasPets,
    'lease': hasLease,
    'ber': hasBer,
    'transit': hasTransit,
    'rent': hasRent,
    'title': hasTitle,
    'location': hasLocation,
    'photos': hasPhotos,
    'description': hasDescription,
    'host': hasHost,
  };
}

bool _shortHouseholdPresent(Map<String, dynamic> item) {
  final occ = ListingData.occupantType(item).toLowerCase();
  if (occ.contains('student') ||
      occ.contains('working') ||
      occ.contains('professional') ||
      occ.contains('mixed') ||
      occ.contains('open')) {
    return true;
  }
  final cohort = ListingData.text(
    item['flatmate_cohort'] ??
        item['household_cohort'] ??
        item['preferred_tenant_occupant'] ??
        item['cohort_type'],
  ).toLowerCase();
  return cohort.contains('student') ||
      cohort.contains('working') ||
      cohort.contains('professional') ||
      cohort.contains('mixed') ||
      cohort.contains('open');
}

bool _parkingDeclared(Map<String, dynamic> item) {
  if (ListingData.parkingAvailable(item)) return true;
  final type = ListingData.parkingType(item).toLowerCase();
  if (type.isNotEmpty) return true;
  if (item.containsKey('parking_available')) return true;
  return false;
}

bool _bikeDeclared(Map<String, dynamic> item) {
  if (item.containsKey('secure_bike_storage') ||
      item.containsKey('has_bike_storage')) {
    return true;
  }
  return ListingData.hasBikeStorage(item);
}

bool _petsDeclared(Map<String, dynamic> item) {
  if (ListingData.text(item['pets_policy']).isNotEmpty) return true;
  if (item.containsKey('pets_allowed')) return true;
  if (ListingData.lifestyleFlags(item).contains('no_pets')) return true;
  return false;
}

bool _petsSmokingDeclared(Map<String, dynamic> item) {
  if (_petsDeclared(item)) return true;
  if (item.containsKey('smoking_allowed')) return true;
  final flags = ListingData.lifestyleFlags(item);
  return flags.any((f) =>
      f.contains('pet') || f.contains('smok') || f.contains('quiet'));
}

bool _transitDeclared(Map<String, dynamic> item) {
  if (ListingData.proximityData(item) != null) return true;
  if (ListingData.transitWalkMinutes(item) != null) return true;
  if (ListingData.transitTypeLabel(item).trim().isNotEmpty) return true;
  if (ListingData.listingCoordinates(item) != null) return true;
  return false;
}

bool _rawTitlePresent(Map<String, dynamic> item) {
  final raw = item['title'];
  return raw != null && raw.toString().trim().isNotEmpty;
}

bool _rawLocationPresent(Map<String, dynamic> item) {
  final loc = item['location'];
  if (loc != null && loc.toString().trim().isNotEmpty) return true;
  final public = item[AddressPrivacy.publicLocationKey];
  return public != null && public.toString().trim().isNotEmpty;
}

bool _rawHostPresent(Map<String, dynamic> item) {
  final host = item['hostName'] ?? item['owner_name'];
  return host != null && host.toString().trim().isNotEmpty;
}

bool _photosPresent(Map<String, dynamic> item) {
  if (ListingData.imageDataUris(item).isNotEmpty) return true;
  if (ListingData.coverImageUrl(item).isNotEmpty) return true;
  final imageUrl = ListingData.text(item['imageUrl'] ?? item['image_url']);
  return imageUrl.isNotEmpty;
}

Map<String, dynamic> _marketplaceCompletenessSummary(
  Iterable<_ScoredListing> rows,
) {
  final list = rows.toList();
  if (list.isEmpty) {
    return {'count': 0};
  }
  final scores = list.map((e) => e.completenessScore).toList()..sort();
  final avg =
      scores.fold<double>(0, (a, b) => a + b) / scores.length;
  final missingFreq = <String, int>{};
  for (final row in list) {
    for (final f in row.missingFields) {
      missingFreq[f] = (missingFreq[f] ?? 0) + 1;
    }
  }
  final topMissing = missingFreq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {
    'count': list.length,
    'min_score': scores.first,
    'max_score': scores.last,
    'avg_score': double.parse(avg.toStringAsFixed(4)),
    'most_frequently_missing': topMissing
        .take(8)
        .map((e) => {'field': e.key, 'listings_missing': e.value})
        .toList(),
  };
}

// ── Resilience ───────────────────────────────────────────────────────────────

Map<String, dynamic> _runResilience(
  _ScoredListing target, {
  required String marketplace,
}) {
  final item = Map<String, dynamic>.from(target.item);
  final sections = <String, dynamic>{};
  final throws = <String>[];

  void check(String name, void Function() body) {
    try {
      body();
    } catch (e, st) {
      throws.add('$name: $e');
      sections[name] = {
        'status': 'FAIL',
        'reason': 'Threw: $e',
        'stack': st.toString().split('\n').take(4).join(' | '),
      };
    }
  }

  if (marketplace == 'shared_living') {
    List<ListingHighlightCell> room = const [];
    List<ListingHighlightCell> household = const [];
    List<ListingHighlightCell> culture = const [];
    List<ListingHighlightCell> property = const [];
    List<String> explanations = const [];
    ListingRankOutcome? rankOutcome;
    MultiCommuteDisplayModel? commute;

    check('room_snapshot', () {
      room = ListingPropertyHighlights.sharedLivingRoomSnapshotCells(item);
      final blank = room.where((c) => c.label.trim().isEmpty).toList();
      sections['room_snapshot'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (room.isEmpty
                ? 'Empty cell list → section hidden (if roomCells.isNotEmpty)'
                : '${room.length} cells, no blank labels')
            : '${blank.length} blank label(s)',
        'cell_count': room.length,
        'labels': room.map((c) => c.label).toList(),
        'section_hidden_when_empty': true,
      };
    });

    check('household_snapshot', () {
      household =
          ListingPropertyHighlights.sharedLivingHouseholdSnapshotCells(item);
      final blank = household.where((c) => c.label.trim().isEmpty).toList();
      sections['household_snapshot'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (household.isEmpty
                ? 'Empty → HOUSEHOLD SNAPSHOT hidden'
                : '${household.length} cells, no blank labels')
            : '${blank.length} blank label(s)',
        'cell_count': household.length,
        'labels': household.map((c) => c.label).toList(),
        'section_hidden_when_empty': true,
      };
    });

    check('household_culture', () {
      culture = ListingPropertyHighlights.sharedLivingCultureCells(item);
      final blank = culture.where((c) => c.label.trim().isEmpty).toList();
      sections['household_culture'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (culture.isEmpty
                ? 'Empty → HOUSEHOLD CULTURE hidden (documented hide-if-empty)'
                : '${culture.length} cells, no blank labels')
            : '${blank.length} blank label(s)',
        'cell_count': culture.length,
        'labels': culture.map((c) => c.label).toList(),
        'section_hidden_when_empty': true,
      };
    });

    check('property_details', () {
      property =
          ListingPropertyHighlights.sharedLivingPropertyDetailCells(item);
      final blank = property.where((c) => c.label.trim().isEmpty).toList();
      sections['property_details'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (property.isEmpty
                ? 'Empty → PROPERTY DETAILS hidden'
                : '${property.length} cells, no blank labels')
            : '${blank.length} blank label(s)',
        'cell_count': property.length,
        'labels': property.map((c) => c.label).toList(),
        'section_hidden_when_empty': true,
      };
    });

    check('match_explanations', () {
      final session = _shareViewerSession();
      final viewer = ViewerProfile.fromSession(session);
      explanations = ListingMatchEngine.sharedLivingPreferenceExplanations(
        item,
        viewer,
        viewerSession: session,
      );
      sections['match_explanations'] = {
        'status': 'PASS',
        'reason': explanations.isEmpty
            ? 'Empty explanation list → preference card hidden '
                '(listing_detail_page_layout preferenceReasons.isNotEmpty). '
                'Valid for sparse / non-matching listings.'
            : '${explanations.length} explanation(s), no throw',
        'explanation_count': explanations.length,
        'explanations': explanations,
        'section_hidden_when_empty': true,
        'note': explanations.isEmpty ? 'WARN_EMPTY_OK' : null,
      };
      if (explanations.isEmpty) {
        sections['match_explanations']['status'] = 'WARN';
      }
    });

    check('ranking', () {
      final session = _shareViewerSession();
      rankOutcome = ListingMatchEngine.rank([item], session);
      sections['ranking'] = {
        'status': 'PASS',
        'reason':
            'ListingMatchEngine.rank completed; ranked=${rankOutcome!.ranked.length} '
            'requiresOnboarding=${rankOutcome!.requiresOnboarding}',
        'ranked_count': rankOutcome!.ranked.length,
      };
    });

    check('transit_commute', () {
      commute = ListingCommuteDisplay.resolve(
        listing: item,
        viewerSession: null,
      );
      final empty = commute == null || commute!.isEmpty;
      sections['transit_commute'] = {
        'status': 'PASS',
        'reason': empty
            ? 'Null/empty MultiCommuteDisplayModel → '
                'ListingDetailCommuteSection returns SizedBox.shrink()'
            : '${commute!.rows.length} commute row(s) rendered',
        'hidden_when_empty': true,
        'row_count': empty ? 0 : commute!.rows.length,
      };
    });

    check('card_chips', () {
      final chipLabels = _sharedCardChipLabels(item);
      final blank = chipLabels.where((l) => l.trim().isEmpty).toList();
      sections['card_rendering'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (chipLabels.isEmpty
                ? 'No chips → PropertyCard uses SizedBox.shrink() for chip row'
                : '${chipLabels.length} chip(s), no blank labels')
            : 'Blank chip label(s)',
        'chip_labels': chipLabels,
        'empty_row_shrinks': true,
      };
    });

    check('detail_story_sections', () {
      final description = ListingData.description(item);
      final title = ListingData.title(item);
      final location = ListingData.location(item);
      sections['detail_page_story'] = {
        'status': 'PASS',
        'reason':
            'Story builders gate sections on isNotEmpty; description uses '
            'placeholder "No description provided." when empty; host uses '
            '"Your host" fallback.',
        'title': title,
        'location_present': location.isNotEmpty,
        'description_present': description.isNotEmpty,
        'description_placeholder_when_empty': true,
        'host_fallback': 'Your host',
        'sections_hidden_when_empty': [
          'ROOM SNAPSHOT',
          'HOUSEHOLD SNAPSHOT',
          'HOUSEHOLD CULTURE',
          'PROPERTY DETAILS',
          'preference insight',
          'TRANSIT & COMMUTE',
        ],
      };
      if (description.isEmpty) {
        sections['detail_page_story']['status'] = 'WARN';
        sections['detail_page_story']['reason'] =
            'Description empty → placeholder text shown (not a blank section)';
      }
    });
  } else {
    List<ListingHighlightCell> highlights = const [];
    List<String> explanations = const [];
    ListingRankOutcome? rankOutcome;
    MultiCommuteDisplayModel? commute;

    check('property_highlights', () {
      highlights = ListingPropertyHighlights.independentPlaceFactCells(item);
      final blank = highlights.where((c) => c.label.trim().isEmpty).toList();
      sections['property_highlights'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (highlights.isEmpty
                ? 'Empty → PROPERTY HIGHLIGHTS hidden (no filler chips)'
                : '${highlights.length} fact cells, no blank labels')
            : '${blank.length} blank label(s)',
        'cell_count': highlights.length,
        'labels': highlights.map((c) => c.label).toList(),
        'section_hidden_when_empty': true,
        'no_platform_fillers': true,
      };
    });

    check('match_explanations', () {
      final session = _rentViewerSession();
      final viewer = ViewerProfile.fromSession(session);
      explanations =
          ListingMatchEngine.independentPlacePreferenceExplanations(
        item,
        viewer,
        viewerSession: session,
      );
      sections['match_explanations'] = {
        'status': explanations.isEmpty ? 'WARN' : 'PASS',
        'reason': explanations.isEmpty
            ? 'Empty explanation list → preference card hidden. Valid when '
                'listing fails hard filters or lacks matchable preference signals.'
            : '${explanations.length} explanation(s), no throw',
        'explanation_count': explanations.length,
        'explanations': explanations,
        'section_hidden_when_empty': true,
      };
    });

    check('ranking', () {
      final session = _rentViewerSession();
      rankOutcome = ListingMatchEngine.rank([item], session);
      sections['ranking'] = {
        'status': 'PASS',
        'reason':
            'ListingMatchEngine.rank completed; ranked=${rankOutcome!.ranked.length}',
        'ranked_count': rankOutcome!.ranked.length,
      };
    });

    check('transit_commute', () {
      commute = ListingCommuteDisplay.resolve(
        listing: item,
        viewerSession: null,
      );
      final empty = commute == null || commute!.isEmpty;
      sections['transit_commute'] = {
        'status': 'PASS',
        'reason': empty
            ? 'Null/empty → ListingDetailCommuteSection shrinks'
            : '${commute!.rows.length} commute row(s)',
        'hidden_when_empty': true,
        'row_count': empty ? 0 : commute!.rows.length,
      };
    });

    check('card_chips', () {
      final chipLabels = _rentCardChipLabels(item);
      final blank = chipLabels.where((l) => l.trim().isEmpty).toList();
      sections['card_rendering'] = {
        'status': blank.isEmpty ? 'PASS' : 'FAIL',
        'reason': blank.isEmpty
            ? (chipLabels.isEmpty
                ? 'No chips → chip row SizedBox.shrink()'
                : '${chipLabels.length} chip(s), no blank labels')
            : 'Blank chip label(s)',
        'chip_labels': chipLabels,
        'empty_row_shrinks': true,
      };
    });

    check('detail_story_sections', () {
      final description = ListingData.description(item);
      sections['detail_page_story'] = {
        'status': description.isEmpty ? 'WARN' : 'PASS',
        'reason': description.isEmpty
            ? 'Description empty → placeholder text (section still present)'
            : 'IP story gates highlights + preference on isNotEmpty; '
                'commute shrinks when empty',
        'description_present': description.isNotEmpty,
        'description_placeholder_when_empty': true,
        'sections_hidden_when_empty': [
          'PROPERTY HIGHLIGHTS',
          'preference insight',
          'TRANSIT & COMMUTE',
        ],
      };
    });

    // Align section keys with audit report expectations
    sections['room_snapshot'] = {
      'status': 'PASS',
      'reason': 'N/A for Independent Places',
      'applicable': false,
    };
    sections['household_snapshot'] = {
      'status': 'PASS',
      'reason': 'N/A for Independent Places',
      'applicable': false,
    };
    sections['household_culture'] = {
      'status': 'PASS',
      'reason': 'N/A for Independent Places',
      'applicable': false,
    };
    sections['property_details'] = sections['property_highlights'];
  }

  final statuses = sections.values
      .whereType<Map>()
      .map((m) => m['status']?.toString())
      .whereType<String>()
      .toList();

  return {
    'listing_id': target.listingId,
    'marketplace': marketplace,
    'completeness_score': target.completenessScore,
    'missing_fields': target.missingFields,
    'available_fields': target.availableFields,
    'sections': sections,
    'threw': throws,
    'section_summary': {
      'PASS': statuses.where((s) => s == 'PASS').length,
      'WARN': statuses.where((s) => s == 'WARN').length,
      'FAIL': statuses.where((s) => s == 'FAIL').length,
    },
  };
}

Map<String, dynamic> _runSyntheticEmptyResilience() {
  final shareEmpty = <String, dynamic>{'id': 'synthetic-empty', 'type': 'Share'};
  final rentEmpty = <String, dynamic>{'id': 'synthetic-empty', 'type': 'Rent'};

  final shareRoom =
      ListingPropertyHighlights.sharedLivingRoomSnapshotCells(shareEmpty);
  final shareHousehold =
      ListingPropertyHighlights.sharedLivingHouseholdSnapshotCells(shareEmpty);
  final shareCulture =
      ListingPropertyHighlights.sharedLivingCultureCells(shareEmpty);
  final shareProperty =
      ListingPropertyHighlights.sharedLivingPropertyDetailCells(shareEmpty);
  final ipFacts =
      ListingPropertyHighlights.independentPlaceFactCells(rentEmpty);
  final grid = ListingPropertyHighlights.gridCells(shareEmpty);

  final shareExpl = ListingMatchEngine.sharedLivingPreferenceExplanations(
    shareEmpty,
    ViewerProfile.fromSession(_shareViewerSession()),
    viewerSession: _shareViewerSession(),
  );
  final rentExpl = ListingMatchEngine.independentPlacePreferenceExplanations(
    rentEmpty,
    ViewerProfile.fromSession(_rentViewerSession()),
    viewerSession: _rentViewerSession(),
  );

  ListingMatchEngine.rank([shareEmpty], _shareViewerSession());
  ListingMatchEngine.rank([rentEmpty], _rentViewerSession());

  final blankCells = [
    ...shareRoom,
    ...shareHousehold,
    ...shareCulture,
    ...shareProperty,
    ...ipFacts,
  ].where((c) => c.label.trim().isEmpty).length;

  return {
    'shared_empty_room_cells': shareRoom.length,
    'shared_empty_household_cells': shareHousehold.length,
    'shared_empty_culture_cells': shareCulture.length,
    'shared_empty_property_cells': shareProperty.length,
    'ip_empty_highlight_cells': ipFacts.length,
    'legacy_grid_cells_always_4': grid.length,
    'blank_label_cells': blankCells,
    'share_explanations_empty': shareExpl.isEmpty,
    'rent_explanations_empty': rentExpl.isEmpty,
    'status': blankCells == 0 && grid.length == 4 ? 'PASS' : 'FAIL',
    'reason': blankCells == 0
        ? 'Fully empty maps produce empty section cell lists (hidden) or '
            'legacy 4-cell platform fallbacks — no blank labels'
        : 'Blank labels detected on empty map',
  };
}

List<String> _sharedCardChipLabels(Map<String, dynamic> listing) {
  final chips = <String>[];
  final token = SharedLivingMatchTokens.roomFromListing(listing);
  if (token == SharedLivingMatchTokens.privateRoom) {
    chips.add('Private');
  } else if (token == SharedLivingMatchTokens.sharedRoom) {
    chips.add('Shared');
  } else {
    final fallback = ListingData.cardRoomTypeLabel(listing).toLowerCase();
    if (fallback.contains('shared') || fallback.contains('bed')) {
      chips.add('Shared');
    } else if (fallback.contains('private') || fallback.contains('ensuite')) {
      chips.add('Private');
    }
  }

  final occ = (listing['occupantType'] ?? listing['preferredTenantType'])
      ?.toString()
      .toLowerCase() ??
      '';
  if (occ.contains('student')) {
    chips.add('Students');
  } else if (occ.contains('working') || occ.contains('professional')) {
    chips.add('Professionals');
  } else if (occ.contains('mixed') || occ.contains('open')) {
    chips.add('Mixed');
  }

  final availability = ListingData.availableFromDisplayLabel(listing);
  if (availability.isNotEmpty) chips.add(availability);

  final commute = ListingData.transitTypeLabel(listing);
  if (commute.trim().isNotEmpty) chips.add(commute);
  return chips;
}

List<String> _rentCardChipLabels(Map<String, dynamic> listing) {
  final chips = <String>[];
  final beds = listing['bhk'] ?? listing['bedrooms'];
  final bedsLabel = beds?.toString().trim() ?? '';
  if (bedsLabel.isNotEmpty) {
    chips.add(
      bedsLabel.toLowerCase().contains('bed') ? bedsLabel : '$bedsLabel Bed',
    );
  }
  final monthLabel = ListingData.availableFromDisplayLabel(listing);
  if (monthLabel.isNotEmpty) chips.add(monthLabel);
  final commute = ListingData.transitTypeLabel(listing);
  if (commute.trim().isNotEmpty) chips.add(commute);
  return chips;
}

Map<String, dynamic> _shareViewerSession() => {
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'Non-veg',
      'occupant_type': 'Working Professionals',
      'budget_min': 500,
      'budget_max': 1200,
      'gender_preference': 'Any/Mixed',
      'demo_mode': true,
      'preferred_room_type': 'private_room',
    };

Map<String, dynamic> _rentViewerSession() => {
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'Non-veg',
      'occupant_type': 'Working Professionals',
      'budget_min': 1000,
      'budget_max': 2500,
      'preferred_layout': '2',
      'preferred_property_type': 'Apartment',
      'demo_mode': true,
    };

// ── Findings / verdict ───────────────────────────────────────────────────────

Map<String, dynamic> _collectFindings({
  required List<_ScoredListing> scored,
  required _ScoredListing leastSl,
  required _ScoredListing leastIp,
  required Map<String, dynamic> slResilience,
  required Map<String, dynamic> ipResilience,
  required Map<String, dynamic> emptyMapResilience,
}) {
  final blockers = <Map<String, dynamic>>[];
  final high = <Map<String, dynamic>>[];
  final medium = <Map<String, dynamic>>[];

  void scanSections(Map<String, dynamic> resilience, String marketplace) {
    final sections = resilience['sections'] as Map<String, dynamic>? ?? {};
    for (final entry in sections.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      final status = data['status']?.toString();
      if (status == 'FAIL') {
        blockers.add({
          'marketplace': marketplace,
          'listing_id': resilience['listing_id'],
          'section': entry.key,
          'reason': data['reason'],
        });
      } else if (status == 'WARN') {
        medium.add({
          'marketplace': marketplace,
          'listing_id': resilience['listing_id'],
          'section': entry.key,
          'reason': data['reason'],
        });
      }
    }
    final threw = resilience['threw'] as List? ?? [];
    for (final t in threw) {
      blockers.add({
        'marketplace': marketplace,
        'listing_id': resilience['listing_id'],
        'section': 'exception',
        'reason': t.toString(),
      });
    }
  }

  scanSections(slResilience, 'shared_living');
  scanSections(ipResilience, 'independent_places');

  if (emptyMapResilience['status'] == 'FAIL') {
    blockers.add({
      'marketplace': 'synthetic',
      'listing_id': 'synthetic-empty',
      'section': 'empty_map_helpers',
      'reason': emptyMapResilience['reason'],
    });
  }

  // Corpus-level gaps that affect UX but not crash resilience.
  final slMissingBer = scored
      .where((s) =>
          s.marketplace == 'shared_living' && s.missingFields.contains('ber'))
      .length;
  final ipMissingLease = scored
      .where((s) =>
          s.marketplace == 'independent_places' &&
          s.missingFields.contains('lease'))
      .length;
  final ipMissingPets = scored
      .where((s) =>
          s.marketplace == 'independent_places' &&
          s.missingFields.contains('pets'))
      .length;
  final slMissingOccupants = scored
      .where((s) =>
          s.marketplace == 'shared_living' &&
          s.missingFields.contains('occupants'))
      .length;

  if (slMissingBer > 0) {
    medium.add({
      'marketplace': 'shared_living',
      'section': 'completeness_corpus',
      'reason':
          '$slMissingBer/40 Share listings missing BER — Property Details '
          'omits BER cell (section still hides empty slots correctly)',
    });
  }
  if (ipMissingLease > 0) {
    medium.add({
      'marketplace': 'independent_places',
      'section': 'completeness_corpus',
      'reason':
          '$ipMissingLease/50 Rent listings missing agreement_type/lease — '
          'Property Highlights omits lease cell',
    });
  }
  if (ipMissingPets > 0) {
    medium.add({
      'marketplace': 'independent_places',
      'section': 'completeness_corpus',
      'reason':
          '$ipMissingPets/50 Rent listings missing pets policy — Highlights '
          'omits pets cell',
    });
  }
  if (slMissingOccupants > 0) {
    medium.add({
      'marketplace': 'shared_living',
      'section': 'completeness_corpus',
      'reason':
          '$slMissingOccupants/40 Share listings missing current_occupants — '
          'Household Snapshot may show cohort only or hide',
    });
  }

  // Least-complete listings with many gaps → high if score very low.
  if (leastSl.completenessScore < 0.5) {
    high.add({
      'marketplace': 'shared_living',
      'listing_id': leastSl.listingId,
      'section': 'completeness',
      'reason':
          'Least-complete Share score ${leastSl.completenessScore} '
          '(missing: ${leastSl.missingFields.join(', ')}). UI hides empty '
          'sections; match explanations may be sparse.',
    });
  }
  if (leastIp.completenessScore < 0.5) {
    high.add({
      'marketplace': 'independent_places',
      'listing_id': leastIp.listingId,
      'section': 'completeness',
      'reason':
          'Least-complete Rent score ${leastIp.completenessScore} '
          '(missing: ${leastIp.missingFields.join(', ')}). Highlights hide '
          'when empty; ranking still runs.',
    });
  }

  return {
    'blockers': blockers,
    'high': high,
    'medium': medium,
  };
}

Map<String, dynamic> _overallVerdict(Map<String, dynamic> findings) {
  final blockers = findings['blockers'] as List;
  final high = findings['high'] as List;
  final medium = findings['medium'] as List;
  if (blockers.isNotEmpty) {
    return {
      'verdict': 'FAIL',
      'reason': '${blockers.length} blocker(s) — throws, blank chips, or broken section contracts',
    };
  }
  if (high.isNotEmpty || medium.isNotEmpty) {
    return {
      'verdict': 'PASS WITH WARNINGS',
      'reason':
          'Resilient rendering; ${high.length} high + ${medium.length} medium '
          'findings (sparse sections / missing explanations / corpus gaps)',
    };
  }
  return {
    'verdict': 'PASS',
    'reason': 'All resilience checks PASS; no blockers or warnings',
  };
}

Map<String, dynamic> _successCriteria({
  required Map<String, dynamic> findings,
  required Map<String, dynamic> slResilience,
  required Map<String, dynamic> ipResilience,
  required Map<String, dynamic> emptyMapResilience,
}) {
  final blockers = findings['blockers'] as List;
  bool noFails(Map<String, dynamic> r) {
    final summary = r['section_summary'] as Map? ?? {};
    return (summary['FAIL'] as int? ?? 0) == 0;
  }

  final criteria = {
    'incomplete_listings_render':
        noFails(slResilience) && noFails(ipResilience),
    'no_broken_detail_pages': noFails(slResilience) && noFails(ipResilience),
    'no_broken_cards':
        (slResilience['sections'] as Map)['card_rendering']?['status'] !=
                'FAIL' &&
            (ipResilience['sections'] as Map)['card_rendering']?['status'] !=
                'FAIL',
    'no_empty_ui_components':
        emptyMapResilience['blank_label_cells'] == 0 &&
            blockers.every((b) =>
                !(b['reason']?.toString().toLowerCase().contains('blank') ??
                    false)),
    'match_explanations_remain_valid':
        (slResilience['sections'] as Map)['match_explanations']?['status'] !=
                'FAIL' &&
            (ipResilience['sections'] as Map)['match_explanations']?['status'] !=
                'FAIL',
    'no_runtime_errors':
        (slResilience['threw'] as List).isEmpty &&
            (ipResilience['threw'] as List).isEmpty &&
            blockers.isEmpty,
  };
  return {
    ...criteria,
    'success_criteria_met': criteria.values.every((v) => v == true),
  };
}

Map<String, dynamic> _emptyDataHandlingNotes() => {
      'blank_sections':
          'Avoided for highlight grids — listing_detail_page_layout wraps '
          'ROOM SNAPSHOT / HOUSEHOLD SNAPSHOT / CULTURE / PROPERTY DETAILS / '
          'PROPERTY HIGHLIGHTS / preference insight in `if (cells.isNotEmpty)`.',
      'empty_chips':
          'PropertyCard._CardMatchChips returns SizedBox.shrink() when no chip '
          'labels resolve; chips only appended when labels non-null/non-empty.',
      'broken_layouts':
          'Fixed-height chip row still reserved on cards (chipsHeight) even when '
          'shrink — layout gap only, not broken. Detail page Column collapses '
          'hidden sections.',
      'placeholder_text':
          'Description: "No description provided." Host: "Your host". '
          'Title ListingData fallback: "Untitled listing". Card location can '
          'fallback toward Dublin area copy.',
      'missing_explanations':
          'Preference insight card omitted when explanation list empty — '
          'expected for sparse listings / hard-filter failures.',
      'rendering_errors':
          'Helpers return empty lists rather than throwing on missing fields. '
          'Legacy ListingPropertyHighlights.gridCells fills 4 platform fallbacks.',
      'evidence_files': [
        'lib/widgets/listing_detail_page_layout.dart',
        'lib/widgets/listing_detail_commute_section.dart',
        'lib/widgets/property_card.dart',
        'lib/utils/listing_property_highlights.dart',
        'lib/utils/listing_match_engine.dart',
      ],
    };

// ── Markdown ─────────────────────────────────────────────────────────────────

String _buildMarkdown(Map<String, dynamic> payload) {
  final overall = payload['overall'] as Map;
  final extremes = payload['extremes'] as Map;
  final slExt = extremes['shared_living'] as Map;
  final ipExt = extremes['independent_places'] as Map;
  final findings = payload['findings'] as Map;
  final success = payload['success_criteria'] as Map;
  final slRes = payload['resilience']['shared_living_least_complete'] as Map;
  final ipRes =
      payload['resilience']['independent_places_least_complete'] as Map;
  final summary = payload['completeness_summary'] as Map;

  String fmtExtreme(Map m) {
    final row = m as Map;
    return '`${row['listing_id']}` score **${row['completeness_score']}** '
        '(${row['present_count']}/${row['field_count']})';
  }

  String sectionTable(Map resilience) {
    final sections = resilience['sections'] as Map;
    final buf = StringBuffer();
    buf.writeln('| Section | Status | Reason |');
    buf.writeln('|---------|--------|--------|');
    for (final key in [
      'card_rendering',
      'detail_page_story',
      'match_explanations',
      'room_snapshot',
      'property_highlights',
      'household_snapshot',
      'household_culture',
      'property_details',
      'transit_commute',
      'ranking',
    ]) {
      final s = sections[key];
      if (s is! Map) continue;
      if (s['applicable'] == false) continue;
      final reason = (s['reason'] ?? '').toString().replaceAll('|', '/');
      buf.writeln('| $key | **${s['status']}** | $reason |');
    }
    return buf.toString();
  }

  String findingsList(String key) {
    final list = findings[key] as List? ?? [];
    if (list.isEmpty) return '_None._\n';
    final buf = StringBuffer();
    for (final f in list) {
      final m = f as Map;
      buf.writeln(
        '- **${m['marketplace']}** `${m['listing_id'] ?? '—'}` / ${m['section']}: ${m['reason']}',
      );
    }
    buf.writeln();
    return buf.toString();
  }

  final buf = StringBuffer();
  buf.writeln('# Missing-Data Listing Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  buf.writeln('**${overall['verdict']}** — ${overall['reason']}');
  buf.writeln();
  buf.writeln(
    '**Success criteria met:** ${success['success_criteria_met'] == true ? 'YES' : 'NO'}',
  );
  buf.writeln();
  buf.writeln('| Criterion | Met? |');
  buf.writeln('|-----------|------|');
  for (final e in success.entries) {
    if (e.key == 'success_criteria_met') continue;
    buf.writeln('| `${e.key}` | ${e.value} |');
  }
  buf.writeln();
  buf.writeln('## Source');
  buf.writeln();
  buf.writeln('- **Dataset:** SampleListingsDublin (ListingsStorageService seed)');
  buf.writeln('- **Counts:** 40 Shared Living (`Share`) · 50 Independent Places (`Rent`)');
  buf.writeln('- **Paths:**');
  for (final p in (payload['source'] as Map)['paths'] as List) {
    buf.writeln('  - `$p`');
  }
  buf.writeln();
  buf.writeln('## PART 1 — Completeness scoring');
  buf.writeln();
  buf.writeln(
    'Score = present usable fields / relevant field set. Presence is judged '
    'via the same helpers the product uses '
    '(`ListingPropertyHighlights`, `ListingData`, `SharedLivingMatchTokens`, '
    '`TenurePreference.fromListing`).',
  );
  buf.writeln();
  buf.writeln('### Shared Living field checklist (20)');
  buf.writeln();
  buf.writeln('| Field ID | Label | Surfaces |');
  buf.writeln('|----------|-------|----------|');
  for (final f in _slFieldDefs) {
    buf.writeln('| `${f['id']}` | ${f['label']} | ${f['surfaces']} |');
  }
  buf.writeln();
  buf.writeln('### Independent Places field checklist (16)');
  buf.writeln();
  buf.writeln('| Field ID | Label | Surfaces |');
  buf.writeln('|----------|-------|----------|');
  for (final f in _ipFieldDefs) {
    buf.writeln('| `${f['id']}` | ${f['label']} | ${f['surfaces']} |');
  }
  buf.writeln();
  buf.writeln('### Extremes');
  buf.writeln();
  buf.writeln('| Marketplace | Most complete | Least complete |');
  buf.writeln('|-------------|----------------|----------------|');
  buf.writeln(
    '| Shared Living | ${fmtExtreme(slExt['most_complete'] as Map)} | ${fmtExtreme(slExt['least_complete'] as Map)} |',
  );
  buf.writeln(
    '| Independent Places | ${fmtExtreme(ipExt['most_complete'] as Map)} | ${fmtExtreme(ipExt['least_complete'] as Map)} |',
  );
  buf.writeln();

  void dumpListing(String heading, Map row) {
    buf.writeln('#### $heading');
    buf.writeln();
    buf.writeln('```');
    buf.writeln('listing_id: ${row['listing_id']}');
    buf.writeln('marketplace: ${row['marketplace']}');
    buf.writeln('completeness_score: ${row['completeness_score']}');
    buf.writeln('missing_fields: ${(row['missing_fields'] as List).join(', ')}');
    buf.writeln(
      'available_fields: ${(row['available_fields'] as List).join(', ')}',
    );
    buf.writeln('```');
    buf.writeln();
  }

  dumpListing('Shared Living — most complete', slExt['most_complete'] as Map);
  dumpListing('Shared Living — least complete', slExt['least_complete'] as Map);
  dumpListing(
    'Independent Places — most complete',
    ipExt['most_complete'] as Map,
  );
  dumpListing(
    'Independent Places — least complete',
    ipExt['least_complete'] as Map,
  );

  buf.writeln('### Corpus completeness summary');
  buf.writeln();
  for (final market in ['shared_living', 'independent_places']) {
    final s = summary[market] as Map;
    buf.writeln(
      '- **$market:** n=${s['count']} min=${s['min_score']} max=${s['max_score']} avg=${s['avg_score']}',
    );
    final top = s['most_frequently_missing'] as List? ?? [];
    if (top.isNotEmpty) {
      buf.writeln(
        '  - Most missing: ${top.map((e) => '${(e as Map)['field']}(${e['listings_missing']})').join(', ')}',
      );
    }
  }
  buf.writeln();
  buf.writeln(
    'Full per-listing table: `docs/uat/v1/missing_data_listing_audit.json` → `listings[]`.',
  );
  buf.writeln();
  buf.writeln('## PART 2 — Detail page resilience (least complete)');
  buf.writeln();
  buf.writeln(
    '### Shared Living least-complete `${slRes['listing_id']}` '
    '(score ${slRes['completeness_score']})',
  );
  buf.writeln();
  buf.write(sectionTable(slRes));
  buf.writeln();
  buf.writeln(
    '### Independent Places least-complete `${ipRes['listing_id']}` '
    '(score ${ipRes['completeness_score']})',
  );
  buf.writeln();
  buf.write(sectionTable(ipRes));
  buf.writeln();
  buf.writeln('## PART 3 — Empty data handling');
  buf.writeln();
  final empty = payload['empty_data_handling'] as Map;
  buf.writeln('| Concern | Finding |');
  buf.writeln('|---------|---------|');
  buf.writeln('| Blank sections | ${empty['blank_sections']} |');
  buf.writeln('| Empty chips | ${empty['empty_chips']} |');
  buf.writeln('| Broken layouts | ${empty['broken_layouts']} |');
  buf.writeln('| Placeholder text | ${empty['placeholder_text']} |');
  buf.writeln('| Missing explanations | ${empty['missing_explanations']} |');
  buf.writeln('| Rendering errors | ${empty['rendering_errors']} |');
  buf.writeln();
  buf.writeln('**Evidence:**');
  for (final f in empty['evidence_files'] as List) {
    buf.writeln('- `$f`');
  }
  buf.writeln();
  final synth = payload['resilience']['synthetic_empty_maps'] as Map;
  buf.writeln(
    'Synthetic `{}` maps: status **${synth['status']}** — ${synth['reason']}',
  );
  buf.writeln();
  buf.writeln('## PART 4 — UAT impact');
  buf.writeln();
  buf.writeln('**Overall:** ${overall['verdict']}');
  buf.writeln();
  buf.writeln('### Blocker findings');
  buf.writeln();
  buf.write(findingsList('blockers'));
  buf.writeln('### High severity findings');
  buf.writeln();
  buf.write(findingsList('high'));
  buf.writeln('### Medium severity findings');
  buf.writeln();
  buf.write(findingsList('medium'));
  buf.writeln('## Success criteria');
  buf.writeln();
  buf.writeln('| Criterion | Result |');
  buf.writeln('|-----------|--------|');
  buf.writeln(
    '| Incomplete listings still render correctly | ${success['incomplete_listings_render']} |',
  );
  buf.writeln(
    '| No broken detail pages | ${success['no_broken_detail_pages']} |',
  );
  buf.writeln('| No broken cards | ${success['no_broken_cards']} |');
  buf.writeln(
    '| No empty UI components (blank labels) | ${success['no_empty_ui_components']} |',
  );
  buf.writeln(
    '| Match explanations remain valid | ${success['match_explanations_remain_valid']} |',
  );
  buf.writeln('| No runtime errors | ${success['no_runtime_errors']} |');
  buf.writeln();
  buf.writeln('---');
  buf.writeln();
  buf.writeln(
    '_Generated by `test/missing_data_listing_audit_test.dart`. Audit only — '
    'no production UI changes._',
  );
  return buf.toString();
}
