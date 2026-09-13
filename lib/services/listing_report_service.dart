import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/listing_report.dart';
import '../utils/profile_data.dart';
import 'listings_supabase_service.dart';

/// Lightweight listing-report capture for Trust & Safety Phase 1.
///
/// Persists locally for an admin review queue; best-effort Supabase mirror.
abstract final class ListingReportService {
  static const storageKey = 'circlekey_listing_reports';

  /// Submits an open listing report. Does not hide or alter the listing.
  static Future<ListingReport> submitListingReport({
    required String listingId,
    required ListingReportReason reason,
    String details = '',
    Map<String, dynamic>? session,
  }) async {
    final trimmedListingId = listingId.trim();
    if (trimmedListingId.isEmpty) {
      throw ArgumentError('listingId is required');
    }

    final report = ListingReport(
      id: 'lr_${DateTime.now().microsecondsSinceEpoch}',
      listingId: trimmedListingId,
      reporterId: _reporterId(session),
      reason: reason,
      details: details.trim(),
      status: 'open',
      createdAt: DateTime.now().toUtc(),
    );

    final existing = await loadAll();
    existing.add(report);
    await _saveAll(existing);

    // Best-effort remote mirror — local queue remains source of truth in Phase 1.
    try {
      await ListingsSupabaseService.tryInsertListingReport(report.toMap());
    } catch (e) {
      debugPrint('ListingReportService remote mirror skipped: $e');
    }

    return report;
  }

  /// All stored reports (admin review queue data).
  static Future<List<ListingReport>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ListingReport.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('ListingReportService loadAll failed: $e');
      return [];
    }
  }

  /// Open reports only — future admin tooling entry point.
  static Future<List<ListingReport>> loadOpen() async {
    final all = await loadAll();
    return all.where((r) => r.status == 'open').toList();
  }

  static Future<void> _saveAll(List<ListingReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode([for (final r in reports) r.toMap()]),
    );
  }

  static String _reporterId(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return 'anonymous';
    final userId = ProfileData.text(session['supabase_user_id']);
    if (userId.isNotEmpty) return userId;
    final email = ProfileData.text(session['email']);
    if (email.isNotEmpty) return email;
    return 'anonymous';
  }

  @visibleForTesting
  static Future<void> clearForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
