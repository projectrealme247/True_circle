import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin_v2.dart';
import 'package:true_circle/services/demo_auth_service.dart';
import 'package:true_circle/services/profile_onboarding_repository.dart';
import 'package:true_circle/services/profile_portal_inheritance_service.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';

void main() {
  test('debug session: demo seeker share pipeline', () {
    final session = <String, dynamic>{
      'email': 'demo.seeker@truecircle.dev',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'vegetarian',
      'occupant_type': 'professional',
      'budget_max': 2500,
      'preferred_property_type': 'Share',
      'preferred_arrangement': 'shared',
    };

    final share = [
      for (final item in SampleListingsDublinV2.items)
        if (ListingData.propertyType(item) == 'Share') item,
    ];

    final snapshot = ProfileOnboardingRepository.snapshotFromSession(session);
    final filters = ProfilePortalInheritanceService.seekerFeedDefaults(snapshot);

    final result = MarketplaceListingPipeline.runWithFilters(
      allListings: share,
      towerPropertyType: 'Share',
      filters: filters,
      userSession: session,
    );

    expect(share.length, greaterThan(0));
    expect(result.afterTower.length, share.length);
    // Intentionally no assert on ranked — capturing logs only.
  });
}
