import '../models/neighborhood_amenity_tag.dart';

/// Unified POI kind for seeded metro catalogs (OpenStreetMap + local curation).
enum PoiCatalogKind {
  grocery,
  primarySchool,
  secondarySchool,
  creche,
  cafe,
  restaurant,
  pharmacy,
  gym,
  park,
  pub,
  pizzaShop,
  atm,
  asianStore,
  foodJoint,
  businessPark,
  attraction,
}

/// Maps seeded kinds to lifestyle chip categories (null = structured-only).
NeighborhoodAmenityCategory? lifestyleCategoryForKind(PoiCatalogKind kind) =>
    switch (kind) {
      PoiCatalogKind.cafe => NeighborhoodAmenityCategory.cafe,
      PoiCatalogKind.restaurant => NeighborhoodAmenityCategory.restaurant,
      PoiCatalogKind.pub => NeighborhoodAmenityCategory.pubs,
      PoiCatalogKind.pizzaShop => NeighborhoodAmenityCategory.pizzaShops,
      PoiCatalogKind.atm => NeighborhoodAmenityCategory.atms,
      PoiCatalogKind.foodJoint => NeighborhoodAmenityCategory.foodJoints,
      PoiCatalogKind.gym => NeighborhoodAmenityCategory.gym,
      PoiCatalogKind.park => NeighborhoodAmenityCategory.park,
      PoiCatalogKind.pharmacy => NeighborhoodAmenityCategory.pharmacy,
      PoiCatalogKind.asianStore => NeighborhoodAmenityCategory.asianStores,
      PoiCatalogKind.businessPark => NeighborhoodAmenityCategory.businessPark,
      PoiCatalogKind.attraction => NeighborhoodAmenityCategory.attraction,
      _ => null,
    };

class PoiCatalogEntry {
  const PoiCatalogEntry({
    required this.name,
    required this.lat,
    required this.lon,
    required this.kind,
  });

  final String name;
  final double lat;
  final double lon;
  final PoiCatalogKind kind;
}
