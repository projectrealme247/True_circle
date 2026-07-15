import 'poi_catalog_kind.dart';
import 'generated/dublin_poi_catalog.g.dart';

/// Shared access to seeded POI catalogs (falls back to legacy inline lists).
abstract final class PoiCatalogRepository {
  static List<PoiCatalogEntry> get dublinEntries => dublinPoiCatalog;

  static bool get hasSeededDublinCatalog => dublinPoiCatalog.isNotEmpty;

  /// UTC timestamp when the Dublin catalog was last generated, or null if never seeded.
  static DateTime? get dublinCatalogGeneratedAt {
    if (dublinPoiCatalogGeneratedAt.isEmpty) return null;
    return DateTime.tryParse(dublinPoiCatalogGeneratedAt);
  }

  /// Days since catalog generation; null when catalog is empty or timestamp invalid.
  static int? get dublinCatalogAgeDays {
    final generated = dublinCatalogGeneratedAt;
    if (generated == null) return null;
    return DateTime.now().toUtc().difference(generated).inDays;
  }

  static List<PoiCatalogEntry> lifestyleEntries() => [
        for (final entry in dublinEntries)
          if (lifestyleCategoryForKind(entry.kind) != null) entry,
      ];

  static List<PoiCatalogEntry> structuredEntries(PoiCatalogKind kind) =>
      dublinEntries.where((e) => e.kind == kind).toList();
}
