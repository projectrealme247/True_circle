import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/listing_application.dart';
import '../models/marketplace_space.dart';
import '../models/applicant_application_status.dart';
import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';
import 'auth_service.dart';
import 'user_session_store.dart';

/// Local application store for seeker apply flows.
class ApplicationService {
  ApplicationService._();

  static final ApplicationService instance = ApplicationService._();

  static const _storageKey = 'circlekey_listing_applications';

  List<Map<String, dynamic>> _rows = const [];
  bool _loaded = false;
  final Map<String, Future<void>> _applyLocks = <String, Future<void>>{};

  /// Clears in-memory state between tests.
  @visibleForTesting
  void resetForTest() {
    _rows = const [];
    _loaded = false;
    _applyLocks.clear();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        _rows = [];
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _rows = [
            for (final item in decoded)
              if (item is Map) Map<String, dynamic>.from(item),
          ];
        } else {
          _rows = [];
        }
      }
    } catch (_) {
      _rows = [];
    }
    _loaded = true;
  }

  List<ListingApplication> getUserApplications(String userId) {
    if (userId.isEmpty) return const [];

    final apps = <ListingApplication>[
      for (final row in _rows)
        if (_rowUserId(row) == userId) ListingApplication.fromMap(row),
    ];
    apps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return apps;
  }

  bool hasApplied({required String listingId, required String userId}) {
    if (listingId.isEmpty || userId.isEmpty) return false;
    return _rows.any(
      (row) =>
          row['listing_id']?.toString() == listingId &&
          _rowUserId(row) == userId,
    );
  }

  List<Map<String, dynamic>> rowsForListing(String listingId) {
    if (listingId.isEmpty) return const [];
    return [
      for (final row in _rows)
        if (row['listing_id']?.toString() == listingId) row,
    ];
  }

  List<Map<String, dynamic>> allRows() => List.unmodifiable(_rows);

  Map<String, dynamic>? rowById(String applicationId) {
    if (applicationId.isEmpty) return null;
    for (final row in _rows) {
      if (row['id']?.toString() == applicationId) return row;
    }
    return null;
  }

  /// Existing application for a seeker on a listing, if any.
  Map<String, dynamic>? rowForListingUser({
    required String listingId,
    required String userId,
  }) {
    if (listingId.isEmpty || userId.isEmpty) return null;
    for (final row in _rows) {
      if (row['listing_id']?.toString() == listingId &&
          _rowUserId(row) == userId) {
        return row;
      }
    }
    return null;
  }

  /// Persists host lifecycle status for a local application row.
  Future<bool> updateApplicationStatus({
    required String applicationId,
    required ApplicantApplicationStatus nextStatus,
    Map<String, dynamic>? extras,
  }) async {
    if (applicationId.isEmpty) return false;
    await ensureLoaded();
    final index = _rows.indexWhere(
      (row) => row['id']?.toString() == applicationId,
    );
    if (index < 0) return false;

    final rows = List<Map<String, dynamic>>.from(_rows);
    rows[index] = {
      ...rows[index],
      if (extras != null) ...extras,
      'status': nextStatus.storageToken,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _saveAll(rows);
    return true;
  }

  /// Caches a remote `listing_applications` row locally (UUID id preserved).
  Future<Map<String, dynamic>> cacheRemoteRow(
    Map<String, dynamic> remoteRow,
  ) async {
    await ensureLoaded();
    final normalized = _normalizeRemoteRow(remoteRow);
    final id = normalized['id']?.toString() ?? '';
    final listingId = normalized['listing_id']?.toString() ?? '';
    final userId = _rowUserId(normalized);

    final rows = List<Map<String, dynamic>>.from(_rows);
    final index = rows.indexWhere((row) {
      if (id.isNotEmpty && row['id']?.toString() == id) return true;
      return listingId.isNotEmpty &&
          userId.isNotEmpty &&
          row['listing_id']?.toString() == listingId &&
          _rowUserId(row) == userId;
    });

    if (index >= 0) {
      rows[index] = normalized;
    } else {
      rows.add(normalized);
    }
    await _saveAll(rows);
    return Map<String, dynamic>.from(
      index >= 0 ? rows[index] : rows.last,
    );
  }

  /// Replaces this seeker's local rows with remote truth (UUID ids).
  /// Other users' cached rows are left in place.
  Future<List<Map<String, dynamic>>> replaceSeekerCacheWithRemote({
    required String userId,
    required List<Map<String, dynamic>> remoteRows,
  }) async {
    await ensureLoaded();
    if (userId.isEmpty) return const [];

    final normalized = [
      for (final row in remoteRows) _normalizeRemoteRow(row),
    ];
    final rows = [
      for (final row in _rows)
        if (_rowUserId(row) != userId) row,
      ...normalized,
    ];
    await _saveAll(rows);
    return List<Map<String, dynamic>>.unmodifiable(
      normalized.map(Map<String, dynamic>.from),
    );
  }

  /// Replaces local rows for [listingId] with remote truth (UUID ids).
  Future<List<Map<String, dynamic>>> replaceListingCacheWithRemote({
    required String listingId,
    required List<Map<String, dynamic>> remoteRows,
  }) async {
    await ensureLoaded();
    if (listingId.isEmpty) return const [];

    final normalized = [
      for (final row in remoteRows) _normalizeRemoteRow(row),
    ];
    final rows = [
      for (final row in _rows)
        if (row['listing_id']?.toString() != listingId) row,
      ...normalized,
    ];
    await _saveAll(rows);
    return List<Map<String, dynamic>>.unmodifiable(
      normalized.map(Map<String, dynamic>.from),
    );
  }

  static Map<String, dynamic> _normalizeRemoteRow(
    Map<String, dynamic> remoteRow,
  ) {
    final userId = remoteRow['applicant_user_id']?.toString() ??
        remoteRow['user_id']?.toString() ??
        '';
    return <String, dynamic>{
      ...remoteRow,
      if (userId.isNotEmpty) ...{
        'user_id': userId,
        'applicant_user_id': userId,
      },
    };
  }

  /// Returns `true` when a new application is stored.
  Future<bool> applyToListing(
    String listingId,
    String userId, {
    MarketplaceSpace? space,
  }) {
    if (listingId.isEmpty || userId.isEmpty) return Future.value(false);

    return _withApplyLock('$userId::$listingId', () async {
      await ensureLoaded();
      if (hasApplied(listingId: listingId, userId: userId)) return false;

      final session = UserSessionStore.current == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(UserSessionStore.current!);

      final application = ListingApplication(
        id: 'app-${DateTime.now().millisecondsSinceEpoch}',
        listingId: listingId,
        userId: userId,
        createdAt: DateTime.now(),
        status: ListingApplicationStatus.pending,
      );

      final rows = List<Map<String, dynamic>>.from(_rows)
        ..add({
          ...application.toMap(),
          'payload': session,
          if (space != null) 'space': space.storageToken,
        });
      await _saveAll(rows);
      return true;
    });
  }

  Future<T> _withApplyLock<T>(String key, Future<T> Function() action) async {
    while (_applyLocks.containsKey(key)) {
      await _applyLocks[key];
    }

    final done = Completer<void>();
    _applyLocks[key] = done.future;
    try {
      return await action();
    } finally {
      _applyLocks.remove(key);
      if (!done.isCompleted) done.complete();
    }
  }

  Future<Map<String, dynamic>> submitWithDetails({
    required String listingId,
    required Map<String, dynamic> session,
    required MarketplaceSpace space,
    required int compatibilityScore,
  }) async {
    if (listingId.isEmpty) {
      throw ArgumentError.value(listingId, 'listingId', 'must not be empty');
    }
    await ensureLoaded();

    var userId = ProfileData.text(session['supabase_user_id']);
    if (userId.isEmpty) {
      userId = AuthService.identityUserId(session);
    }
    final rows = List<Map<String, dynamic>>.from(_rows);
    final existing = rows.indexWhere(
      (row) =>
          row['listing_id']?.toString() == listingId &&
          _rowUserId(row) == userId,
    );

    // One application per seeker + listing — never create a second row.
    if (existing >= 0) {
      return Map<String, dynamic>.from(rows[existing]);
    }

    final application = ListingApplication(
      id: 'app-${DateTime.now().millisecondsSinceEpoch}',
      listingId: listingId,
      userId: userId,
      createdAt: DateTime.now(),
      status: ListingApplicationStatus.pending,
    );

    final payload = {
      ...application.toMap(),
      'space': space == MarketplaceSpace.sharedSpace
          ? 'shared_space'
          : 'full_rental',
      'compatibility_score':
          NumericBounds.clampPercentInt(compatibilityScore),
      'payload': Map<String, dynamic>.from(session),
    };

    rows.add(payload);
    await _saveAll(rows);
    return payload;
  }

  Future<void> _saveAll(List<Map<String, dynamic>> rows) async {
    _rows = rows;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(rows));
  }

  static String _rowUserId(Map<String, dynamic> row) =>
      row['user_id']?.toString() ??
      row['applicant_user_id']?.toString() ??
      '';
}

final applicationService = ApplicationService.instance;
