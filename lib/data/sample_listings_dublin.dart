import 'sample_listings_dublin_v2.dart';

/// Dublin marketplace seed — delegates to v2 dataset (50 Rent + 40 Share).
///
/// Legacy v1 reference preserved in [sample_listings_dublin_legacy.dart].
abstract final class SampleListingsDublin {
  static List<Map<String, dynamic>> get items => SampleListingsDublinV2.items;
}
