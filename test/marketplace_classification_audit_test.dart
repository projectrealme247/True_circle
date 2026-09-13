import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/listing_data.dart';

/// Generates docs/uat/v1/marketplace_classification_audit.{json,md}
///
/// Run: `flutter test test/marketplace_classification_audit_test.dart`
void main() {
  test('marketplace classification audit dump', () {
    final items = SampleListingsDublin.items;
    final results = items.map(_classify).toList();

    final summary = <String, int>{
      'VALID': 0,
      'REVIEW': 0,
      'INVALID': 0,
      'shared_living': 0,
      'independent_places': 0,
    };
    for (final r in results) {
      summary[r['classification_status'] as String] =
          (summary[r['classification_status'] as String] ?? 0) + 1;
      summary[r['marketplace'] as String] =
          (summary[r['marketplace'] as String] ?? 0) + 1;
    }

    final payload = <String, dynamic>{
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
            'UAT workbook targets ~50 SL + ~50 IP; checked-in seed is 40 Share + 50 Rent. '
            'App home feed bootstraps from this seed via ListingsStorageService (not Firestore). '
            'Supabase public.listings was empty at last probe; remote schema drifts from local migrations. '
            'Firestore is not used.',
        'shared_living_count': summary['shared_living'],
        'independent_places_count': summary['independent_places'],
        'total': results.length,
      },
      'summary': {
        'VALID': summary['VALID'],
        'REVIEW': summary['REVIEW'],
        'INVALID': summary['INVALID'],
        'success_criteria_met': summary['INVALID'] == 0,
      },
      'listings': results,
    };

    final outDir = Directory('docs/uat/v1');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    File('docs/uat/v1/marketplace_classification_audit.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    File('docs/uat/v1/marketplace_classification_audit.md')
        .writeAsStringSync(_buildMarkdown(payload));

    // Also print compact summary for CI logs.
    // ignore: avoid_print
    print(
      'AUDIT_SUMMARY VALID=${summary['VALID']} REVIEW=${summary['REVIEW']} '
      'INVALID=${summary['INVALID']} SL=${summary['shared_living']} '
      'IP=${summary['independent_places']}',
    );

    expect(results.length, 90);
    expect(summary['shared_living'], 40);
    expect(summary['independent_places'], 50);
  });
}

Map<String, dynamic> _classify(Map<String, dynamic> item) {
  final id = ListingData.id(item);
  final title = ListingData.title(item);
  final description = ListingData.description(item);
  final tower = ListingData.listingType(item);
  final marketplace = tower == 'Share' ? 'shared_living' : 'independent_places';
  final roomType = ListingData.roomType(item);
  final bedrooms = ListingData.bedrooms(item);
  final propertyCategory =
      ListingData.text(item['property_category']).isNotEmpty
          ? ListingData.text(item['property_category'])
          : ListingData.text(item['property_type']);
  final shareRoomKind = ListingData.text(item['share_room_kind']);
  final marketplaceCategory = ListingData.text(item['marketplace_category']);
  final rent = ListingData.price(item);
  final blob = '${title.toLowerCase()} ${description.toLowerCase()} '
      '${roomType.toLowerCase()} ${bedrooms.toLowerCase()} '
      '${propertyCategory.toLowerCase()}';

  final signals = _detectSignals(blob, roomType, bedrooms, shareRoomKind);
  final statusReason = _statusFor(
    marketplace: marketplace,
    tower: tower,
    marketplaceCategory: marketplaceCategory,
    signals: signals,
    roomType: roomType,
    bedrooms: bedrooms,
    propertyCategory: propertyCategory,
    title: title,
    description: description,
  );

  return {
    'listing_id': id,
    'title': title,
    'marketplace': marketplace,
    'listing_type': tower,
    'property_type': propertyCategory.isEmpty ? null : propertyCategory,
    'room_type': roomType.isEmpty ? null : roomType,
    'bedrooms': bedrooms.isEmpty ? null : bedrooms,
    'share_room_kind': shareRoomKind.isEmpty ? null : shareRoomKind,
    'marketplace_category':
        marketplaceCategory.isEmpty ? null : marketplaceCategory,
    'rent': rent.isEmpty ? null : rent,
    'signals': signals.toList()..sort(),
    'classification_status': statusReason.$1,
    'review_reason': statusReason.$2,
  };
}

