import 'marketplace_space.dart';

/// Option 2 marketplace categories for listing creation (Phase C).
enum ListingCreationCategory {
  independentPlaces(
    'independent_places',
    'Independent Places',
    'Whole Flat/House',
  ),
  sharedLiving(
    'shared_living',
    'Shared Living',
    'Rooms & Shares',
  );

  const ListingCreationCategory(
    this.storageToken,
    this.displayTitle,
    this.displaySubtitle,
  );

  final String storageToken;
  final String displayTitle;
  final String displaySubtitle;

  bool get isIndependent => this == ListingCreationCategory.independentPlaces;

  bool get isShared => this == ListingCreationCategory.sharedLiving;

  /// Tower filter token consumed by the listing pipeline (`Rent` / `Share`).
  String get towerPropertyType => switch (this) {
        ListingCreationCategory.independentPlaces => 'Rent',
        ListingCreationCategory.sharedLiving => 'Share',
      };

  static ListingCreationCategory fromStorageToken(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'shared_living' || 'shared' || 'share' => sharedLiving,
      _ => independentPlaces,
    };
  }

  static ListingCreationCategory fromMarketplaceSpace(MarketplaceSpace space) {
    return switch (space) {
      MarketplaceSpace.sharedSpace => sharedLiving,
      MarketplaceSpace.fullRental => independentPlaces,
    };
  }

  MarketplaceSpace toMarketplaceSpace() => switch (this) {
        ListingCreationCategory.independentPlaces =>
          MarketplaceSpace.fullRental,
        ListingCreationCategory.sharedLiving => MarketplaceSpace.sharedSpace,
      };
}
