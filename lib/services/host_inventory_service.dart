import '../data/dublin_mock_data.dart';
import 'listings_storage_service.dart';
import 'listings_supabase_service.dart';
import 'qa_test_auth_service.dart';

/// Owned-listing source for Home and the host dashboard.
///
/// Signed-in hosts read Supabase. A failed remote fetch throws.
/// Signed-out and demo sessions that are not signed in read local storage.
abstract final class HostInventoryService {
  static const loadErrorMessage = 'Could not load your listings. Try again.';

  static bool get usesRemote {
    try {
      return ListingsSupabaseService.canWrite;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> loadOwned(
    Map<String, dynamic>? session,
  ) async {
    if (usesRemote) {
      return ListingsSupabaseService.fetchOwnedByCurrentUser();
    }
    return _loadLocal(session);
  }

  static Future<List<Map<String, dynamic>>> _loadLocal(
    Map<String, dynamic>? session,
  ) async {
    final listings = await ListingsStorageService.ownedByCurrentUser(session);
    if (listings.isEmpty &&
        DublinMockData.useMockHarness &&
        QaTestAuthService.allowMockHostListings(session)) {
      return DublinMockData.ownedListingsForHost();
    }
    return listings;
  }
}
