/// Strips electoral-division and other administrative noise from Nominatim labels.
abstract final class NominatimLabelSanitizer {
  static final _noisePatterns = <RegExp>[
    RegExp(r'\bD\s*ED\b', caseSensitive: false),
    RegExp(r'\bDED\b', caseSensitive: false),
    RegExp(r'\bFED\b', caseSensitive: false),
    RegExp(r'\bED\b(?=\s*[,)\d]|$)', caseSensitive: false),
    RegExp(r'district electoral division', caseSensitive: false),
    RegExp(r'electoral division', caseSensitive: false),
    RegExp(r'civil parish', caseSensitive: false),
    RegExp(r'\bthe ward\b', caseSensitive: false),
    RegExp(r'\bward\b', caseSensitive: false),
    RegExp(r'\b1986\b'),
    RegExp(r'\(electoral division[^)]*\)', caseSensitive: false),
    RegExp(r'\([^)]*administrative[^)]*\)', caseSensitive: false),
  ];

  /// Known noisy queries → human-readable Dublin landmarks for suggestion UI.
  static const _landmarkFallbacks = <String, String>{
    'alfie byrne road': 'East Point Business Park, Clontarf',
    'fairview': 'Fairview, Clontarf',
    'clontarf west': 'Clontarf',
    'clontarf east': 'Clontarf',
  };

