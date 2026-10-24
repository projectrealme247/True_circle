import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/listings_supabase_service.dart';

void main() {
  test('owned listing row keeps the database id', () {
    final mapped = ListingsSupabaseService.mapOwnedListingRow({
      'id': 'df2752d5-7b98-4eeb-bee5-1bf614c27f5f',
      'user_id': '7c013486-4d63-4a57-a257-de21e4534cf9',
      'title': 'Test 2',
      'price': 1200,
      'location': 'Dublin',
      'description': 'A place',
      'listing_type': 'Rent',
      'marketplace_category': 'independent_places',
      'metadata': {
        'id': 'listing-local',
        'hostName': 'Host',
      },
      'created_at': '2026-10-18T20:00:00Z',
    });

    expect(mapped['id'], 'df2752d5-7b98-4eeb-bee5-1bf614c27f5f');
    expect(mapped['user_id'], '7c013486-4d63-4a57-a257-de21e4534cf9');
    expect(mapped['owner_user_id'], '7c013486-4d63-4a57-a257-de21e4534cf9');
    expect(mapped['marketplace_category'], 'independent_places');
    expect(mapped['title'], 'Test 2');
  });
}
