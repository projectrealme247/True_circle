import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/viewer_profile.dart';

Map<String, dynamic> _shareListing({List<String> flags = const []}) => {
      'type': 'Share',
      'listing_type': 'Share',
      'price': 'EUR 800',
      'location': 'Dublin 8',
      'lifestyle_flags': flags,
      'kitchen_usage_timing': 'Flexible',
      'schedule_type': 'Flexible',
      'hostFoodPreference': 'Veg',
      'hostMotherTongue': 'English',
      'hostLanguage': 'English',
      'occupantType': 'Students',
    };

void main() {
  const shareViewerBase = {
    'full_name': 'Test',
    'detected_city': 'Dublin 8',
    'mother_tongue': 'English',
    'spoken_languages': ['English'],
    'food_preference': 'Veg',
    'budget_max': 800,
    'preferred_property_type': 'Share',
  };

  test('smoker in no-smoking household is hard-excluded for share', () {
    final viewer = ViewerProfile.fromSession({
      ...shareViewerBase,
      'smoking_ok': true,
    });
    final conflict = ListingMatchEngine.evaluate(
      _shareListing(flags: ['no_smoking']),
      viewer,
    );
    expect(conflict.excluded, isTrue);
  });

  test('quiet-hours alignment increases share score', () {
    final viewer = ViewerProfile.fromSession({
      ...shareViewerBase,
      'schedule_type': 'Day shift',
    });
    final aligned = ListingMatchEngine.evaluate(
      _shareListing(flags: ['quiet_hours_preferred']),
      viewer,
    );
    final baseline = ListingMatchEngine.evaluate(_shareListing(), viewer);
    expect(aligned.score, greaterThanOrEqualTo(baseline.score));
    expect(aligned.percentage, greaterThan(50));
  });

  test('pet owner in no-pets household is hard-excluded for share', () {
    final viewer = ViewerProfile.fromSession({
      ...shareViewerBase,
      'household_has_pets': true,
    });
    final conflict = ListingMatchEngine.evaluate(
      _shareListing(flags: ['no_pets']),
      viewer,
    );
    expect(conflict.excluded, isTrue);
  });
}
