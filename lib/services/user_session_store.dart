/// Global in-memory user profile session — no UI or auth service imports.
abstract final class UserSessionStore {
  static Map<String, dynamic>? current;
}
