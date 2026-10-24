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
}
