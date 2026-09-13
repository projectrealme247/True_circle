import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/district_inventory_stats.dart';

void main() {
  group('DistrictInventorySnapshot.build', () {
    test('single-pass aggregates rent, beds, and tower split per district', () {
      final snapshot = DistrictInventorySnapshot.build([
        _listing(
          areaKey: 'dublin4',
          price: '2000/month',
          bedrooms: '2 bed',
          type: 'Rent',
        ),
        _listing(
          areaKey: 'dublin4',
          price: '1800/month',
          bedrooms: '1 bed',
          type: 'Rent',
        ),
        _listing(
          areaKey: 'dublin4',
          price: '900/month',
          bedrooms: 'Studio',
          type: 'Share',
        ),
        _listing(
          areaKey: 'dublin9',
          price: '2200/month',
          bedrooms: '3 bed',
          type: 'Rent',
        ),
        _listing(
          location: 'Somewhere unknown',
          price: '1500/month',
          bedrooms: '2 bed',
          type: 'Rent',
        ),
      ]);

      expect(snapshot.totalListingsScanned, 5);
      expect(snapshot.unresolvedListingCount, 1);

      final d4 = snapshot['dublin4']!;
      expect(d4.listingCount, 3);
      expect(d4.independentPlaceCount, 2);
      expect(d4.sharedLivingCount, 1);
      expect(d4.medianRent, 1800);
      expect(d4.averageRent, closeTo(1566.666, 0.01));
      expect(d4.bedroomHistogram[0], 1); // studio
      expect(d4.bedroomHistogram[1], 1);
      expect(d4.bedroomHistogram[2], 1);
      expect(d4.listingsWithAtLeastBeds(2), 1);

      final d9 = snapshot['dublin9']!;
      expect(d9.listingCount, 1);
      expect(d9.medianRent, 2200);
      expect(d9.independentPlaceCount, 1);
    });

    test('prefers listing_area_key over location blob', () {
      final key = resolveDistrictKeyForListing({
        'listing_area_key': 'dublin15',
        'location': 'Dublin 4 (Ballsbridge, Donnybrook)',
        'type': 'Rent',
        'price': '1600/month',
      });
      expect(key, 'dublin15');
    });

    test('resolves district from location label when key missing', () {
      final key = resolveDistrictKeyForListing({
        'location': 'Dublin 3 (Clontarf, Fairview)',
        'type': 'Rent',
        'price': '1700/month',
      });
      expect(key, 'dublin3');
    });
  });
}

Map<String, dynamic> _listing({
  String? areaKey,
  String? location,
  required String price,
  required String bedrooms,
  required String type,
}) {
  return {
    if (areaKey != null) 'listing_area_key': areaKey,
    if (location != null) 'location': location,
    'price': price,
    'bedrooms': bedrooms,
    'type': type,
    'listing_type': type,
  };
}
