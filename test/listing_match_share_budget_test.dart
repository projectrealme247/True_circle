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

    'trust_stage': 1,

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
    expect(overBudget.percentage, lessThan(35));

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



  test('just landed seeker with verified docs uses grand trust multiplier', () {

    final viewer = ViewerProfile.fromSession({

      ...viewerSession,

      'onboarding_letter_verified': true,

    });

    expect(viewer?.hasVerifiedPreArrivalDocs, isTrue);

    expect(viewer?.trustStage, TrustStage.casual);



    final listing = shareListing('EUR 750');

    listing['host_trust_stage'] = 2;



    final upgraded = ListingMatchEngine.evaluate(listing, viewer);

    final baselineViewer = ViewerProfile.fromSession(viewerSession);

    final baseline = ListingMatchEngine.evaluate(listing, baselineViewer);



    expect(upgraded.excluded, isFalse);

    expect(upgraded.score, greaterThan(baseline.score));

    expect(

      upgraded.reasons.any((r) => r.contains('Pre-arrival docs verified')),

      isTrue,

    );

  });

}

