import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/config/market/dublin_districts.dart';

void main() {
  test('dublinDistricts contains 24 postal areas', () {
    expect(dublinDistricts, hasLength(24));
  });

  test('dublinAreaOptions keys are unique and match districts', () {
    final keys = dublinAreaOptions.map((e) => e.$1).toList();
    expect(keys.toSet(), hasLength(keys.length));
    expect(dublinAreaOptions.first.$2, 'Dublin 1 (City Centre North)');
    expect(dublinDistrictKey('Dublin 6W (Terenure)'), 'dublin6w');
    expect(dublinDistrictKey('Co. Dublin (North - Malahide, Swords, Skerries)'),
        'co_dublin_north');
  });

  test('legacy cherrywood alias maps to Dublin 18', () {
    expect(dublinCityAliases['dublin18'], contains('cherrywood'));
  });
}