Set<String> _detectSignals(
  String blob,
  String roomType,
  String bedrooms,
  String shareRoomKind,
) {
  final s = <String>{};
  if (RegExp(r'\bentire\b|\bwhole (apartment|flat|house|place|property)\b')
      .hasMatch(blob)) {
    s.add('entire_property_language');
  }
  if (RegExp(
            r'\bprivate room\b|\ben-?suite\b|\btwin (share|room)\b|'
            r'\bshared room\b|\bbed (in |space)|master room\b|'
            r'\broom (to )?share\b|\bspare room\b|\bco-?living\b',
          ).hasMatch(blob) ||
      roomType.isNotEmpty ||
      shareRoomKind.isNotEmpty) {
    s.add('room_share_language');
  }
  if (RegExp(r'\bstudio\b').hasMatch(blob) ||
      bedrooms.toLowerCase().contains('studio')) {
    s.add('studio');
  }
  if (RegExp(r'\bannex\b|\bgranny flat\b|\bself[- ]contained\b')
      .hasMatch(blob)) {
    s.add('self_contained_edge');
  }
  if (RegExp(r'\b(\d+)\s*bed(?:room)?s?\b').hasMatch(blob) ||
      RegExp(r'^\d+\s*bed$', caseSensitive: false).hasMatch(bedrooms.trim())) {
    s.add('multi_or_n_bed_property');
  }
  if (RegExp(r'\bapartment\b|\bflat\b|\bhouse\b|\bcottage\b|\bduplex\b')
      .hasMatch(blob)) {
    s.add('property_structure_language');
  }
  return s;
}

