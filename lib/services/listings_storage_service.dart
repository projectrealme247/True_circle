import '../config/market/market_config.dart';
import '../data/market_listings_seed.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import 'listings_storage_platform.dart'
    if (dart.library.html) 'listings_storage_platform_web.dart' as platform;

/// Persists marketplace listings as a JSON array (localStorage on web).
abstract final class ListingsStorageService {
  static String get storageKey =>
      'circlekey_listings_${MarketConfig.current.id.name}';

  static const _seedVersionKeyPrefix = 'circlekey_seed_version_';

  static String get _seedVersionKey =>
      '$_seedVersionKeyPrefix${MarketConfig.current.id.name}';

  static int get _currentSeedVersion => MarketConfig.current.seedVersion;

  static Future<List<Map<String, dynamic>>> load() async {
    var raw = await platform.loadListings(storageKey);
    final storedVersion = await platform.loadSeedVersion(_seedVersionKey);
    if (raw.isEmpty || storedVersion < _currentSeedVersion) {
      raw = MarketListingsSeed.items;
      await platform.saveSeedVersion(_seedVersionKey, _currentSeedVersion);
    }
    final normalized = ListingData.normalizeList(raw);
    if (raw.isNotEmpty) {
      await platform.saveListings(storageKey, normalized);
    }
    return normalized;
  }

  static Future<void> save(List<Map<String, dynamic>> listings) async {
    final normalized = ListingData.normalizeList(listings);
    await platform.saveListings(storageKey, normalized);
  }

  /// Saves a listing and returns the stored object. Skips duplicate id/content.
  static Future<Map<String, dynamic>> addListing(Map<String, dynamic> listing) async {
    final listings = await load();
    final listingId = listing['id'] ?? DateTime.now().millisecondsSinceEpoch;
    final withPublished = Map<String, dynamic>.from(listing);
    if (ListingData.text(withPublished[ListingData.publishedAtKey]).isEmpty) {
      withPublished[ListingData.publishedAtKey] =
          DateTime.now().toUtc().toIso8601String();
    }
    final payload = ListingData.normalizeItem({
      ...withPublished,
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
    await platform.saveListings(storageKey, next);
    return payload;
  }

  /// Listings created by the signed-in user (user id or host name match).
  static Future<List<Map<String, dynamic>>> ownedByCurrentUser(
    Map<String, dynamic>? session,
  ) async {
    if (session == null || session.isEmpty) return const [];

    final userId = ProfileData.text(session['supabase_user_id']);
    final fullName = ProfileData.text(session['full_name']).toLowerCase();
    final email = ProfileData.text(session['email']).toLowerCase();
    final listings = await load();

    return [
      for (final item in listings)
        if (_isOwnedListing(
          item,
          userId: userId,
          fullName: fullName,
          email: email,
        ))
          item,
    ];
  }

  static bool _isOwnedListing(
    Map<String, dynamic> item, {
    required String userId,
    required String fullName,
    String email = '',
  }) {
    for (final key in ['owner_user_id', 'user_id', 'landlord_id']) {
      final ownerId = ProfileData.text(item[key]);
      if (userId.isNotEmpty && ownerId.isNotEmpty && ownerId == userId) {
        return true;
      }
    }

    final ownerEmail = ProfileData.text(item['owner_email']).toLowerCase();
    if (email.isNotEmpty && ownerEmail.isNotEmpty && ownerEmail == email) {
      return true;
    }

    final host = ListingData.hostName(item).trim().toLowerCase();
    if (fullName.isNotEmpty && host.isNotEmpty && host == fullName) {
      return true;
    }
    return false;
  }

  static bool isOwnedBySession(
    Map<String, dynamic> item,
    Map<String, dynamic>? session,
  ) {
    if (session == null) return false;
    final userId = ProfileData.text(session['supabase_user_id']);
    final fullName = ProfileData.text(session['full_name']).toLowerCase();
    final email = ProfileData.text(session['email']).toLowerCase();
    return _isOwnedListing(
      item,
      userId: userId,
      fullName: fullName,
      email: email,
    );
  }

  static Future<Map<String, dynamic>> updateListing(
    String listingId,
    Map<String, dynamic> listing,
  ) async {
    final listings = await load();
    final merged = Map<String, dynamic>.from(listing);
    final index = listings.indexWhere(
      (item) => item['id']?.toString() == listingId,
    );
    // Preserve first-publish timestamp; never invent for legacy rows.
    if (ListingData.text(merged[ListingData.publishedAtKey]).isEmpty &&
        index >= 0) {
      final existing =
          ListingData.text(listings[index][ListingData.publishedAtKey]);
      if (existing.isNotEmpty) {
        merged[ListingData.publishedAtKey] = existing;
      }
    }
    final payload = ListingData.normalizeItem({
      ...merged,
      'id': listingId,
    });
    if (index < 0) {
      return addListing(payload);
    }
    final next = List<Map<String, dynamic>>.from(listings);
    next[index] = payload;
    await platform.saveListings(storageKey, ListingData.normalizeList(next));
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

  /// Removes a listing by id. Returns true if something was deleted.
  static Future<bool> deleteListing(String listingId) async {
    if (listingId.isEmpty) return false;
    final listings = await load();
    final next = listings
        .where((item) => item['id']?.toString() != listingId)
        .toList(growable: false);
    if (next.length == listings.length) return false;
    await platform.saveListings(storageKey, ListingData.normalizeList(next));
    return true;
  }
}
