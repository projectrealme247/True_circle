import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:true_circle/controllers/listing_creation_controller.dart';
import 'package:true_circle/models/listing_creation_category.dart';
import 'package:true_circle/models/listing_creation_draft.dart';
import 'package:true_circle/models/listing_creation_field_keys.dart';
import 'package:true_circle/services/eircode_geocoding_service.dart';
import 'package:true_circle/services/listing_creation_payload_builder.dart';
import 'package:true_circle/services/listing_creation_validation_service.dart';

void main() {
  setUp(ListingCreationController.resetSubmissionStateForTests);
  group('EircodeGeocodingService', () {
    test('accepts valid Dublin Eircode formats', () {
      expect(EircodeGeocodingService.isValidFormat('D02 X285'), isTrue);
      expect(EircodeGeocodingService.isValidFormat('d02x285'), isTrue);
      expect(EircodeGeocodingService.normalize('d02x285'), 'D02 X285');
    });

    test('rejects malformed Eircode', () {
      expect(EircodeGeocodingService.isValidFormat('Dublin 4'), isFalse);
      expect(EircodeGeocodingService.isValidFormat('12345'), isFalse);
    });
  });

  group('ListingCreationDraft category reset', () {
    test('wipes independent fields when switching to shared living', () {
      const draft = ListingCreationDraft(
        category: ListingCreationCategory.independentPlaces,
        bedsCount: 2,
        rtbStatus: ListingRtbStatus.registered,
        parkingAvailable: true,
        latitude: 53.3,
        longitude: -6.2,
      );

      final next = draft.withCategory(ListingCreationCategory.sharedLiving);

      expect(next.category, ListingCreationCategory.sharedLiving);
      expect(next.bedsCount, isNull);
      expect(next.rtbStatus, isNull);
      expect(next.parkingAvailable, isNull);
      expect(next.latitude, isNull);
      expect(next.languagesSpoken, ['English']);
    });

    test('wipes shared fields when switching to independent places', () {
      const draft = ListingCreationDraft(
        category: ListingCreationCategory.sharedLiving,
        roomType: ListingShareRoomType.ensuite,
        householdDynamic: ListingHouseholdDynamic.professionals,
        kitchenCulture: ListingKitchenCulture.vegFriendly,
        languagesSpoken: ['English', 'Polish'],
      );

      final next = draft.withCategory(ListingCreationCategory.independentPlaces);

      expect(next.category, ListingCreationCategory.independentPlaces);
      expect(next.roomType, isNull);
      expect(next.householdDynamic, isNull);
      expect(next.kitchenCulture, isNull);
      expect(next.languagesSpoken, isEmpty);
    });
  });

  group('ListingCreationValidationService', () {
    test('requires independent place fields', () {
      const draft = ListingCreationDraft(
        title: 'Bright 2-bed',
        price: '2100/month',
        description: 'A lovely flat near the Luas.',
        eircode: 'D02 X285',
      );

      final errors = ListingCreationValidationService.validate(draft);
      expect(errors.containsKey(ListingCreationFieldKeys.bedsCount), isTrue);
      expect(errors.containsKey(ListingCreationFieldKeys.rtbStatus), isTrue);
      expect(
        errors.containsKey(ListingCreationFieldKeys.parkingAvailable),
        isTrue,
      );
    });

    test('defaults languages validation for shared living', () {
      const draft = ListingCreationDraft(
        category: ListingCreationCategory.sharedLiving,
        title: 'Ensuite in Dublin 6',
        price: '950/month',
        description: 'Quiet house with professionals.',
        eircode: 'D06 E9W4',
        roomType: ListingShareRoomType.ensuite,
        householdDynamic: ListingHouseholdDynamic.professionals,
        kitchenCulture: ListingKitchenCulture.open,
        languagesSpoken: ['English'],
      );

      expect(ListingCreationValidationService.validate(draft), isEmpty);
    });

    test('strips deprecated kitchen utility keys', () {
      final cleaned = ListingCreationValidationService.stripForbiddenKeys({
        'title': 'Test',
        'kitchen_usage_timing': 'Morning only',
        'kitchen_utility_preference': 'Shared',
      });

      expect(cleaned.containsKey('kitchen_usage_timing'), isFalse);
      expect(cleaned.containsKey('kitchen_utility_preference'), isFalse);
      expect(cleaned['title'], 'Test');
    });
  });

  group('ListingCreationPayloadBuilder', () {
    test('maps independent draft to PostGIS-ready row', () {
      const draft = ListingCreationDraft(
        category: ListingCreationCategory.independentPlaces,
        title: '1 bed · Dublin 4',
        price: '2100/month',
        description: 'Fully furnished apartment.',
        eircode: 'D04 V9K4',
        latitude: 53.333,
        longitude: -6.248,
        bedsCount: 1,
        rtbStatus: ListingRtbStatus.notProvided,
        parkingAvailable: false,
      );

      final local = ListingCreationPayloadBuilder.toLocalListingMap(draft);
      final row = ListingCreationPayloadBuilder.toSupabaseRow(
        local,
        userId: 'user-1',
      );

      expect(local['kitchen_usage_timing'], isNull);
      expect(row[ListingCreationFieldKeys.bedsCount], 1);
      expect(row[ListingCreationFieldKeys.locationGeom], isNotNull);
      final geom = row[ListingCreationFieldKeys.locationGeom] as Map;
      expect(geom['type'], 'Point');
      expect(geom['coordinates'], [-6.248, 53.333]);
    });

    test('maps shared draft with kitchen culture not utility timing', () {
      const draft = ListingCreationDraft(
        category: ListingCreationCategory.sharedLiving,
        title: 'Ensuite · Rialto',
        price: '850/month',
        description: 'Friendly household.',
        eircode: 'D08 NHY1',
        latitude: 53.32,
        longitude: -6.27,
        roomType: ListingShareRoomType.shared,
        householdDynamic: ListingHouseholdDynamic.students,
        kitchenCulture: ListingKitchenCulture.vegFriendly,
        languagesSpoken: ['English'],
      );

      final local = ListingCreationPayloadBuilder.toLocalListingMap(draft);

      expect(local[ListingCreationFieldKeys.kitchenCulture], 'veg_friendly');
      expect(local.containsKey('kitchen_usage_timing'), isFalse);
      expect(local['languages_spoken'], ['English']);
    });
  });

  group('ListingCreationController', () {
    test('onCategoryChanged delegates defensive reset', () {
      const draft = ListingCreationDraft(
        bedsCount: 3,
        parkingAvailable: true,
      );

      final next = ListingCreationController.onCategoryChanged(
        draft,
        ListingCreationCategory.sharedLiving,
      );

      expect(next.bedsCount, isNull);
      expect(next.languagesSpoken, ['English']);
    });

    test('resolveEircode updates coordinates from geocoder', () async {
      const draft = ListingCreationDraft(
        title: 'Test flat',
        price: '2000/month',
        description: 'Description long enough.',
        eircode: 'D02 X285',
      );

      final resolved = await ListingCreationController.resolveEircode(
        draft,
        geocodeForTests: (_) async => [
          Location(
            latitude: 53.342,
            longitude: -6.267,
            timestamp: DateTime.now(),
          ),
        ],
      );

      expect(resolved.latitude, 53.342);
      expect(resolved.longitude, -6.267);
    });
  });

  group('QA — ghost Eircode response', () {
    test('publish halts without Supabase insert when geocoder is empty', () async {
      var insertCalled = false;

      const draft = ListingCreationDraft(
        title: 'Bright flat',
        price: '2000/month',
        description: 'Description long enough for validation.',
        eircode: 'D02 X285',
        bedsCount: 2,
        rtbStatus: ListingRtbStatus.registered,
        parkingAvailable: true,
      );

      await expectLater(
        ListingCreationController.publish(
          draft,
          geocodeForTests: (_) async => <Location>[],
          insertOverride: (_) async {
            insertCalled = true;
            return {'id': 'should-not-run'};
          },
        ),
        throwsA(
          isA<ListingCreationTransactionException>().having(
            (e) => e.code,
            'code',
            ListingCreationErrorCode.eircode,
          ),
        ),
      );

      expect(insertCalled, isFalse);
    });
  });

  group('QA — state mutation pollution cleanse', () {
    test('shared draft toggled to independent omits shared fields from payload', () {
      const sharedDraft = ListingCreationDraft(
        category: ListingCreationCategory.sharedLiving,
        title: 'Ensuite in Dublin 6',
        price: '950/month',
        description: 'Quiet house with professionals.',
        eircode: 'D06 E9W4',
        latitude: 53.32,
        longitude: -6.27,
        roomType: ListingShareRoomType.ensuite,
        householdDynamic: ListingHouseholdDynamic.professionals,
        kitchenCulture: ListingKitchenCulture.vegFriendly,
        languagesSpoken: ['English', 'Polish'],
      );

      var draft = ListingCreationController.onCategoryChanged(
        sharedDraft,
        ListingCreationCategory.independentPlaces,
      );
      draft = draft.copyWith(
        bedsCount: 2,
        rtbStatus: ListingRtbStatus.notProvided,
        parkingAvailable: false,
        latitude: 53.32,
        longitude: -6.27,
      );

      expect(ListingCreationController.validate(draft), isEmpty);

      final local = ListingCreationController.buildLocalPayload(draft);

      expect(local[ListingCreationFieldKeys.roomType], isNull);
      expect(local['share_room_kind'], isNull);
      expect(local['room_type'], isNull);
      expect(local[ListingCreationFieldKeys.householdDynamic], isNull);
      expect(local[ListingCreationFieldKeys.kitchenCulture], isNull);
      expect(local['languages_spoken'], isNull);
      expect(local[ListingCreationFieldKeys.languagesSpoken], isNull);
      expect(local[ListingCreationFieldKeys.bedsCount], 2);
      expect(local[ListingCreationFieldKeys.rtbStatus], isNotNull);
      expect(local[ListingCreationFieldKeys.parkingAvailable], isFalse);

      final row = ListingCreationPayloadBuilder.toSupabaseRow(
        local,
        userId: 'user-qa',
      );

      expect(row[ListingCreationFieldKeys.roomType], isNull);
      expect(row[ListingCreationFieldKeys.householdDynamic], isNull);
      expect(row[ListingCreationFieldKeys.kitchenCulture], isNull);
      expect(row[ListingCreationFieldKeys.languagesSpoken], isNull);
      expect(row[ListingCreationFieldKeys.bedsCount], 2);
    });
  });

  group('QA — idempotency double-tap prevention', () {
    test('only one insert when publish is called twice concurrently', () async {
      var insertCount = 0;

      const draft = ListingCreationDraft(
        title: 'Bright flat',
        price: '2000/month',
        description: 'Description long enough for validation.',
        eircode: 'D02 X285',
        latitude: 53.342,
        longitude: -6.267,
        bedsCount: 2,
        rtbStatus: ListingRtbStatus.registered,
        parkingAvailable: true,
      );

      Future<Map<String, dynamic>> slowInsert(Map<String, dynamic> _) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        insertCount++;
        return {'id': 'listing-$insertCount'};
      }

      expect(ListingCreationController.isSubmitting, isFalse);

      final first = ListingCreationController.publish(
        draft,
        insertOverride: slowInsert,
      );

      expect(ListingCreationController.isSubmitting, isTrue);

      await expectLater(
        ListingCreationController.publish(
          draft,
          insertOverride: slowInsert,
        ),
        throwsA(
          isA<ListingCreationTransactionException>().having(
            (e) => e.code,
            'code',
            ListingCreationErrorCode.duplicateSubmission,
          ),
        ),
      );

      final result = await first;
      expect(result.listingId, 'listing-1');
      expect(insertCount, 1);
      expect(ListingCreationController.isSubmitting, isFalse);
    });
  });

  group('QA — language array sanitization', () {
    test('sanitizeLanguages trims, dedupes case-insensitively, and capitalizes', () {
      expect(
        ListingCreationValidationService.sanitizeLanguages([
          'English ',
          'english',
        ]),
        ['English'],
      );
      expect(
        ListingCreationValidationService.sanitizeLanguages([
          ' polish ',
          'Polish',
          'ENGLISH',
        ]),
        ['Polish', 'English'],
      );
    });

    test('payload builder applies language sanitization for shared living', () {
      const draft = ListingCreationDraft(
        category: ListingCreationCategory.sharedLiving,
        title: 'Ensuite · Rialto',
        price: '850/month',
        description: 'Friendly household.',
        eircode: 'D08 NHY1',
        latitude: 53.32,
        longitude: -6.27,
        roomType: ListingShareRoomType.shared,
        householdDynamic: ListingHouseholdDynamic.students,
        kitchenCulture: ListingKitchenCulture.open,
        languagesSpoken: ['English ', 'english'],
      );

      final local = ListingCreationPayloadBuilder.toLocalListingMap(draft);

      expect(local['languages_spoken'], ['English']);
      expect(local[ListingCreationFieldKeys.languagesSpoken], ['English']);
    });
  });
}