(String, String) _statusFor({
  required String marketplace,
  required String tower,
  required String marketplaceCategory,
  required Set<String> signals,
  required String roomType,
  required String bedrooms,
  required String propertyCategory,
  required String title,
  required String description,
}) {
  if (!ListingData.propertyTypes.contains(tower)) {
    return (
      'INVALID',
      'Missing/invalid listing_type/type tower (got "$tower"); feed would default or mis-route.',
    );
  }

  if (marketplaceCategory.isNotEmpty) {
    final cat = marketplaceCategory.toLowerCase();
    final catShared = cat.contains('shared');
    final catIndependent = cat.contains('independent') ||
        cat.contains('full_rental') ||
        cat == 'full_rental';
    if (tower == 'Share' && catIndependent && !catShared) {
      return (
        'INVALID',
        'marketplace_category="$marketplaceCategory" conflicts with Share tower (Independent Places signal).',
      );
    }
    if (tower == 'Rent' && catShared) {
      return (
        'INVALID',
        'marketplace_category="$marketplaceCategory" conflicts with Rent tower (Shared Living signal).',
      );
    }
  }

  final textBlob = '${title.toLowerCase()} ${description.toLowerCase()}';

  if (marketplace == 'shared_living') {
    if (signals.contains('entire_property_language') &&
        !signals.contains('room_share_language')) {
      return (
        'INVALID',
        'Shared Living listing uses entire-property language without room-share signals.',
      );
    }
    if (signals.contains('multi_or_n_bed_property') &&
        signals.contains('property_structure_language') &&
        roomType.isEmpty &&
        !signals.contains('room_share_language')) {
      return (
        'INVALID',
        'Shared Living listing looks like an entire independent property (N-bed + property type, no room_type).',
      );
    }
    if (signals.contains('studio') || signals.contains('self_contained_edge')) {
      return (
        'REVIEW',
        'Shared Living edge case: studio/annex/self-contained language — confirm room-in-household vs exclusive unit.',
      );
    }
    if (signals.contains('entire_property_language') &&
        signals.contains('room_share_language')) {
      return (
        'REVIEW',
        'Conflicting signals: entire-property language plus room-share cues.',
      );
    }
    if (roomType.isEmpty) {
      return (
        'REVIEW',
        'Shared Living listing missing room_type; confirm it is a room share not an entire place.',
      );
    }
    return ('VALID', 'Clear Shared Living / room-share listing.');
  }

  // Independent Places
  final rt = roomType.toLowerCase();
  if (rt.isNotEmpty &&
      (rt.contains('shared') ||
          rt.contains('private room') ||
          rt.contains('ensuite') ||
          rt.contains('twin') ||
          rt.contains('bed in') ||
          rt.contains('master room'))) {
    return (
      'INVALID',
      'Independent Places listing has room-share room_type="$roomType".',
    );
  }
  if (RegExp(
        r'\b(private|shared) room\b|\bbed in shared\b|\btwin share\b|\ben-?suite\b',
      ).hasMatch(textBlob) &&
      !signals.contains('studio') &&
      !signals.contains('multi_or_n_bed_property')) {
    return (
      'INVALID',
      'Independent Places listing looks like a room share (room language without entire-place layout).',
    );
  }
  if (signals.contains('studio') || signals.contains('self_contained_edge')) {
    return (
      'REVIEW',
      'Independent Places edge case: studio/annex/self-contained — confirm exclusive entire unit (VALID if exclusive).',
    );
  }
  if (signals.contains('room_share_language') &&
      (signals.contains('property_structure_language') ||
          signals.contains('multi_or_n_bed_property'))) {
    // room_share_language may fire from empty share_room_kind only on Share;
    // on Rent, property_category alone shouldn't set room_share. If it did via
    // title words like "co-living", flag for review.
    if (RegExp(r'\bco-?living\b|\bspare room\b|\broom share\b')
        .hasMatch(textBlob)) {
      return (
        'REVIEW',
        'Independent Places has some room-share language alongside property signals — confirm exclusive use.',
      );
    }
  }
  if (bedrooms.isEmpty && propertyCategory.isEmpty) {
    return (
      'REVIEW',
      'Independent Places missing bedrooms and property_type/category — confirm entire-place layout.',
    );
  }
  return ('VALID', 'Clear Independent Places / entire-property listing.');
}

