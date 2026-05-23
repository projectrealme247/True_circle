import 'dart:convert';

import 'package:web/web.dart' as web;

const listingsStorageKey = 'circlekey_listings';

Future<void> saveListings(List<Map<String, dynamic>> listings) async {
  web.window.localStorage.setItem(listingsStorageKey, jsonEncode(listings));
}

Future<List<Map<String, dynamic>>> loadListings() async {
  try {
    final raw = web.window.localStorage.getItem(listingsStorageKey);
    return _decodeListings(raw);
  } catch (_) {
    return [];
  }
}

Future<int> loadSeedVersion(String key) async {
  try {
    final raw = web.window.localStorage.getItem(key);
    return raw != null ? (int.tryParse(raw) ?? 0) : 0;
  } catch (_) {
    return 0;
  }
}

Future<void> saveSeedVersion(String key, int version) async {
  web.window.localStorage.setItem(key, version.toString());
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
