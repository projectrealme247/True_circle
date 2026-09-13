import '../models/listing_creation_form_models.dart';
import '../models/neighborhood_amenity_tag.dart';
import 'listing_data.dart';

/// One named neighbourhood place for listing detail (presentation-only).
///
/// Reads persisted listing proximity fields; never fabricates names or re-queries.
class NeighbourhoodHighlight {
  const NeighbourhoodHighlight({
    required this.emoji,
    required this.categoryLabel,
    required this.placeName,
    required this.priority,
    this.walkMin,
  });

  final String emoji;
  final String categoryLabel;
  final String placeName;
  final int? walkMin;

  /// Lower is shown earlier.
  final int priority;

  String get distanceLabel {
    final minutes = walkMin;
    if (minutes == null || minutes <= 0) return '';
    return '$minutes min walk';
  }

  /// Compact chip: `🏫 Tyrrelstown Educate Together National School`
  String get chipLabel => '$emoji $placeName';

  /// Chip with short walk cue when known: `🛒 Spar · 6 min`
  String get compactChipLabel {
    final minutes = walkMin;
    if (minutes == null || minutes <= 0) return chipLabel;
    return '$emoji $placeName · $minutes min';
  }

  /// Legacy card string (unused on discovery cards).
  String get cardLabel {
    final distance = distanceLabel;
    if (distance.isEmpty) return chipLabel;
    return '$emoji $placeName · $distance';
  }

  String get detailLabel {
    final distance = distanceLabel;
    if (distance.isEmpty) return '$emoji $categoryLabel\n$placeName';
    return '$emoji $categoryLabel\n$placeName\n$distance';
  }
}

/// Grouped neighbourhood section for listing detail scanning.
class NeighbourhoodHighlightSection {
  const NeighbourhoodHighlightSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<NeighbourhoodHighlight> items;
}

abstract final class NeighbourhoodHighlights {
  NeighbourhoodHighlights._();

  static const cardMax = 3;
  static const detailMax = 20;
  static const lifestylePreviewMax = 4;

  /// Detail sections in scan order (Education → … → Lifestyle).
  static const detailSectionOrder = <String>[
    'Education',
    'Groceries',
    'Transport',
    'Healthcare',
    'Lifestyle',
  ];

  static String sectionTitleFor(NeighbourhoodHighlight item) {
    return switch (item.categoryLabel) {
      'Primary School' || 'Secondary School' || 'College / University' =>
        'Education',
      'Grocery' => 'Groceries',
      'Public Transport' => 'Transport',
      'Healthcare' => 'Healthcare',
      _ => 'Lifestyle',
    };
  }

  /// Grouped neighbourhood sections for listing detail.
  static List<NeighbourhoodHighlightSection> groupedForDetail(
    Map<String, dynamic> listing,
  ) {
    final items = forDetail(listing);
    if (items.isEmpty) return const [];

    final buckets = <String, List<NeighbourhoodHighlight>>{
      for (final title in detailSectionOrder) title: <NeighbourhoodHighlight>[],
    };
    for (final item in items) {
      final title = sectionTitleFor(item);
      buckets.putIfAbsent(title, () => <NeighbourhoodHighlight>[]).add(item);
    }

    return [
      for (final title in detailSectionOrder)
        if ((buckets[title] ?? const []).isNotEmpty)
          NeighbourhoodHighlightSection(
            title: title,
            items: List<NeighbourhoodHighlight>.unmodifiable(buckets[title]!),
          ),
    ];
  }