  /// Cleans a single address fragment.
  static String cleanPart(String? value) {
    var trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return '';

    trimmed = trimmed.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim();

    for (final pattern in _noisePatterns) {
      trimmed = trimmed.replaceAll(pattern, ' ').trim();
    }
    trimmed = trimmed
        .replaceAll(RegExp(r'\bED\s+\d+\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+West\s*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+East\s*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+North\s*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+South\s*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (trimmed.isEmpty || isNoisyAdminPart(trimmed) || _isFullyNoisy(trimmed)) {
      return '';
    }
    return trimmed;
  }

  /// True when a fragment is electoral/admin noise unsuitable for UI labels.
  static bool isNoisyAdminPart(String? value) {
    final lower = (value ?? '').toLowerCase().trim();
    if (lower.isEmpty) return true;
    if (lower.contains('electoral division')) return true;
    if (lower.contains('civil parish')) return true;
    if (RegExp(r'\bded\b').hasMatch(lower)) return true;
    if (RegExp(r'\bfed\b').hasMatch(lower)) return true;
    if (RegExp(r'\bthe ward\b').hasMatch(lower)) return true;
    if (RegExp(r'\bward\b').hasMatch(lower) &&
        RegExp(r'\b(ed|ded|1986|\d{4})\b').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'\bed\b').hasMatch(lower) && RegExp(r'\d').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^1986$').hasMatch(lower)) return true;
    return false;
  }

  /// Locality-first place name: suburb → village → town → hamlet, then
  /// neighbourhood / quarter / optional [nameFallback].
  static String resolveLocality(
    Map<String, String?> fields, {
    String? nameFallback,
  }) {
    for (final key in const [
      'suburb',
      'village',
      'town',
      'hamlet',
      'neighbourhood',
      'quarter',
    ]) {
      final cleaned = cleanPart(fields[key]);
      if (cleaned.isNotEmpty) return cleaned;
    }
    return cleanPart(nameFallback);
  }

  /// County line for suggestion subtitles (e.g. County Dublin → Co. Dublin).
  static String formatCountyLabel(String? county) {
    final cleaned = cleanPart(county);
    if (cleaned.isEmpty) return 'Dublin';
    final lower = cleaned.toLowerCase();
    if (lower == 'dublin' || lower == 'county dublin') return 'Co. Dublin';
    if (lower.startsWith('county ')) {
      return 'Co. ${cleaned.substring(7).trim()}';
    }
    if (lower.startsWith('co. ')) return cleaned;
    return cleaned;
  }

  /// Structured fields used by map / address autocomplete.
  static ({
    String displayLabel,
    String streetLine,
    String area,
    String county,
  }) structuredFromAddress(
    Map<String, String?> fields, {
    String? nameFallback,
  }) {
    final houseNumber = cleanPart(fields['house_number']);
    final road = cleanPart(fields['road']);
    final localArea = resolveLocality(fields, nameFallback: nameFallback);
    final cityDistrict = cleanPart(fields['city_district']);
    final city = cleanPart(fields['city']);
    final municipality = cleanPart(fields['municipality']);
    final postcode = cleanPart(fields['postcode']);
    final county = formatCountyLabel(fields['county']);

    final streetLine = [
      if (houseNumber.isNotEmpty) houseNumber,
      if (road.isNotEmpty) road,
    ].join(' ');

    final district = cityDistrict.isNotEmpty
        ? cityDistrict
        : city.isNotEmpty
            ? city
            : municipality;

    final area = localArea.isNotEmpty
        ? localArea
        : (district.isNotEmpty && !isNoisyAdminPart(district) ? district : '');

    final parts = <String>[
      if (streetLine.isNotEmpty) streetLine,
      if (area.isNotEmpty && area.toLowerCase() != streetLine.toLowerCase())
        area,
      if (district.isNotEmpty &&
          district.toLowerCase() != area.toLowerCase() &&
          !partsContain(district, streetLine, area))
        district,
      if (postcode.isNotEmpty) postcode,
    ];

    var displayLabel = parts.join(', ');
    if (displayLabel.isEmpty) {
      final display = cleanPart(fields['display_name']);
      displayLabel = display.isNotEmpty
          ? formatSuggestionLabel(display)
          : (nameFallback != null ? cleanPart(nameFallback) : '');
    }

    return (
      displayLabel: displayLabel,
      streetLine: streetLine.isNotEmpty ? streetLine : displayLabel,
      area: area,
      county: county,
    );
  }

  /// Cleans a full comma-separated display string.
  static String cleanDisplayString(String raw) {
    final parts = raw
        .split(',')
        .map((part) => cleanPart(part))
        .where((part) => part.isNotEmpty)
        .toList();

    final seen = <String>{};
    final unique = <String>[];
    for (final part in parts) {
      final key = part.toLowerCase();
      if (seen.add(key)) unique.add(part);
    }

    return unique.join(', ');
  }

  /// Compact label for autocomplete / suggestion rows.
  static String formatSuggestionLabel(String raw) {
    final fallback = _lookupLandmarkFallback(raw);
    if (fallback != null) return fallback;

    final cleaned = cleanDisplayString(raw);
    if (cleaned.isEmpty) return raw.trim();

    final parts = cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length <= 2) return cleaned;

    final first = parts.first;
    final tail = parts.reversed.firstWhere(
      (part) => !_isPostcode(part) && !_isCountyLabel(part),
      orElse: () => parts.last,
    );

    if (first.toLowerCase() == tail.toLowerCase()) return first;
    return '$first, $tail';
  }

  /// Builds a readable label from Nominatim `address` map entries.
  static String fromAddressMap(Map<String, String> fields) {
    final structured = structuredFromAddress(fields);
    if (structured.displayLabel.isNotEmpty) {
      return formatSuggestionLabel(structured.displayLabel);
    }
    final display = cleanPart(fields['display_name']);
    return display.isNotEmpty ? formatSuggestionLabel(display) : '';
  }

  static String? _lookupLandmarkFallback(String raw) {
    final lower = raw.toLowerCase();
    for (final entry in _landmarkFallbacks.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static bool partsContain(String value, String a, String b) {
    final lower = value.toLowerCase();
    return lower == a.toLowerCase() || lower == b.toLowerCase();
  }

  static bool _isFullyNoisy(String part) {
    final lower = part.toLowerCase().trim();
    if (lower.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(lower)) return true;
    return false;
  }

  static bool _isPostcode(String part) =>
      RegExp(r'^[A-Z]\d{2}\s?[A-Z0-9]{4}$', caseSensitive: false)
          .hasMatch(part.replaceAll(' ', ''));

  static bool _isCountyLabel(String part) {
    final lower = part.toLowerCase();
    return lower.contains('county') ||
        lower.startsWith('co. ') ||
        lower == 'dublin' ||
        lower == 'ireland';
  }
}
