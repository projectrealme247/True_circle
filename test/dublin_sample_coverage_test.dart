import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_districts.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/utils/city_area_match.dart';
import 'package:true_circle/utils/listing_data.dart';

void main() {
  group('Dublin sample coverage', () {
    late List<Map<String, dynamic>> all;
    late List<Map<String, dynamic>> share;
    late List<Map<String, dynamic>> rent;

    setUp(() {
      all = SampleListingsDublin.items;
      share = all.where((l) => l['type'] == 'Share').toList();
      rent = all.where((l) => l['type'] == 'Rent').toList();
    });

    test('totals match 40 Share, 50 Rent, 90 combined', () {
      expect(share, hasLength(40));
      expect(rent, hasLength(50));
      expect(all, hasLength(90));
    });

    test('coverage metrics for Share, Rent, and combined pool', () {
      final shareMetrics = _computeMetrics(share, isShare: true);
      final rentMetrics = _computeMetrics(rent, isShare: false);
      final combinedMetrics = _computeMetrics(all, isShare: null);

      _assertHealthyCoverage(shareMetrics, label: 'Share');
      _assertHealthyCoverage(rentMetrics, label: 'Rent');
      _assertHealthyCoverage(combinedMetrics, label: 'Combined');

      // All 24 Dublin districts represented across the full pool.
      expect(
        combinedMetrics.districtKeysMatched.length,
        dublinDistricts.length,
        reason: 'Missing districts: '
            '${dublinDistricts.map(dublinDistrictKey).toSet().difference(combinedMetrics.districtKeysMatched)}',
      );

      // Preserve deliberate test listings.
      expect(all.any((l) => l['id'] == 'dub-rent-28'), isTrue);
      expect(all.any((l) => l['id'] == 'dub-rent-29'), isTrue);
      expect(all.any((l) => l['id'] == 'dub-rent-30'), isTrue);
      expect(all.any((l) => l['id'] == 'dub-share-25'), isTrue);

      final lowMatch = all.firstWhere((l) => l['id'] == 'dub-rent-28');
      expect(lowMatch['proximity_data'], isNull);
      expect(ListingData.location(lowMatch), contains('Cork'));

      // Print coverage report for CI / agent summary.
      _printReport('Share', shareMetrics);
      _printReport('Rent', rentMetrics);
      _printReport('Combined', combinedMetrics);
    });
  });
}

class _CoverageMetrics {
  const _CoverageMetrics({
    required this.count,
    required this.languagesPct,
    required this.dietsPct,
    required this.householdPct,
    required this.moveInPct,
    required this.propertySizePct,
    required this.areasPct,
    required this.transitPct,
    required this.districtKeysMatched,
  });

  final int count;
  final double languagesPct;
  final double dietsPct;
  final double householdPct;
  final double moveInPct;
  final double propertySizePct;
  final double areasPct;
  final double transitPct;
  final Set<String> districtKeysMatched;
}

_CoverageMetrics _computeMetrics(
  List<Map<String, dynamic>> listings, {
  required bool? isShare,
}) {
  var languages = 0;
  var diets = 0;
  var household = 0;
  var moveIn = 0;
  var propertySize = 0;
  var areas = 0;
  var transit = 0;
  final districtKeys = <String>{};

  for (final listing in listings) {
    final langs = listing['languages_spoken'];
    if (langs is List && langs.isNotEmpty) languages++;

    final food = listing['food_preference'] ?? listing['foodPreference'];
    if (food != null && food.toString().trim().isNotEmpty) diets++;

    final occupant = listing['occupantType'];
    final preferred = listing['preferred_tenant_occupant'];
    if (occupant != null && occupant.toString().trim().isNotEmpty) {
      household++;
    } else if (isShare != false &&
        preferred != null &&
        preferred.toString().trim().isNotEmpty) {
      household++;
    }

    final available = listing['available_from'];
    if (available != null && available.toString().trim().isNotEmpty) {
      moveIn++;
    }

    final shareListing = listing['type'] == 'Share';
    if (shareListing) {
      final room = listing['room_type'];
      if (room != null && room.toString().trim().isNotEmpty) propertySize++;
    } else {
      final beds = listing['bedrooms'];
      if (beds != null && beds.toString().trim().isNotEmpty) propertySize++;
    }

    final blob =
        '${ListingData.location(listing)} ${ListingData.hostCity(listing)}';
    var matchedDistrict = false;
    for (final district in dublinDistricts) {
      final key = dublinDistrictKey(district);
      if (CityAreaMatch.blobMatchesFilter(blob, key)) {
        districtKeys.add(key);
        matchedDistrict = true;
      }
    }
    if (matchedDistrict) areas++;

    if (listing['proximity_data'] != null) transit++;
  }

  final n = listings.length;
  double pct(int covered) => n == 0 ? 0 : (covered / n) * 100;

  return _CoverageMetrics(
    count: n,
    languagesPct: pct(languages),
    dietsPct: pct(diets),
    householdPct: pct(household),
    moveInPct: pct(moveIn),
    propertySizePct: pct(propertySize),
    areasPct: pct(areas),
    transitPct: pct(transit),
    districtKeysMatched: districtKeys,
  );
}

void _assertHealthyCoverage(_CoverageMetrics m, {required String label}) {
  expect(m.languagesPct, greaterThanOrEqualTo(80), reason: '$label languages');
  expect(m.dietsPct, greaterThanOrEqualTo(95), reason: '$label diets');
  expect(m.householdPct, greaterThanOrEqualTo(80), reason: '$label household');
  expect(m.moveInPct, greaterThanOrEqualTo(95), reason: '$label move-in');
  expect(m.propertySizePct, greaterThanOrEqualTo(95), reason: '$label size');
  expect(m.transitPct, greaterThanOrEqualTo(85), reason: '$label transit');
}

void _printReport(String label, _CoverageMetrics m) {
  // ignore: avoid_print
  print(
    '$label (n=${m.count}): '
    'languages=${m.languagesPct.toStringAsFixed(1)}%, '
    'diets=${m.dietsPct.toStringAsFixed(1)}%, '
    'household=${m.householdPct.toStringAsFixed(1)}%, '
    'move-in=${m.moveInPct.toStringAsFixed(1)}%, '
    'size=${m.propertySizePct.toStringAsFixed(1)}%, '
    'areas=${m.areasPct.toStringAsFixed(1)}%, '
    'transit=${m.transitPct.toStringAsFixed(1)}%, '
    'districts=${m.districtKeysMatched.length}/24',
  );
}