String _buildMarkdown(Map<String, dynamic> payload) {
  final source = payload['source'] as Map<String, dynamic>;
  final summary = payload['summary'] as Map<String, dynamic>;
  final listings = (payload['listings'] as List).cast<Map<String, dynamic>>();
  final invalid =
      listings.where((l) => l['classification_status'] == 'INVALID').toList();
  final review =
      listings.where((l) => l['classification_status'] == 'REVIEW').toList();
  final buf = StringBuffer();

  buf.writeln('# Marketplace Classification Audit — TrueCircle V1');
  buf.writeln();
  buf.writeln('**Audited at:** ${payload['audited_at']}');
  buf.writeln();
  buf.writeln('## Verdict');
  buf.writeln();
  final ok = summary['success_criteria_met'] == true;
  buf.writeln(
    ok
        ? '**Success criteria met:** 0 INVALID listings.'
        : '**Success criteria NOT met:** ${summary['INVALID']} INVALID listing(s).',
  );
  buf.writeln();
  buf.writeln('| Status | Count |');
  buf.writeln('|--------|------:|');
  buf.writeln('| VALID | ${summary['VALID']} |');
  buf.writeln('| REVIEW | ${summary['REVIEW']} |');
  buf.writeln('| INVALID | ${summary['INVALID']} |');
  buf.writeln('| **Total** | **${listings.length}** |');
  buf.writeln();
  buf.writeln('## Source');
  buf.writeln();
  buf.writeln('- **Dataset:** ${source['name']}');
  buf.writeln(
    '- **Counts:** ${source['shared_living_count']} Shared Living (`Share`) · '
    '${source['independent_places_count']} Independent Places (`Rent`)',
  );
  buf.writeln('- **Paths:**');
  for (final p in source['paths'] as List) {
    buf.writeln('  - `$p`');
  }
  buf.writeln('- **Notes:** ${source['notes']}');
  buf.writeln();
  buf.writeln('## Methodology');
  buf.writeln();
  buf.writeln(
    'Aligned with app tower classification in `ListingData.propertyType` / '
    '`MarketplaceSpace` / `MarketplaceListingPipeline`:',
  );
  buf.writeln();
  buf.writeln(
    '1. Canonical marketplace tower = `listing_type` → `type` → `marketplace_category` '
    '(`Share` = Shared Living, `Rent` = Independent Places).',
  );
  buf.writeln(
    '2. Feed separation is tower equality only (`Share` vs `Rent`); bleed risk is '
    'wrong tower assignment or conflicting copy/fields.',
  );
  buf.writeln(
    '3. Heuristics scan title, description, `room_type`, `bedrooms`, '
    '`property_category`, `share_room_kind` for entire-property vs room-share signals, '
    'plus studio/annex/self-contained edge cases.',
  );
  buf.writeln(
    '4. **VALID** = clear fit; **REVIEW** = ambiguous edge; **INVALID** = clear wrong '
    'marketplace or missing/conflicting critical marketplace tower field.',
  );
  buf.writeln();
  buf.writeln('## INVALID blockers');
  buf.writeln();
  if (invalid.isEmpty) {
    buf.writeln('_None._');
  } else {
    for (final l in invalid) {
      buf.writeln(
        '- `${l['listing_id']}` (${l['marketplace']}): ${l['review_reason']}',
      );
    }
  }
  buf.writeln();
  buf.writeln('## REVIEW items (human judgment)');
  buf.writeln();
  if (review.isEmpty) {
    buf.writeln('_None._');
  } else {
    buf.writeln('| listing_id | marketplace | title | review_reason |');
    buf.writeln('|------------|-------------|-------|---------------|');
    for (final l in review) {
      buf.writeln(
        '| `${l['listing_id']}` | ${l['marketplace']} | '
        '${_mdCell(l['title'])} | ${_mdCell(l['review_reason'])} |',
      );
    }
  }
  buf.writeln();
  buf.writeln('## Full listing table');
  buf.writeln();
  buf.writeln(
    '| listing_id | title | marketplace | listing_type | property_type | '
    'room_type | rent | status | review_reason |',
  );
  buf.writeln(
    '|------------|-------|-------------|--------------|---------------|'
    '----------|------|--------|---------------|',
  );
  for (final l in listings) {
    buf.writeln(
      '| `${l['listing_id']}` | ${_mdCell(l['title'])} | ${l['marketplace']} | '
      '${l['listing_type']} | ${_mdCell(l['property_type'])} | '
      '${_mdCell(l['room_type'])} | ${_mdCell(l['rent'])} | '
      '**${l['classification_status']}** | ${_mdCell(l['review_reason'])} |',
    );
  }
  buf.writeln();
  buf.writeln('## Data-access limitations');
  buf.writeln();
  buf.writeln(
    '- Frozen UAT seeker dataset / exact 50+50 listing inventory is **not checked in**.',
  );
  buf.writeln(
    '- This audit uses the **in-repo Dublin seed** (40 SL + 50 IP) that bootstraps localStorage.',
  );
  buf.writeln(
    '- Live `public.listings` in Supabase was probed separately if credentials allowed; '
    'seed remains the authoritative demo/UAT feed inventory.',
  );
  buf.writeln('- Firestore is not used by this project.');
  buf.writeln();
  return buf.toString();
}

String _mdCell(dynamic v) {
  if (v == null) return '—';
  return v.toString().replaceAll('|', '\\|').replaceAll('\n', ' ');
}
