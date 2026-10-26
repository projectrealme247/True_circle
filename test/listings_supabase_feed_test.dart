import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/listings_supabase_service.dart';

void main() {
  test('active listing fetch fails when Supabase is not ready', () {
    expect(
      ListingsSupabaseService.fetchActiveListings(),
      throwsA(isA<StateError>()),
    );
  });

  test('public listing fetch is empty when Supabase is not ready', () async {
    expect(await ListingsSupabaseService.tryFetchListings(), isEmpty);
  });

  test('listing by id is null when the id is empty', () async {
    expect(await ListingsSupabaseService.fetchListingById(''), isNull);
    expect(await ListingsSupabaseService.fetchListingById('   '), isNull);
  });

  test('listing by id fails when Supabase is not ready', () {
    expect(
      ListingsSupabaseService.fetchListingById(
        'df2752d5-7b98-4eeb-bee5-1bf614c27f5f',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
