import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/listing_creation_form_models.dart';
import 'package:true_circle/models/move_in_timing.dart';
import 'package:true_circle/models/seeker_onboarding_enums.dart';

void main() {
  group('ListingParkingFeature', () {
    test('house options exclude apartment tokens', () {
      expect(
        ListingParkingFeature.optionsFor(ListingPropertySubType.house),
        [
          ListingParkingFeature.onStreet,
          ListingParkingFeature.driveway,
          ListingParkingFeature.garage,
        ],
      );
    });

    test('apartment options are bike + resident car', () {
      expect(
        ListingParkingFeature.optionsFor(ListingPropertySubType.apartment),
        [
          ListingParkingFeature.bikeParking,
          ListingParkingFeature.residentCar,
        ],
      );
    });

    test('parseFeatures reads multi-select array', () {
      final features = ListingParkingFeature.parseFeatures({
        'parking_features': ['driveway', 'garage'],
      });
      expect(features, {
        ListingParkingFeature.driveway,
        ListingParkingFeature.garage,
      });
    });

    test('parseFeatures maps legacy single parking_type', () {
      final features = ListingParkingFeature.parseFeatures({
        'parking_type': 'secure_bike_parking',
      });
      expect(features, {ListingParkingFeature.bikeParking});
    });

    test('empty selection means no parking', () {
      expect(ListingParkingFeature.parseFeatures({}), isEmpty);
      expect(
        ListingParkingFeature.parseFeatures({'parking_type': 'not_available'}),
        isEmpty,
      );
    });
  });

  group('Independent Place lease + availability', () {
    test('IP listing lease choices exclude Flexible', () {
      expect(
        TenurePreference.independentPlaceValues,
        [TenurePreference.temporary, TenurePreference.longTerm],
      );
    });

    test('legacy flexible tenure migrates to long_term for IP seekers', () {
      expect(
        TenurePreference.migrateIndependentPlace(TenurePreference.flexible),
        TenurePreference.longTerm,
      );
      expect(
        TenurePreference.fromSession({'tenure_preference': 'flexible'}),
        TenurePreference.longTerm,
      );
      final session = <String, dynamic>{'tenure_preference': 'flexible'};
      TenurePreference.migrateIndependentPlaceSession(session);
      expect(session['tenure_preference'], 'long_term');
    });

    test('availability selectable values are +15 / +1 Month / Flexible', () {
      expect(
        LandlordAvailabilityFlexibility.independentPlaceValues,
        [
          LandlordAvailabilityFlexibility.plus15Days,
          LandlordAvailabilityFlexibility.plus1Month,
          LandlordAvailabilityFlexibility.flexible,
        ],
      );
    });

    test('exact_date and fixed migrate to Flexible for IP', () {
      expect(
        LandlordAvailabilityFlexibility.parse('exact_date'),
        LandlordAvailabilityFlexibility.fixed,
      );
      expect(
        LandlordAvailabilityFlexibility.migrateIndependentPlace(
          LandlordAvailabilityFlexibility.fixed,
        ),
        LandlordAvailabilityFlexibility.flexible,
      );
      expect(
        LandlordAvailabilityFlexibility.migrateIndependentPlace(
          LandlordAvailabilityFlexibility.parse('exact_date'),
        ),
        LandlordAvailabilityFlexibility.flexible,
      );
    });

    test('legacy flexible token still parses for matching', () {
      expect(
        LandlordAvailabilityFlexibility.parse('flexible'),
        LandlordAvailabilityFlexibility.flexible,
      );
    });
  });
}
