import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/nominatim_forward.dart';
import 'package:true_circle/utils/dublin_location_search_suggestions.dart';
import 'package:true_circle/utils/nominatim_label_sanitizer.dart';

void main() {
  group('NominatimLabelSanitizer locality-first', () {
    test('Newcastle village is preferred over empty suburb fields', () {
      final structured = NominatimLabelSanitizer.structuredFromAddress({
        'village': 'Newcastle',
        'municipality': 'South Dublin',
        'county': 'County Dublin',
        'postcode': 'D22 XV65',
      });

      expect(structured.area, 'Newcastle');
      expect(structured.displayLabel, contains('Newcastle'));
      expect(structured.displayLabel.toLowerCase(), isNot(contains('ded')));
      expect(structured.county, 'Co. Dublin');
    });

    test('DED / 1986 city_district is cleaned; village remains locality', () {
      final structured = NominatimLabelSanitizer.structuredFromAddress({
        'city_district': 'Newcastle DED 1986',
        'village': 'Newcastle',
        'county': 'County Dublin',
      });

      expect(structured.area, 'Newcastle');
      expect(structured.displayLabel.toLowerCase(), isNot(contains('ded')));
      expect(structured.displayLabel, isNot(contains('1986')));
      expect(
        NominatimLabelSanitizer.isNoisyAdminPart('Newcastle DED 1986'),
        isTrue,
      );
    });

    test('suburb / village / town / hamlet priority order', () {
      expect(
        NominatimLabelSanitizer.resolveLocality({
          'suburb': 'Adamstown',
          'village': 'Newcastle',
          'town': 'Lucan',
          'hamlet': 'X',
        }),
        'Adamstown',
      );
      expect(
        NominatimLabelSanitizer.resolveLocality({
          'village': 'Rathcoole',
          'town': 'Lucan',
        }),
        'Rathcoole',
      );
      expect(
        NominatimLabelSanitizer.resolveLocality({
          'town': 'Skerries',
          'hamlet': 'X',
        }),
        'Skerries',
      );
      expect(
        NominatimLabelSanitizer.resolveLocality({'hamlet': 'X'}),
        'X',
      );
    });

    test('coastal and west Dublin localities stay human-friendly', () {
      for (final place in [
        'Rathcoole',
        'Newcastle',
        'Rush',
        'Lusk',
        'Skerries',
      ]) {
        final structured = NominatimLabelSanitizer.structuredFromAddress({
          'village': place,
          'county': 'County Dublin',
        });
        expect(structured.area, place);
        expect(structured.displayLabel, contains(place));
        expect(structured.county, 'Co. Dublin');
      }
    });

    test('suppresses electoral / ward / ED noise from cleaned parts', () {
      expect(NominatimLabelSanitizer.cleanPart('Newcastle DED 1986'), 'Newcastle');
      expect(NominatimLabelSanitizer.cleanPart('Clonsilla ED 1986'), 'Clonsilla');
      expect(
        NominatimLabelSanitizer.cleanPart('Somewhere Electoral Division'),
        'Somewhere',
      );
      expect(NominatimLabelSanitizer.cleanPart('The Ward'), '');
      expect(NominatimLabelSanitizer.cleanPart('1986'), '');
    });
  });

  group('location suggestions use locality-first titles', () {
    NominatimAddressResult fromAddress(
      Map<String, String?> fields, {
      String? name,
      double lat = 53.3,
      double lon = -6.5,
    }) {
      final structured = NominatimLabelSanitizer.structuredFromAddress(
        fields,
        nameFallback: name,
      );
      return NominatimAddressResult(
        displayLabel: structured.displayLabel,
        lat: lat,
        lon: lon,
        streetLine: structured.streetLine,
        area: structured.area,
        county: structured.county,
      );
    }

    test('Newcastle / Rathcoole suggestions are not County Dublin-only', () {
      final ranked = rankLocationSearchSuggestions(
        'newcastle',
        const [],
        [
          fromAddress({
            'village': 'Newcastle',
            'county': 'County Dublin',
            'postcode': 'D22 XV65',
          }),
          fromAddress({
            'city_district': 'Newcastle DED 1986',
            'village': 'Rathcoole',
            'county': 'County Dublin',
          }),
        ],
      );

      expect(ranked, hasLength(2));
      expect(ranked.map((r) => r.primaryTitle), containsAll(['Newcastle', 'Rathcoole']));
      for (final row in ranked) {
        expect(row.primaryTitle.toLowerCase(), isNot(contains('county')));
        expect(row.primaryTitle.toLowerCase(), isNot(contains('ded')));
        expect(row.secondaryTitle, 'Co. Dublin');
        expect(row.secondaryTitle.toLowerCase(), isNot(contains('ded')));
        expect(row.secondaryTitle, isNot(contains('1986')));
      }
    });

    test('Rush, Lusk, Skerries keep locality primary titles', () {
      final ranked = rankLocationSearchSuggestions(
        'rush',
        const [],
        [
          for (final place in ['Rush', 'Lusk', 'Skerries'])
            fromAddress({
              'town': place,
              'county': 'County Dublin',
            }),
        ],
      );

      expect(
        ranked.map((r) => r.primaryTitle).toSet(),
        containsAll(['Rush', 'Lusk', 'Skerries']),
      );
      expect(
        ranked.every((r) => r.secondaryTitle == 'Co. Dublin'),
        isTrue,
      );
    });
  });
}
