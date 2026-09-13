import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/viewer_profile.dart';

void main() {
  const viewerSession = {
    'full_name': 'Maya',
    'detected_city': 'Dublin 8',
    'mother_tongue': 'English',
    'food_preference': 'Veg',
    'occupant_type': 'Students',
    'budget_max': 800,
    'preferred_property_type': 'Share',
  };

  Map<String, dynamic> shareListing(String price) => {
        'type': 'Share',
        'listing_type': 'Share',
        'price': price,
        'location': 'Dublin 8',
        'hostFoodPreference': 'Veg',
        'schedule_type': 'Flexible',
        'room_type': 'Private room',
      };

  test('share listings above 125% of max budget are scored not hard-excluded', () {
    final viewer = ViewerProfile.fromSession(viewerSession);
    final overBudget = ListingMatchEngine.evaluate(
      shareListing('EUR 1050'),
      viewer,
    );

    expect(overBudget.excluded, isFalse);
    // Compatibility-only scoring (no trust multiplier).
    expect(overBudget.percentage, lessThan(50));
  });

  test('allows share listings within 125% buffer', () {
    final viewer = ViewerProfile.fromSession(viewerSession);
    final withinBuffer = ListingMatchEngine.evaluate(
      shareListing('EUR 900'),
      viewer,
    );

    expect(withinBuffer.excluded, isFalse);
  });

  test('stretch zone 110-125% triggers budget warning reason', () {
    final viewer = ViewerProfile.fromSession(viewerSession);
    final stretch = ListingMatchEngine.evaluate(
      shareListing('EUR 900'),
      viewer,
    );

    expect(stretch.excluded, isFalse);
    expect(
      stretch.reasons.any((r) => r.contains('Slightly over your max budget')),
      isTrue,
    );
  });

  test('offer letter sets pre-arrival docs without trust score boost', () {
    final viewer = ViewerProfile.fromSession({
      ...viewerSession,
      'onboarding_letter_verified': true,
    });
    expect(viewer?.hasVerifiedPreArrivalDocs, isTrue);

    final listing = shareListing('EUR 750');
    final withLetter = ListingMatchEngine.evaluate(listing, viewer);
    final baselineViewer = ViewerProfile.fromSession(viewerSession);
    final baseline = ListingMatchEngine.evaluate(listing, baselineViewer);

    expect(withLetter.excluded, isFalse);
    // Trust multipliers removed — verification flags do not change match score.
    expect(withLetter.score, baseline.score);
  });
}
