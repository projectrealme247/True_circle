import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_circle/services/host_inventory_service.dart';
import 'package:true_circle/services/listings_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signed-out inventory reads local listings', () async {
    expect(HostInventoryService.usesRemote, isFalse);

    await ListingsStorageService.addListing({
      'id': 'local-host-1',
      'title': 'Local only',
      'user_id': 'host-local',
      'listing_type': 'Rent',
    });

    final listings = await HostInventoryService.loadOwned({
      'supabase_user_id': 'host-local',
    });

    expect(
      listings.any((item) => item['id']?.toString() == 'local-host-1'),
      isTrue,
    );
  });
}
