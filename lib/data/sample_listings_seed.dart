export 'market_listings_seed.dart';
export 'sample_listings_india.dart';
export 'sample_listings_dublin.dart';

import 'market_listings_seed.dart';

/// @deprecated Use [MarketListingsSeed] instead.
abstract final class SampleListingsSeed {
  static List<Map<String, dynamic>> get items => MarketListingsSeed.items;
}
