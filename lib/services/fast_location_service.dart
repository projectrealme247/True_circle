import 'dart:async';

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
  /// Bound for cold GPS when no fresh last-known is available.
  static const userActionGpsTimeout = Duration(seconds: 8);
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

  /// Accurate GPS for explicit user actions — prefer fresh last-known for
  /// instant pin/POI, then upgrade with a bounded GPS fix (no IP fallback).
  ///
  /// Web: skips [Geolocator.getLastKnownPosition] (unsupported → UnsupportedError)
  /// and goes straight to [Geolocator.getCurrentPosition].
  static Future<
      ({
        double latitude,
        double longitude,
        FastLocationSource source,
      })?> resolveForUserAction() async {
    // TEMP DEBUG
    void gpsLog(String phase, [Map<String, Object?> data = const {}]) {
      if (!kDebugMode) return;
      debugPrint('[GPS] $phase $data');
    }

    Position? lastKnown;
    if (!kIsWeb) {
      gpsLog('last_known_start');
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
        gpsLog('last_known_end', {
          'ok': lastKnown != null,
          'lat': lastKnown?.latitude,
          'lon': lastKnown?.longitude,
          'timestamp': lastKnown?.timestamp.toIso8601String(),
          'ageMs': lastKnown == null
              ? null
              : DateTime.now().difference(lastKnown.timestamp).inMilliseconds,
          'withinMaxAge': lastKnown == null
              ? null
              : DateTime.now().difference(lastKnown.timestamp) <=
                  _lastKnownMaxAge,
        });
      } catch (e, st) {
        // Unsupported / platform errors → treat as no cached location.
        gpsLog('exception', {
          'phase': 'last_known',
          'error': e.toString(),
          'type': e.runtimeType.toString(),
          'stack': st.toString(),
          'treatedAs': 'no_cached_location',
        });
        lastKnown = null;
      }
    } else {
      gpsLog('last_known_skipped', {'reason': 'unsupported_on_web'});
    }

    if (lastKnown != null) {
      final age = DateTime.now().difference(lastKnown.timestamp);
      if (age <= _lastKnownMaxAge) {
        // Kick GPS in background to refresh cache for the next action.
        unawaited(_refreshGpsCache());
        await _writeCache(lastKnown.latitude, lastKnown.longitude);
        return (
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
          source: FastLocationSource.lastKnown,
        );
      }
    }

    Position? gps;
    gpsLog('current_location_start', {
      'timeoutSec': userActionGpsTimeout.inSeconds,
      'isWeb': kIsWeb,
    });
    final sw = Stopwatch()..start();
    try {
      gps = await Geolocator.getCurrentPosition(
        locationSettings: _userActionLocationSettings,
      ).timeout(userActionGpsTimeout);
      sw.stop();
      gpsLog('current_location_end', {
        'ok': true,
        'ms': sw.elapsedMilliseconds,
        'lat': gps.latitude,
        'lon': gps.longitude,
      });
    } catch (e, st) {
      sw.stop();
      final isTimeout = e is TimeoutException;
      gpsLog(isTimeout ? 'timeout' : 'exception', {
        'phase': 'current_location',
        'ms': sw.elapsedMilliseconds,
        'timeoutSec': userActionGpsTimeout.inSeconds,
        'error': e.toString(),
        'type': e.runtimeType.toString(),
        'stack': st.toString(),
      });
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

    gpsLog('current_location_end', {'ok': false, 'returning': 'null'});
    return null;
  }

  static Future<void> _refreshGpsCache() async {
    try {
      final gps = await Geolocator.getCurrentPosition(
        locationSettings: _userActionLocationSettings,
      ).timeout(userActionGpsTimeout);
      await _writeCache(gps.latitude, gps.longitude);
    } catch (_) {}
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
