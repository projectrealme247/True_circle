import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/listing_creation_form_models.dart';
import 'package:true_circle/utils/listing_smart_copy_generator.dart';

void main() {
  group('ListingSmartCopyGenerator', () {
    test('generates shared living title and description', () {
      final result = ListingSmartCopyGenerator.generate(
        const ListingSmartCopyInput(
          isSharedLiving: true,
          areaName: 'Rathmines',
          postalDistrict: 'Dublin 8',
          propertyType: 'Apartment',
          isFurnished: true,
          bedrooms: 3,
          bathrooms: 2,
          monthlyRent: 950,
          closestTransit: 'Luas Red Cow',
          transitWalkTime: '8 min',
          closestShop: 'Tesco',
          shopWalkTime: '6 min',
          roomArchitecture: SharedRoomArchitecture.privateEnsuite,
        ),
      );

      expect(
        result.title,
        'Bright Ensuite Room in Apartment | Rathmines, Dublin 8',
      );
      expect(result.description, contains('## The Space'));
      expect(result.description, contains('## The Location & Commute'));
      expect(result.description, contains('Getting around is incredibly easy.'));
      expect(result.description, contains('day-to-day essentials'));
      expect(result.description, contains('## House Guidelines & Vibe'));
      expect(result.description, contains('€950/month'));
    });

    test('generates full rental title and description', () {
      final result = ListingSmartCopyGenerator.generate(
        const ListingSmartCopyInput(
          isSharedLiving: false,
          areaName: 'Castleknock',
          postalDistrict: 'Dublin 15',
          propertyType: 'House',
          isFurnished: true,
          bedrooms: 2,
          bathrooms: 1,
          monthlyRent: 2200,
          closestTransit: 'Bus 39A',
          transitWalkTime: '4 min',
          closestShop: 'Lidl',
          shopWalkTime: '7 min',
        ),
      );

      expect(
        result.title,
        'Bright & Modern 2-Bed House | Castleknock, Dublin 15',
      );
      expect(
        result.description,
        contains('comfortable, modern home of their own'),
      );
      expect(result.description, isNot(contains('House Guidelines')));
      expect(result.description, isNot(contains('retail utilities')));
    });

    test('skips generation when fields already populated', () {
      final result = ListingSmartCopyGenerator.generate(
        const ListingSmartCopyInput(
          isSharedLiving: false,
          areaName: 'Dublin',
          postalDistrict: 'Dublin 4',
          propertyType: 'Apartment',
          isFurnished: true,
          bedrooms: 1,
          bathrooms: 1,
          monthlyRent: 1500,
          closestTransit: 'Dart',
          transitWalkTime: '5 min',
          closestShop: 'Dunnes',
          shopWalkTime: '5 min',
          existingTitle: 'Custom title',
          existingDescription: 'Custom description',
        ),
      );

      expect(result.title, isNull);
      expect(result.description, isNull);
    });
  });
}
