import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const listingsStorageKey = 'circlekey_listings';

Future<void> saveListings(List<Map<String, dynamic>> listings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(listingsStorageKey, jsonEncode(listings));
}

Future<List<Map<String, dynamic>>> loadListings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(listingsStorageKey);
    return _decodeListings(raw);
  } catch (_) {
    return [];
  }
}

Future<int> loadSeedVersion(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  } catch (_) {
    return 0;
  }
}

Future<void> saveSeedVersion(String key, int version) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, version);
}

List<Map<String, dynamic>> _decodeListings(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ))
      .toList();
}
