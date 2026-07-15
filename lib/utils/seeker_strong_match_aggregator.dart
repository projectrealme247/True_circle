import '../services/listings_storage_service.dart';
import '../services/marketplace_context_notifier.dart';
import 'listing_search_intent.dart';
import 'marketplace_listing_pipeline.dart';
import 'seeker_strong_match_counter.dart';

/// Lightweight strong-match count for cross-mode badges outside HomeScreen.
abstract final class SeekerStrongMatchAggregator {
  static Future<int> countForSession(Map<String, dynamic>? session) async {
    if (session == null || session.isEmpty) return 0;
    final listings = await ListingsStorageService.load();
    final space = marketplaceContextNotifier.activeSpace;
    final result = MarketplaceListingPipeline.runWithFilters(
      allListings: listings,
      towerPropertyType: space.towerPropertyType,
      filters: const ListingSearchFilters(),
      userSession: session,
    );
    return SeekerStrongMatchCounter.count(result.ranked);
  }
}
