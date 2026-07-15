/// Stable preference keys for proximity chip hide/pin (survive re-enrichment).
abstract final class ProximityChipKeys {
  static const transport = 'transport';
  static const groceries = 'groceries';
  static const education = 'education';
  static const healthcare = 'healthcare';
  static const lifestyle = 'lifestyle';
  static const outdoors = 'outdoors';
  static const custom = 'custom';

  /// Normalized place name used for matching across enrich cycles.
  static String normalizeName(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s*[•·]\s*\d+\s*min(?:\s*walk)?\s*$'), '');
    s = s.replaceAll(RegExp(r'^\s*\d+\s*min(?:\s*walk)?\s*[•·]?\s*'), '');
    // Drop leading emoji / symbol tokens (e.g. lifestyle "☕ Cafe").
    s = s.replaceAll(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Stable key: `category|normalizedName`.
  static String build(String category, String name) {
    final cat = category.trim().toLowerCase();
    final n = normalizeName(name);
    if (cat.isEmpty || n.isEmpty) return '';
    return '$cat|$n';
  }

  static String fromChip({
    required String category,
    required String matchName,
    required String label,
  }) {
    final name = matchName.trim().isNotEmpty ? matchName : label;
    return build(category, name);
  }
}