  /// Named highlights from persisted proximity, priority-ordered.
  ///
  /// Multiple groceries / lifestyle / transit items are kept (deduped by name).
  static List<NeighbourhoodHighlight> fromListing(
    Map<String, dynamic> listing, {
    int limit = detailMax,
  }) {
    final candidates = <NeighbourhoodHighlight>[
      ..._fromPersistedDraft(listing),
      ..._fromProximityData(listing),
      ..._fromCustomPoints(listing),
    ];

    final byName = <String, NeighbourhoodHighlight>{};
    for (final item in candidates) {
      if (!_hasRealName(item.placeName)) continue;
      final key = _normalizeKey(item.placeName);
      if (key.isEmpty) continue;
      final existing = byName[key];
      if (existing == null) {
        byName[key] = item;
        continue;
      }
      final byPriority = item.priority.compareTo(existing.priority);
      if (byPriority < 0) {
        byName[key] = item;
        continue;
      }
      if (byPriority == 0) {
        final existingWalk = existing.walkMin ?? 999;
        final nextWalk = item.walkMin ?? 999;
        if (nextWalk < existingWalk) byName[key] = item;
      }
    }

    final ranked = byName.values.toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        final aWalk = a.walkMin ?? 999;
        final bWalk = b.walkMin ?? 999;
        final byWalk = aWalk.compareTo(bWalk);
        if (byWalk != 0) return byWalk;
        return a.placeName.compareTo(b.placeName);
      });

    if (limit <= 0) return const [];
    return ranked.take(limit).toList();
  }

  static List<NeighbourhoodHighlight> forCard(Map<String, dynamic> listing) =>
      fromListing(listing, limit: cardMax);

  static List<NeighbourhoodHighlight> forDetail(Map<String, dynamic> listing) =>
      fromListing(listing, limit: detailMax);

  static List<NeighbourhoodHighlight> _fromPersistedDraft(
    Map<String, dynamic> listing,
  ) {
    final raw = listing['neighborhood_proximity'];
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    final draft = NeighborhoodProximityDraft.fromJson(map);
    final out = <NeighbourhoodHighlight>[];

    final primary = _cleanName(draft.primarySchool);
    if (_hasRealName(primary)) {
      out.add(
        NeighbourhoodHighlight(
          emoji: '🏫',
          categoryLabel: 'Primary School',
          placeName: primary,
          walkMin: _positiveWalk(draft.primarySchoolWalkMin),
          priority: 1,
        ),
      );
    }

    final secondary = _cleanName(draft.secondarySchool);
    if (_hasRealName(secondary)) {
      out.add(
        NeighbourhoodHighlight(
          emoji: '🏫',
          categoryLabel: 'Secondary School',
          placeName: secondary,
          walkMin: _positiveWalk(draft.secondarySchoolWalkMin),
          priority: 2,
        ),
      );
    }

    final college = _cleanName(draft.collegeSchool);
    if (_hasRealName(college)) {
      out.add(
        NeighbourhoodHighlight(
          emoji: '🎓',
          categoryLabel: 'College / University',
          placeName: college,
          walkMin: _positiveWalk(draft.collegeWalkMin),
          priority: 3,
        ),
      );
    }

    if (draft.groceries.isNotEmpty) {
      for (final grocery in draft.groceries) {
        final brand = _cleanName(grocery.brand);
        if (!_hasRealName(brand)) continue;
        out.add(
          NeighbourhoodHighlight(
            emoji: '🛒',
            categoryLabel: 'Grocery',
            placeName: brand,
            walkMin: _positiveWalk(grocery.walkMin),
            priority: 4,
          ),
        );
      }
    } else {
      // Avoid Tesco default fabrication: only when brand key was present.
      final groceryRaw = map['grocery_brand'];
      final grocery = groceryRaw == null ? '' : _cleanName(groceryRaw);
      if (_hasRealName(grocery)) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🛒',
            categoryLabel: 'Grocery',
            placeName: grocery,
            walkMin: _positiveWalk(draft.groceryWalkMin),
            priority: 4,
          ),
        );
      }
    }

    final transportRaw = ListingData.text(draft.transportLine);
    final transportName = _transportDisplayName(transportRaw);
    if (_hasRealName(transportName)) {
      out.add(
        NeighbourhoodHighlight(
          emoji: _transportEmoji(transportRaw),
          categoryLabel: 'Public Transport',
          placeName: transportName,
          walkMin: _positiveWalk(draft.transportWalkMin),
          priority: 5,
        ),
      );
    }

    for (final transit in draft.extraTransit) {
      final line = ListingData.text(transit.line);
      if (line.toLowerCase().startsWith('hospital')) {
        final hospital = _transportDisplayName(line);
        if (!_hasRealName(hospital)) continue;
        out.add(
          NeighbourhoodHighlight(
            emoji: '🏥',
            categoryLabel: 'Healthcare',
            placeName: hospital.contains('·')
                ? hospital.split('·').sublist(1).join('·').trim()
                : hospital,
            walkMin: _positiveWalk(transit.walkMin),
            priority: 6,
          ),
        );
        continue;
      }
      final name = _transportDisplayName(line);
      if (!_hasRealName(name)) continue;
      out.add(
        NeighbourhoodHighlight(
          emoji: _transportEmoji(line),
          categoryLabel: 'Public Transport',
          placeName: name,
          walkMin: _positiveWalk(transit.walkMin),
          priority: 5,
        ),
      );
    }

    final gp = _cleanName(draft.gpClinic);
    if (_hasRealName(gp)) {
      out.add(
        NeighbourhoodHighlight(
          emoji: '🏥',
          categoryLabel: 'Healthcare',
          placeName: gp,
          walkMin: _positiveWalk(draft.gpWalkMin),
          priority: 6,
        ),
      );
    }

    for (final tag in draft.lifestyleTags) {
      final name = _cleanName(tag.name);
      if (!_hasRealName(name)) continue;
      final walk = tag.distanceKm > 0
          ? ((tag.distanceKm * 1000) / 80).round().clamp(1, 60)
          : null;
      if (tag.category == NeighborhoodAmenityCategory.pharmacy) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🏥',
            categoryLabel: 'Healthcare',
            placeName: name,
            walkMin: walk,
            priority: 6,
          ),
        );
        continue;
      }
      out.add(
        NeighbourhoodHighlight(
          emoji: _lifestyleEmoji(tag),
          categoryLabel: 'Lifestyle',
          placeName: name,
          walkMin: walk,
          priority: 7,
        ),
      );
    }

    return out;
  }

  static List<NeighbourhoodHighlight> _fromProximityData(
    Map<String, dynamic> listing,
  ) {
    final proximity = ListingData.proximityData(listing);
    if (proximity == null) return const [];

    final out = <NeighbourhoodHighlight>[];

    final stopRaw = ListingData.text(
      proximity['nearest_stop_name'] ??
          proximity['nearest_transit_name'] ??
          proximity['transit_name'],
    );
    final transitType = ListingData.transitTypeLabel(listing);
    final composed = stopRaw.isEmpty
        ? ''
        : (transitType.isNotEmpty &&
                !_isGenericTransportPlace(stopRaw) &&
                !stopRaw.contains('·')
            ? '$transitType · $stopRaw'
            : stopRaw);
    final transportName = _transportDisplayName(composed.isEmpty ? stopRaw : composed);
    final walk = ListingData.transitWalkMinutes(listing) ??
        _intFrom(proximity, const [
          'bus_minutes',
          'dart_minutes',
          'luas_minutes',
          'walk_minutes',
          'nearest_transit_minutes',
        ]);
    if (_hasRealName(transportName)) {
      out.add(
        NeighbourhoodHighlight(
          emoji: _transportEmoji('$transitType $stopRaw'),
          categoryLabel: 'Public Transport',
          placeName: transportName,
          walkMin: walk,
          priority: 5,
        ),
      );
    }

    return out;
  }

  static List<NeighbourhoodHighlight> _fromCustomPoints(
    Map<String, dynamic> listing,
  ) {
    final raw = listing['neighborhood_proximity'];
    if (raw is! Map) return const [];
    final draft = NeighborhoodProximityDraft.fromJson(
      Map<String, dynamic>.from(raw),
    );
    final out = <NeighbourhoodHighlight>[];

    for (final point in draft.customPoints) {
      final name = _cleanName(point.name);
      if (!_hasRealName(name)) continue;
      final walk = point.walkMin > 0 ? point.walkMin : null;
      final lower = name.toLowerCase();

      if (_isCollegeName(lower)) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🎓',
            categoryLabel: 'College / University',
            placeName: name,
            walkMin: walk,
            priority: 3,
          ),
        );
        continue;
      }

      if (_isHealthcareName(lower)) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🏥',
            categoryLabel: 'Healthcare',
            placeName: name,
            walkMin: walk,
            priority: 6,
          ),
        );
        continue;
      }

      if (lower.contains('secondary') ||
          lower.contains('community college')) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🏫',
            categoryLabel: 'Secondary School',
            placeName: name,
            walkMin: walk,
            priority: 2,
          ),
        );
        continue;
      }

      if ((lower.contains('primary') && !lower.contains('primary care')) ||
          lower.contains('national school')) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🏫',
            categoryLabel: 'Primary School',
            placeName: name,
            walkMin: walk,
            priority: 1,
          ),
        );
        continue;
      }

      if (point.category == ProximityPointCategory.grocery ||
          _isGroceryName(lower)) {
        out.add(
          NeighbourhoodHighlight(
            emoji: '🛒',
            categoryLabel: 'Grocery',
            placeName: name,
            walkMin: walk,
            priority: 4,
          ),
        );
        continue;
      }

      if (point.category == ProximityPointCategory.transport ||
          _looksLikeTransport(lower)) {
        final transportName = _transportDisplayName(name);
        if (!_hasRealName(transportName)) continue;
        out.add(
          NeighbourhoodHighlight(
            emoji: _transportEmoji(name),
            categoryLabel: 'Public Transport',
            placeName: transportName,
            walkMin: walk,
            priority: 5,
          ),
        );
        continue;
      }

      // Remaining custom amenities → lifestyle.
      out.add(
        NeighbourhoodHighlight(
          emoji: '📍',
          categoryLabel: 'Lifestyle',
          placeName: name,
          walkMin: walk,
          priority: 7,
        ),
      );
    }

    return out;
  }

  /// Prefer full `Dublin Bus · The Oaks` when the place segment is real.
  static String _transportDisplayName(Object? raw) {
    final cleaned = _cleanName(raw);
    if (cleaned.isEmpty) return '';

    final parts = cleaned.split('·');
    if (parts.length >= 2) {
      final place = parts.sublist(1).join('·').trim();
      if (_isGenericTransportPlace(place)) return '';
      return cleaned;
    }

    if (_isGenericTransportPlace(cleaned)) return '';
    return cleaned;
  }

  static bool _isGenericTransportPlace(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return true;
    const generics = {
      'stop',
      'bus stop',
      'bus',
      'dublin bus',
      'luas',
      'dart',
      'rail',
      'train',
      'tram',
      'public transport',
      'transit',
      'hospital',
    };
    return generics.contains(lower);
  }

  static bool _looksLikeTransport(String lower) =>
      lower.contains('bus') ||
      lower.contains('luas') ||
      lower.contains('dart') ||
      lower.contains('rail') ||
      lower.contains('tram') ||
      lower.contains('stop');

  static bool _isGroceryName(String lower) =>
      lower.contains('tesco') ||
      lower.contains('dunnes') ||
      lower.contains('lidl') ||
      lower.contains('aldi') ||
      lower.contains('supervalu') ||
      lower.contains('centra') ||
      lower.contains('spar') ||
      lower.contains('grocery') ||
      lower.contains('supermarket');

  static bool _isCollegeName(String lower) =>
      lower.contains('university') ||
      lower.contains('institute') ||
      (lower.contains('college') && !lower.contains('community college'));

  static bool _isHealthcareName(String lower) =>
      lower.contains('clinic') ||
      lower.contains('hospital') ||
      lower.contains('gp') ||
      lower.contains('doctor') ||
      lower.contains('medical') ||
      lower.contains('pharmacy') ||
      lower.contains('primary care') ||
      lower.contains('health');

  static String _lifestyleEmoji(NeighborhoodAmenityTag tag) {
    final emoji = tag.emoji.trim();
    if (emoji.isNotEmpty) return emoji;
    return switch (tag.category) {
      NeighborhoodAmenityCategory.cafe => '☕',
      NeighborhoodAmenityCategory.pubs => '🍺',
      NeighborhoodAmenityCategory.pizzaShops ||
      NeighborhoodAmenityCategory.restaurant ||
      NeighborhoodAmenityCategory.foodJoints =>
        '🍽️',
      NeighborhoodAmenityCategory.gym => '🏋️',
      NeighborhoodAmenityCategory.atms => '🏧',
      NeighborhoodAmenityCategory.park => '🌳',
      NeighborhoodAmenityCategory.pharmacy => '🏥',
      _ => '☕',
    };
  }

  static String _transportEmoji(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('luas') || lower.contains('tram')) return '🚊';
    if (lower.contains('dart') ||
        lower.contains('rail') ||
        lower.contains('train')) {
      return '🚆';
    }
    return '🚌';
  }

  static String _cleanName(Object? raw) {
    var text = ListingData.text(raw);
    if (text.isEmpty) return '';
    text = text
        .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
        .trim();
    text = text.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    text = text
        .replaceAll(
          RegExp(r'\s*[•·]\s*\d+\s*min(?:\s*walk)?$', caseSensitive: false),
          '',
        )
        .trim();
    return text;
  }

  static String _normalizeKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _hasRealName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2) return false;
    return RegExp(r'\p{L}', unicode: true).hasMatch(trimmed);
  }

  static int? _positiveWalk(Object? raw) {
    if (raw is num && raw > 0) return raw.round();
    final parsed = int.tryParse(ListingData.text(raw));
    if (parsed != null && parsed > 0) return parsed;
    return null;
  }

  static int? _intFrom(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = _positiveWalk(map[key]);
      if (value != null) return value;
    }
    return null;
  }
}
