import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:true_circle/config/market/dublin_commuter_hubs.dart';
import 'package:true_circle/models/dublin_destination_suggestion.dart';
import 'package:true_circle/services/commute_destination_geocoding_service.dart';
import 'package:true_circle/services/seeker_destination_nominatim_service.dart';
import 'package:true_circle/utils/nominatim_label_sanitizer.dart';

void main() {
  group('CommuteDestinationGeocodingService', () {
    test('resolveCustomDestination maps geocoded point to custom hub', () async {
      final hub = await CommuteDestinationGeocodingService.resolveCustomDestination(
        'Smithfield',
        geocodeForTests: (_) async => [
          Location(
            latitude: 53.3475,
            longitude: -6.2782,
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(hub, isNotNull);
      expect(hub!.label, 'Smithfield');
      expect(hub.latitude, closeTo(53.3475, 0.0001));
      expect(hub.longitude, closeTo(-6.2782, 0.0001));
      expect(DublinCommuterHubs.isCustomHub(hub), isTrue);
    });

    test('hubFromSuggestion persists coordinate payload fields', () {
      final hub = SeekerDestinationNominatimService.hubFromSuggestion(
        const DublinDestinationSuggestion(
          displayLabel: 'Grand Canal Dock',
          latitude: 53.3419,
          longitude: -6.2373,
        ),
      );

      final fields = DublinCommuterHubs.persistFields(hub);
      expect(fields['destination_latitude'], closeTo(53.3419, 0.0001));
      expect(fields['destination_longitude'], closeTo(-6.2373, 0.0001));
      expect(fields['commute_destination'], 'Grand Canal Dock');
    });
  });

  group('NominatimLabelSanitizer', () {
    test('strips D ED and electoral division suffixes', () {
      const raw =
          'Alfie Byrne Road, Fairview, Clontarf West D ED, Dublin, Ireland';
      final cleaned = NominatimLabelSanitizer.formatSuggestionLabel(raw);
      expect(cleaned.toLowerCase(), isNot(contains('d ed')));
      expect(cleaned.toLowerCase(), isNot(contains('electoral')));
      expect(cleaned, 'East Point Business Park, Clontarf');
    });

    test('strips DED and FED administrative noise', () {
      const raw =
          'Main Street, Smithfield ED 1986, Smithfield DED, Dublin 7, D07';
      final cleaned = NominatimLabelSanitizer.cleanDisplayString(raw);
      expect(cleaned.toLowerCase(), isNot(contains('ded')));
      expect(cleaned.toLowerCase(), isNot(contains('ed 1986')));
      expect(cleaned, contains('Main Street'));
      expect(cleaned, contains('Smithfield'));
    });
  });
}
