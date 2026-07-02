import 'dart:convert';
import 'dart:io';

Future<({double lat, double lon})?> fetchIpCoordinates() async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('https://ipapi.co/json/'))
        .timeout(const Duration(seconds: 2));
    request.headers.set('Accept', 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final lat = decoded['latitude'];
    final lon = decoded['longitude'];
    if (lat is! num || lon is! num) return null;
    return (lat: lat.toDouble(), lon: lon.toDouble());
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
