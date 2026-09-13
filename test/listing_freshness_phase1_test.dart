import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/listing_creation_draft.dart';
import 'package:true_circle/models/listing_creation_field_keys.dart';
import 'package:true_circle/services/listing_creation_payload_builder.dart';
import 'package:true_circle/utils/listing_data.dart';

void main() {
  group('Listing freshness Phase 1', () {
    test('relative chip labels cover today, days ago, and 60+', () {
      final now = DateTime(2026, 8, 25, 15);

      expect(
        ListingData.listedRelativeChipLabel(
          {ListingData.publishedAtKey: '2026-08-25'},
          now: now,
        ),
        'Listed today',
      );
      expect(
        ListingData.listedRelativeChipLabel(
          {ListingData.publishedAtKey: '2026-08-20'},
          now: now,
        ),
        'Listed 5 days ago',
      );
      expect(
        ListingData.listedRelativeChipLabel(
          {ListingData.publishedAtKey: '2026-06-01'},
          now: now,
        ),
        'Listed 60+ days ago',
      );
    });

    test('missing published_at falls back to empty labels', () {
      expect(ListingData.listedRelativeChipLabel(const {}), isEmpty);
      expect(ListingData.listedOnDisplayLabel(const {}), isEmpty);
      expect(ListingData.publishedAt(const {}), isNull);
    });

    test('detail label uses Listed on DD MMM YYYY', () {
      final label = ListingData.listedOnDisplayLabel({
        ListingData.publishedAtKey: '2026-08-25T12:00:00.000Z',
      });
      expect(label, startsWith('Listed on '));
      expect(label.contains('Aug'), isTrue);
      expect(label.contains('2026'), isTrue);
    });

    test('normalizeItem preserves published_at', () {
      final normalized = ListingData.normalizeItem({
        'title': 'Test',
        'price': '1000',
        'location': 'Dublin',
        'type': 'Rent',
        'description': 'Desc',
        ListingData.publishedAtKey: '2026-08-01T00:00:00.000Z',
      });
      expect(
        normalized[ListingData.publishedAtKey],
        '2026-08-01T00:00:00.000Z',
      );
    });

    test('controller payload stamps published_at on first publish', () {
      const draft = ListingCreationDraft(
        title: 'Bright flat',
        price: '2000/month',
        description: 'Description long enough.',
        eircode: 'D02 X285',
        latitude: 53.3,
        longitude: -6.2,
        bedsCount: 2,
        parkingAvailable: true,
        listingAuthorizationConfirmed: true,
      );

      final local = ListingCreationPayloadBuilder.toLocalListingMap(draft);
      expect(local[ListingCreationFieldKeys.publishedAt], isNotEmpty);
      expect(
        DateTime.tryParse(local[ListingCreationFieldKeys.publishedAt].toString()),
        isNotNull,
      );
    });
  });
}
