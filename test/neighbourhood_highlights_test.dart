import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/neighbourhood_highlights.dart';

void main() {
  group('NeighbourhoodHighlights v2 detail', () {
    test('surfaces full persisted snapshot with multiple groceries', () {
      final listing = {
        'neighborhood_proximity': {
          'transport_line': 'Dublin Bus · The Oaks',
          'transport_walk_min': 3,
          'grocery_brand': 'Spar',
          'grocery_walk_min': 6,
          'groceries': [
            {'brand': 'Spar', 'walk_min': 6},
            {'brand': 'Tesco', 'walk_min': 10},
            {'brand': 'SuperValu', 'walk_min': 11},
          ],
          'primary_school': 'Tyrrelstown Educate Together National School',
          'primary_school_walk_min': 8,
          'secondary_school': 'Le Chéile Secondary School',
          'college_school': 'TU Dublin Blanchardstown',
          'college_walk_min': 12,
          'gp_clinic': 'Limitless Health',
          'gp_walk_min': 7,
          'lifestyle_tags': [
            {
              'category': 'cafe',
              'name': '5 To Go',
              'distance_km': 0.4,
              'emoji': '☕',
            },
            {
              'category': 'pizzaShops',
              'name': "Domino's",
              'distance_km': 0.5,
              'emoji': '🍕',
            },
          ],
          'custom_points': [
            {
              'category': 'amenity',
              'name': 'Corduff Primary Care Centre',
              'walk_min': 11,
            },
          ],
        },
      };

      final detail = NeighbourhoodHighlights.forDetail(listing);
      expect(
        detail.map((h) => h.chipLabel).toList(),
        containsAll([
          '🏫 Tyrrelstown Educate Together National School',
          '🏫 Le Chéile Secondary School',
          '🎓 TU Dublin Blanchardstown',
          '🛒 Spar',
          '🛒 Tesco',
          '🛒 SuperValu',
          '🚌 Dublin Bus · The Oaks',
          '🏥 Limitless Health',
          '🏥 Corduff Primary Care Centre',
          '☕ 5 To Go',
          "🍕 Domino's",
        ]),
      );

      // Priority: schools before grocery before transport before healthcare.
      expect(detail.first.categoryLabel, 'Primary School');
      expect(
        detail.indexWhere((h) => h.categoryLabel == 'Grocery'),
        lessThan(detail.indexWhere((h) => h.categoryLabel == 'Healthcare')),
      );

      final grouped = NeighbourhoodHighlights.groupedForDetail(listing);
      expect(grouped.map((s) => s.title).toList(), [
        'Education',
        'Groceries',
        'Transport',
        'Healthcare',
        'Lifestyle',
      ]);
      expect(grouped.first.items, hasLength(3));
      expect(grouped[1].items.map((i) => i.placeName), [
        'Spar',
        'Tesco',
        'SuperValu',
      ]);
    });

    test('does not fabricate grocery or generic transport labels', () {
      final listing = {
        'neighborhood_proximity': {
          'transport_line': 'Dublin Bus · Stop',
          'transport_walk_min': 2,
          'grocery_walk_min': 4,
        },
      };

      expect(NeighbourhoodHighlights.forDetail(listing), isEmpty);
    });

    test('returns empty when proximity data is missing', () {
      expect(NeighbourhoodHighlights.forDetail({'title': 'Flat'}), isEmpty);
    });

    test('maps college custom points', () {
      final listing = {
        'neighborhood_proximity': {
          'custom_points': [
            {
              'category': 'school',
              'name': 'Trinity College Dublin',
              'walk_min': 15,
            },
          ],
        },
      };
      final highlights = NeighbourhoodHighlights.forDetail(listing);
      expect(highlights.single.chipLabel, '🎓 Trinity College Dublin');
    });
  });
}
