import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/listing_application.dart';
import '../models/marketplace_space.dart';
import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';
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

    final userId = ProfileData.text(session['supabase_user_id']);
    final rows = List<Map<String, dynamic>>.from(_rows);
    final existing = rows.indexWhere(
      (row) =>
          row['listing_id']?.toString() == listingId &&
          _rowUserId(row) == userId,
    );

    final application = ListingApplication(
      id: existing >= 0
          ? rows[existing]['id']?.toString() ??
              'app-${DateTime.now().millisecondsSinceEpoch}'
          : 'app-${DateTime.now().millisecondsSinceEpoch}',
      listingId: listingId,
      userId: userId,
      createdAt: existing >= 0
          ? DateTime.tryParse(
                rows[existing]['created_at']?.toString() ?? '',
              ) ??
              DateTime.now()
          : DateTime.now(),
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

    if (existing >= 0) {
      rows[existing] = payload;
    } else {
      rows.add(payload);
    }
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
