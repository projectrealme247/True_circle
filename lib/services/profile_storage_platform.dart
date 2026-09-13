import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/json_safe.dart';

/// Mobile/desktop persistence (SharedPreferences).
const profileStorageKey = 'circlekey_user_profile';

Future<void> saveProfile(Map<String, dynamic> profile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    profileStorageKey,
    jsonEncode(JsonSafe.encodeMap(profile)),
  );
}

Future<void> saveNamedProfile(String key, Map<String, dynamic> profile) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, jsonEncode(JsonSafe.encodeMap(profile)));
}

Future<Map<String, dynamic>?> loadProfile() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(profileStorageKey);
    return _decodeProfile(raw);
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> loadNamedProfile(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return _decodeProfile(prefs.getString(key));
  } catch (_) {
    return null;
  }
}

Future<void> clearProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(profileStorageKey);
}

Map<String, dynamic>? _decodeProfile(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  return Map<String, dynamic>.from(
    decoded.map((key, value) => MapEntry(key.toString(), value)),
  );
}
