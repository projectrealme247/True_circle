import 'package:flutter/foundation.dart';

import 'user_session_store.dart';
import '../utils/profile_data.dart';

/// Canonical in-memory profile session for completion % and missing-field UI.
///
/// [session] mirrors the persisted auth payload. [editingSession] is the live
/// draft while [ProfileEditScreen] is open.
final profileStateNotifier = ProfileStateNotifier();

final class ProfileStateNotifier extends ChangeNotifier {
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _editingSession;

  /// Persisted profile row — same memory lane as [UserSessionStore.current].
  Map<String, dynamic>? get session {
    _syncFromAuthScreen();
    return _session;
  }

  /// Live edit draft; null when not on profile edit.
  Map<String, dynamic>? get editingSession => _editingSession;

  int get completionPercent =>
      ProfileData.calculateProfileCompletionPercentage(session);

  List<String> get missingFields =>
      ProfileData.missingFieldsForCompletion(session);

  int editingCompletionPercent(Map<String, dynamic>? fallbackDraft) =>
      ProfileData.calculateProfileCompletionPercentage(
        _editingSession ?? fallbackDraft ?? session,
      );

  List<String> editingMissingFields(Map<String, dynamic>? fallbackDraft) =>
      ProfileData.missingFieldsForCompletion(
        _editingSession ?? fallbackDraft ?? session,
      );

  void beginEditing(Map<String, dynamic>? baseline, {bool notify = true}) {
    _editingSession = baseline == null
        ? null
        : Map<String, dynamic>.from(baseline);
    if (notify) notifyListeners();
  }

  void updateEditingSession(Map<String, dynamic> draft, {bool notify = true}) {
    _editingSession = Map<String, dynamic>.from(draft);
    if (notify) notifyListeners();
  }

  void endEditing() {
    _editingSession = null;
    notifyListeners();
  }

  /// Drops cached session and re-reads [UserSessionStore.current].
  void invalidateCache() {
    _session = null;
    _syncFromAuthScreen();
    notifyListeners();
  }

  /// Explicit global invalidation broadcast for cross-route UI refresh.
  void broadcast() => notifyListeners();

  void commitPersisted(Map<String, dynamic> synced) {
    _session = Map<String, dynamic>.from(synced);
    _editingSession = null;
    notifyListeners();
  }

  void clear() {
    _session = null;
    _editingSession = null;
    notifyListeners();
  }

  void _syncFromAuthScreen() {
    final global = UserSessionStore.current;
    if (global == null) {
      _session = null;
      return;
    }
    _session = Map<String, dynamic>.from(global);
  }
}
