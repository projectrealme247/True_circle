import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/overpass_config.dart';
import 'package:true_circle/services/overpass_full_query.dart';

void main() {
  test('request timeout exceeds query timeout by safety buffer', () {
    for (final type in OverpassQueryType.values) {
      final querySeconds = OverpassConfig.queryTimeoutSeconds(type);
      final requestSeconds = OverpassConfig.requestTimeoutFor(type).inSeconds;
      expect(
        requestSeconds,
        querySeconds + OverpassConfig.safetyBuffer.inSeconds,
      );
      expect(
        OverpassConfig.requestTimeoutFor(type),
        greaterThan(Duration(seconds: querySeconds)),
      );
    }
  });

  test('query headers use centralized timeout seconds', () {
    expect(
      buildFullOverpassQuery('53.424890', '-6.372960'),
      startsWith(
        '[out:json][timeout:${OverpassConfig.fullQueryTimeoutSeconds}]',
      ),
    );
    expect(
      buildEssentialsOverpassQuery('53.424890', '-6.372960'),
      startsWith(
        '[out:json][timeout:${OverpassConfig.essentialsQueryTimeoutSeconds}]',
      ),
    );
  });

  test('Hollywoodrath full request allows 23s before client abort', () {
    expect(OverpassConfig.queryTimeoutSeconds(OverpassQueryType.full), 18);
    expect(
      OverpassConfig.requestTimeoutFor(OverpassQueryType.full).inSeconds,
      23,
    );
  });
}
