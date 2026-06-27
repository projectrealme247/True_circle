import '../config/market/market_config.dart';
import 'sample_listings_dublin.dart';
import 'sample_listings_india.dart';

/// Market-aware sample listing seed for localStorage bootstrap.
abstract final class MarketListingsSeed {
  static List<Map<String, dynamic>> get items {
    return switch (MarketConfig.current.id) {
      MarketId.india => SampleListingsIndia.items,
      MarketId.dublin => SampleListingsDublin.items,
    };
  }
}
