import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const pins = {
  'hollywoodrath': (53.42489, -6.37296),
  'tallaght': (53.2885, -6.3575),
};

double hav(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dP = (lat2 - lat1) * math.pi / 180, dL = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dP/2)*math.sin(dP/2) + math.cos(p1)*math.cos(p2)*math.sin(dL/2)*math.sin(dL/2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
}

Future<Map?> fetchOverpass(double lat, double lon) async {
  final latS = lat.toStringAsFixed(6);
  final lonS = lon.toStringAsFixed(6);
  final query = '''
[out:json][timeout:18];
(
  node["shop"~"supermarket|convenience"](around:1200,,);
  node["amenity"="school"](around:1800,,);
  node["railway"~"tram_stop|station|halt"](around:2800,,);
  node["highway"="bus_stop"](around:2200,,);
  node["amenity"~"pub|bar"](around:1200,,);
  node["amenity"="pharmacy"](around:1000,,);
);
out center;
''';
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('https://overpass.kumi.systems/api/interpreter'));
    req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    req.write('data=');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return jsonDecode(body) as Map;
  } finally { client.close(force: true); }
}

void main() async {
  final groceries = [
    ('Tesco Blanch', 53.3915, -6.3938),
    ('Sacred Heart Hollystown', 53.3948, -6.4012),
    ('Tesco Tallaght', 53.2885, -6.3575),
    ('Blanch Bus', 53.3920, -6.3915),
  ];
  for (final e in pins.entries) {
    print('===   ===');
    for (final g in groceries) {
      final d = hav(e.value., e.value., g., g.);
      print('  :  km');
    }
    final data = await fetchOverpass(e.value., e.value.);
    final els = (data?['elements'] as List?) ?? [];
    print('  Overpass raw elements: ');
  }
}
