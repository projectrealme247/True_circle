import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/dublin_mock_data.dart';
import 'package:true_circle/models/applicant_trust_tier.dart';
import 'package:true_circle/models/listing_creation_field_keys.dart';

void main() {
  group('DublinMockData', () {
    test('shared flat listing has Ranelagh shared-living fields', () {
      final listing = DublinMockData.sharedFlatListing();

      expect(listing['id'], DublinMockData.listingId);
      expect(
        listing[ListingCreationFieldKeys.marketplaceCategory],
        'shared_living',
      );
      expect(listing['location'], contains('Ranelagh'));
      expect(listing['price'], '€1,100 / month');
      expect(
        listing[ListingCreationFieldKeys.languagesSpoken],
        ['English', 'Spanish'],
      );
      expect(listing[ListingCreationFieldKeys.bedsCount], 3);
      expect(listing['property_type'], 'Share');
    });

    test('applicant stream is flat (no trust-tier sections)', () {
      final stream = DublinMockData.applicantStream();

      expect(stream.listingId, DublinMockData.listingId);
      expect(stream.totalCount, 9);
      expect(stream.blocks, hasLength(1));
      expect(stream.blocks.first.applicants, hasLength(9));
      expect(
        stream.flattenedApplicants.map((a) => a.trustTier).toSet(),
        containsAll([
          ApplicantTrustTier.sound,
          ApplicantTrustTier.grand,
          ApplicantTrustTier.justLanded,
        ]),
      );
    });

    test('applicants expose Dublin personas with language overlap', () {
      final applicants = DublinMockData.applicantStream().flattenedApplicants;
      final byName = {for (final row in applicants) row.seekerName: row};

      final mark = byName["Mark O'Connor"]!;
      expect(mark.trustTier, ApplicantTrustTier.sound);
      expect(mark.customBioPitch, contains('Stripe'));
      expect(mark.languageAlignmentOverlap, contains('English'));
      expect(mark.lifestyleMatchScorePercent, 91);
      expect(mark.overallMatchScore, 91);
      expect(mark.verifiedTransitDurationSeconds, 1680);

      final chloe = byName['Chloe Dubois']!;
      expect(chloe.trustTier, ApplicantTrustTier.grand);
      expect(chloe.customBioPitch, contains('UCD'));
      expect(chloe.customBioPitch, contains('39a'));
      expect(chloe.languageAlignmentOverlap, contains('English'));

      final aarav = byName['Aarav Mehta']!;
      expect(aarav.trustTier, ApplicantTrustTier.justLanded);
      expect(aarav.customBioPitch, contains('Trinity'));
      expect(aarav.customBioPitch, contains('loan'));
      expect(aarav.languageAlignmentOverlap, contains('English'));
      expect(aarav.lifestyleMatchScorePercent, 76);
      expect(aarav.overallMatchScore, 76);
      expect(aarav.verifiedTransitDurationSeconds, 2400);
    });

    test('ownedListingsForHost returns harness listing', () {
      final owned = DublinMockData.ownedListingsForHost();
      expect(owned, hasLength(1));
      expect(owned.first['id'], DublinMockData.listingId);
    });
  });
}
