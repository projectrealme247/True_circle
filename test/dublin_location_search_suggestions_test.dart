import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/nominatim_forward.dart';
import 'package:true_circle/utils/dublin_location_search_suggestions.dart';

void main() {
  group('searchLocalDublinAreaSuggestions', () {
    test('talla matches Tallaght with place-first presentation', () {
      final results = searchLocalDublinAreaSuggestions('talla');
      expect(results, isNotEmpty);
      expect(results.first.primaryTitle, 'Tallaght');
      expect(results.first.secondaryTitle, 'Dublin 24');
    });

    test('blanch matches Blanchardstown', () {
      final results = searchLocalDublinAreaSuggestions('blanch');
      expect(results, isNotEmpty);
      expect(
        results.any((r) => r.primaryTitle == 'Blanchardstown'),
        isTrue,
      );
    });

    test('sword matches Swords via Co. Dublin North', () {
      final results = searchLocalDublinAreaSuggestions('sword');
      expect(results, isNotEmpty);
      expect(results.any((r) => r.primaryTitle == 'Swords'), isTrue);
    });

    test('query shorter than 3 chars returns empty', () {
      expect(searchLocalDublinAreaSuggestions('ta'), isEmpty);
    });
  });

  group('rankLocationSearchSuggestions', () {
    test('drum ranks Drumcondra and Dundrum before generic Nominatim', () {
      final local = searchLocalDublinAreaSuggestions('drum');
      final ranked = rankLocationSearchSuggestions(
        'drum',
        local,
        const [
          NominatimAddressResult(
            displayLabel: 'Gun and Drum Hill, Cherrywood, Dublin',
            lat: 53.27,
            lon: -6.14,
            streetLine: 'Gun and Drum Hill',
            area: 'Cherrywood',
            county: 'Dublin',
          ),
        ],
      );

      expect(ranked.length, greaterThanOrEqualTo(2));
      expect(ranked.first.primaryTitle, 'Drumcondra');
      expect(ranked.first.secondaryTitle, 'Dublin 9');

      final titles = ranked.map((r) => r.primaryTitle).toList();
      expect(titles, contains('Dundrum'));
      expect(titles.indexOf('Drumcondra'), lessThan(titles.indexOf('Dundrum')));

      final nominatimIndex = titles.indexOf('Cherrywood');
      if (nominatimIndex >= 0) {
        expect(nominatimIndex, greaterThan(titles.indexOf('Drumcondra')));
        expect(nominatimIndex, greaterThan(titles.indexOf('Dundrum')));
      }
    });

    test('local suggestions outscore distant Nominatim contains matches', () {
      final local = searchLocalDublinAreaSuggestions('talla');
      final ranked = rankLocationSearchSuggestions(
        'talla',
        local,
        const [
          NominatimAddressResult(
            displayLabel: 'Tallaght Road, Cork',
            lat: 51.89,
            lon: -8.47,
            streetLine: 'Tallaght Road',
            area: 'Cork',
            county: 'Cork',
          ),
        ],
      );

      expect(ranked.first.primaryTitle, 'Tallaght');
      expect(ranked.first.tier, LocationSuggestionTier.localAlias);
    });
  });
}
