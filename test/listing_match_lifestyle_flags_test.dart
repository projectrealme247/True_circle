import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/viewer_profile.dart';

Map<String, dynamic> _shareListing({List<String> flags = const []}) => {
      'type': 'Share',
      'listing_type': 'Share',
      'price': 'EUR 800',
      'lifestyle_flags': flags,
      'kitchen_usage_timing': 'Flexible',
      'schedule_type': 'Flexible',
      'hostFoodPreference': 'Veg',
    };

void main() {
  test('hard excludes smoker when listing forbids smoking', () {
    final viewer = ViewerProfile.fromSession({
      'full_name': 'Test',
      'detected_city': 'Dublin 8',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'Veg',
      'smoking_ok': true,
      'preferred_property_type': 'Share',
    });
    final result = ListingMatchEngine.evaluate(
      _shareListing(flags: ['no_smoking']),
      viewer,
    );
    expect(result.excluded, isTrue);
  });
  test('quiet-hours bonus increases share score', () {
    final viewer = ViewerProfile.fromSession({
      'full_name': 'Test',
      'detected_city': 'Dublin 8',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'Veg',
      'schedule_type': 'Day shift',
      'preferred_property_type': 'Share',
    });
    final aligned = ListingMatchEngine.evaluate(
      _shareListing(flags: ['quiet_hours_preferred']),
      viewer,
    );
    final baseline = ListingMatchEngine.evaluate(_shareListing(), viewer);
    expect(aligned.score, greaterThan(baseline.score));
  });
}
