import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/listing_seed_published_at.dart';
import 'package:true_circle/data/market_listings_seed.dart';
import 'package:true_circle/data/sample_listings_dublin.dart';
import 'package:true_circle/data/sample_listings_india.dart';
import 'package:true_circle/utils/listing_data.dart';

void main() {
  group('Listing Freshness Phase 1.1 seeds', () {
    final fixedNow = DateTime(2026, 8, 25, 15);

    test('bucket helper covers all six ages', () {
      final labels = <String>{};
      for (var i = 0; i < 6; i++) {
        final iso = ListingSeedPublishedAt.forId('id-$i', now: fixedNow);
        final label = ListingData.listedRelativeChipLabel(
          {ListingData.publishedAtKey: iso},
          now: fixedNow,
        );
        labels.add(label);
      }
      expect(
        labels,
        containsAll([
          'Listed today',
          'Listed 3 days ago',
          'Listed 7 days ago',
          'Listed 14 days ago',
          'Listed 30 days ago',
          'Listed 60+ days ago',
        ]),
      );
    });

    test('every Dublin seed listing has parseable published_at', () {
      final items = SampleListingsDublin.items;
      expect(items, isNotEmpty);
      final dist = <String, int>{};
      for (final raw in items) {
        final item = ListingData.normalizeItem(Map<String, dynamic>.from(raw));
        expect(
          ListingData.text(item[ListingData.publishedAtKey]),
          isNotEmpty,
          reason: 'missing published_at on ${item['id']}',
        );
        expect(
          ListingData.publishedAt(item),
          isNotNull,
          reason: 'unparseable published_at on ${item['id']}',
        );
        final label =
            ListingData.listedRelativeChipLabel(item, now: fixedNow);
        expect(label, isNotEmpty);
        dist[label] = (dist[label] ?? 0) + 1;
        expect(ListingData.listedOnDisplayLabel(item), startsWith('Listed on '));
      }
      expect(dist.keys, hasLength(6));
    });

    test('every India seed listing has parseable published_at', () {
      final items = SampleListingsIndia.items;
      expect(items, isNotEmpty);
      final dist = <String, int>{};
      for (final raw in items) {
        final item = ListingData.normalizeItem(Map<String, dynamic>.from(raw));
        expect(ListingData.publishedAt(item), isNotNull);
        final label =
            ListingData.listedRelativeChipLabel(item, now: fixedNow);
        expect(label, isNotEmpty);
        dist[label] = (dist[label] ?? 0) + 1;
      }
      expect(dist.keys, hasLength(6));
      expect(items.length, 53);
      expect(SampleListingsDublin.items.length, 90);
    });

    test('MarketListingsSeed exposes published_at on all rows', () {
      final items = MarketListingsSeed.items;
      final missing = items
          .where(
            (e) => ListingData.text(e[ListingData.publishedAtKey]).isEmpty,
          )
          .length;
      expect(missing, 0);
      expect(items.length, greaterThan(0));
    });
  });
}
