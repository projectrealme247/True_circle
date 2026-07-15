import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/neighborhood_amenities_service.dart';
import 'package:true_circle/services/structured_amenities_fallback_service.dart';

/// Sanity check that local-only proximity paths stay sub-300ms (Fix 1 baseline).
void main() {
  test('local catalog + structured fallback resolve under 300ms', () async {
    const lat = 53.3498;
    const lon = -6.2603;

    final sw = Stopwatch()..start();
    final catalog = await NeighborhoodAmenitiesService.resolve(
      latitude: lat,
      longitude: lon,
    );
    final structured = StructuredAmenitiesFallbackService.resolve(
      latitude: lat,
      longitude: lon,
    );
    sw.stop();

    expect(catalog, isNotEmpty);
    expect(structured, isNotNull);
    expect(
      sw.elapsedMilliseconds,
      lessThan(300),
      reason: 'Phase-1 local data should render near-instantly',
    );
    print('Local proximity phase-1: ${sw.elapsedMilliseconds}ms');
  });
}
