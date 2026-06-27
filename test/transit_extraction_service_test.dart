import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/transit_extraction_service.dart';

void main() {
  group('TransitExtractionService', () {
    test('tags Luas Green Line when within walking threshold', () {
      final proximity = TransitExtractionService.extractLocally(
        latitude: 53.3380,
        longitude: -6.2600,
      );

      expect(proximity, isNotNull);
      expect(proximity!['transit_type'], 'Luas Green Line');
      expect(proximity['walk_minutes'], isA<int>());
      expect((proximity['walk_minutes'] as int) > 0, isTrue);
      expect(proximity['nearest_stop_name'], isNotEmpty);
    });

    test('returns null when no rapid transit is within strict walk envelope', () {
      final proximity = TransitExtractionService.extractLocally(
        latitude: 53.10,
        longitude: -6.50,
      );

      expect(proximity, isNull);
    });

    test('proximity payload uses walk_minutes not kilometres', () {
      final proximity = TransitExtractionService.extractLocally(
        latitude: 53.3415,
        longitude: -6.2380,
      );

      expect(proximity, isNotNull);
      expect(proximity!.containsKey('walk_minutes'), isTrue);
      expect(proximity.containsKey('distance_km'), isFalse);
    });
  });
}
