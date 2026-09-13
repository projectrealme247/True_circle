import 'profile_storage_platform.dart'
    if (dart.library.html) 'profile_storage_platform_web.dart' as platform;

/// Persists signup profile data (localStorage on web, SharedPreferences elsewhere).
abstract final class ProfileStorageService {
  static const storageKey = 'circlekey_user_profile';

  static Future<void> save(Map<String, dynamic> profile) =>
      platform.saveProfile(profile);

  static Future<void> saveSlot(String slotKey, Map<String, dynamic> profile) =>
      platform.saveNamedProfile(slotKey, profile);

  static Future<Map<String, dynamic>?> load() => platform.loadProfile();

  static Future<Map<String, dynamic>?> loadSlot(String slotKey) =>
      platform.loadNamedProfile(slotKey);

  static Future<void> clear() => platform.clearProfile();
}
