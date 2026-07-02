import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fast_location_ip_lookup.dart';

enum FastLocationSource { gps, lastKnown, ip, cache }

/// Low-latency device location — coarse GPS, then IP, then cache.
abstract final class FastLocationService {
  static const _cacheLatKey = 'tc_fast_location_lat';
  static const _cacheLonKey = 'tc_fast_location_lon';
  static const gpsTimeout = Duration(milliseconds: 2500);
  static const userActionGpsTimeout = Duration(seconds: 12);
  static const _lastKnownMaxAge = Duration(minutes: 30);

  static Future<
      ({
        double latitude,
        double longitude,
        FastLocationSource source,
      })?> resolve() async {
    Position? gps;
    try {
      gps = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: gpsTimeout,
        ),
      ).timeout(gpsTimeout);
    } catch (_) {
      gps = null;
    }

    if (gps != null) {
      await _writeCache(gps.latitude, gps.longitude);
      return (
        latitude: gps.latitude,
        longitude: gps.longitude,
        source: FastLocationSource.gps,
      );
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      await _writeCache(lastKnown.latitude, lastKnown.longitude);
      return (
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
        source: FastLocationSource.lastKnown,
      );
    }

    final ip = await FastLocationIpLookup.coordinates();
    if (ip != null) {
      await _writeCache(ip.lat, ip.lon);
      return (
        latitude: ip.lat,
        longitude: ip.lon,
        source: FastLocationSource.ip,
      );
    }

    final cached = await _readCache();
    if (cached != null) return cached;

    return null;
  }

  /// Accurate GPS for explicit user actions — no IP or stale cache fallback.
  static Future<
      ({
        double latitude,
        double longitude,
        FastLocationSource source,
      })?> resolveForUserAction() async {
    Position? gps;
    try {
      gps = await Geolocator.getCurrentPosition(
        locationSettings: _userActionLocationSettings,
      ).timeout(userActionGpsTimeout);
    } catch (_) {
      gps = null;
    }

    if (gps != null) {
      await _writeCache(gps.latitude, gps.longitude);
      return (
        latitude: gps.latitude,
        longitude: gps.longitude,
        source: FastLocationSource.gps,
      );
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      final age = DateTime.now().difference(lastKnown.timestamp);
      if (age <= _lastKnownMaxAge) {
        await _writeCache(lastKnown.latitude, lastKnown.longitude);
        return (
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          source: FastLocationSource.lastKnown,
        );
      }
    }

    return null;
  }

  static LocationSettings get _userActionLocationSettings {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: userActionGpsTimeout,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: userActionGpsTimeout,
    );
  }

  static Future<
      ({
        double latitude,
        double longitude,
        FastLocationSource source,
      })?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_cacheLatKey);
      final lon = prefs.getDouble(_cacheLonKey);
      if (lat == null || lon == null) return null;
      return (
        latitude: lat,
        longitude: lon,
        source: FastLocationSource.cache,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cacheLatKey, lat);
      await prefs.setDouble(_cacheLonKey, lon);
    } catch (_) {}
  }
}
