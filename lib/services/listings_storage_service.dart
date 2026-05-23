import '../data/sample_listings_seed.dart';
import '../utils/listing_data.dart';
import 'listings_storage_platform.dart'
    if (dart.library.html) 'listings_storage_platform_web.dart' as platform;

/// Persists marketplace listings as a JSON array (localStorage on web).
abstract final class ListingsStorageService {
  static const storageKey = 'circlekey_listings';
  static const _seedVersionKey = 'circlekey_seed_version';
  static const _currentSeedVersion = 3;

  static Future<List<Map<String, dynamic>>> load() async {
    var raw = await platform.loadListings();
    final storedVersion = await platform.loadSeedVersion(_seedVersionKey);
    if (raw.isEmpty || storedVersion < _currentSeedVersion) {
      raw = SampleListingsSeed.items;
      await platform.saveSeedVersion(_seedVersionKey, _currentSeedVersion);
    }
    final normalized = ListingData.normalizeList(raw);
    if (raw.isNotEmpty) {
      await platform.saveListings(normalized);
    }
    return normalized;
  }

  static Future<void> save(List<Map<String, dynamic>> listings) async {
    final normalized = ListingData.normalizeList(listings);
    await platform.saveListings(normalized);
  }

  /// Saves a listing and returns the stored object. Skips duplicate id/content.
  static Future<Map<String, dynamic>> addListing(Map<String, dynamic> listing) async {
    final listings = await load();
    final listingId = listing['id'] ?? DateTime.now().millisecondsSinceEpoch;
    final payload = ListingData.normalizeItem({
      ...listing,
      'id': listingId,
    });

    final fingerprint = ListingData.listingFingerprint(payload);

    for (final existing in listings) {
      if (existing['id'].toString() == payload['id'].toString()) {
        return existing;
      }
      if (ListingData.listingFingerprint(existing) == fingerprint) {
        return existing;
      }
    }

    final next = List<Map<String, dynamic>>.from(listings)..add(payload);
    await platform.saveListings(next);
    return payload;
  }

  static Future<Map<String, dynamic>?> getById(String id) async {
    if (id.isEmpty) return null;
    final listings = await load();
    for (var i = 0; i < listings.length; i++) {
      final item = listings[i];
      if (item['id']?.toString() == id) return item;
      if (id == 'listing-$i') return item;
    }
    return null;
  }
}
