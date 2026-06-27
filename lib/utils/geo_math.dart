import 'dart:math' as math;

/// Geographic coordinate pair for commute matrix calculations.
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Shared geodesic + mode-speed helpers for commute scoring.
abstract final class GeoMath {
  static const _earthRadiusKm = 6371.0;
  static const _walkingKmh = 5.0;
  static const _luasKmh = 25.0;
  static const _busKmh = 18.0;
  static const _drivingKmh = 28.0;

  static double haversineKm(LatLng a, LatLng b) {
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusKm * c;
  }

  static int walkingMinutes(double km) =>
      math.max(1, (km / _walkingKmh * 60).round());

  static int luasMinutes(double km) =>
      math.max(1, (km / _luasKmh * 60).round());

  static int busMinutes(double km) =>
      math.max(1, (km / _busKmh * 60).round());

  static int drivingMinutes(double km) =>
      math.max(1, (km / _drivingKmh * 60).round());

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}
