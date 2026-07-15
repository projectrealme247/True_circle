import '../config/market/market_config.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';

enum MarketplaceSpace { fullRental, sharedSpace;
  /// Option 2 primary tower title (home filter toggle).
  String get option2Title => switch (this) {
        MarketplaceSpace.fullRental => 'Independent Places',
        MarketplaceSpace.sharedSpace => 'Shared Living',
      };

  /// Hero segmented control label — onboarding emoji primitives.
  String get option2HeroLabel => switch (this) {
        MarketplaceSpace.fullRental => '🏡 Independent Places',
        MarketplaceSpace.sharedSpace => '👥 Shared Living',
      };

  String get option2HeroEmoji => switch (this) {
        MarketplaceSpace.fullRental => '🏠',
        MarketplaceSpace.sharedSpace => '👥',
      };

  /// Hero segmented control text without leading emoji.
  String get option2HeroText => option2Title;

  /// Option 2 subtitle under each tower title.
  String get option2Subtitle => switch (this) {
        MarketplaceSpace.fullRental => 'Whole Flat/House',
        MarketplaceSpace.sharedSpace => 'Rooms & Shares',
      };

  String get label => option2Title;
  String get arrangementBackend => switch (this) { MarketplaceSpace.fullRental => 'full_rent', MarketplaceSpace.sharedSpace => 'shared' };
  String get towerPropertyType => switch (this) { MarketplaceSpace.fullRental => 'Rent', MarketplaceSpace.sharedSpace => 'Share' };
  String get storageToken => switch (this) { MarketplaceSpace.fullRental => 'full_rental', MarketplaceSpace.sharedSpace => 'shared_space' };
  static List<MarketplaceSpace> enabledForMarket() {
    final towers = MarketConfig.current.enabledTowers;
    final spaces = <MarketplaceSpace>[];
    if (towers.contains('Rent')) spaces.add(MarketplaceSpace.fullRental);
    if (towers.contains('Share')) spaces.add(MarketplaceSpace.sharedSpace);
    return spaces.isEmpty ? [MarketplaceSpace.fullRental, MarketplaceSpace.sharedSpace] : spaces;
  }
  static MarketplaceSpace fromTowerPropertyType(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (ListingData.isRoomShare({'listing_type': normalized, 'type': normalized})) return MarketplaceSpace.sharedSpace;
    return MarketplaceSpace.fullRental;
  }
  static MarketplaceSpace fromSession(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return MarketplaceSpace.fullRental;
    final arrangement = ProfileData.text(session['preferred_arrangement']).toLowerCase();
    if (arrangement == 'shared' || arrangement.contains('shared')) return MarketplaceSpace.sharedSpace;
    if (ProfileData.text(session['preferred_property_type']) == 'Share') return MarketplaceSpace.sharedSpace;
    return MarketplaceSpace.fullRental;
  }
  static MarketplaceSpace fromStorageToken(String? raw) => switch (raw?.trim().toLowerCase()) {
    'shared' || 'shared_space' || 'share' => MarketplaceSpace.sharedSpace,
    _ => MarketplaceSpace.fullRental,
  };
}

enum MarketplaceWorkflow { browsing, listing, managing, replacing }
