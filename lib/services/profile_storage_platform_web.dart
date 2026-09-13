import 'dart:convert';

import 'package:web/web.dart' as web;

import '../utils/json_safe.dart';

/// Web persistence via browser localStorage.
const profileStorageKey = 'circlekey_user_profile';

Future<void> saveProfile(Map<String, dynamic> profile) async {
  web.window.localStorage.setItem(
    profileStorageKey,
    jsonEncode(JsonSafe.encodeMap(profile)),
  );
}

Future<void> saveNamedProfile(String key, Map<String, dynamic> profile) async {
  web.window.localStorage.setItem(
    key,
    jsonEncode(JsonSafe.encodeMap(profile)),
  );
}

Future<Map<String, dynamic>?> loadProfile() async {
  try {
    final raw = web.window.localStorage.getItem(profileStorageKey);
    return _decodeProfile(raw);
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> loadNamedProfile(String key) async {
  try {
    return _decodeProfile(web.window.localStorage.getItem(key));
  } catch (_) {
    return null;
  }
}

Future<void> clearProfile() async {
  web.window.localStorage.removeItem(profileStorageKey);
}

Map<String, dynamic>? _decodeProfile(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return null;
  return Map<String, dynamic>.from(
    decoded.map((key, value) => MapEntry(key.toString(), value)),
  );
}
