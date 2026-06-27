import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth_screen.dart';
import '../utils/viewer_profile.dart';
import 'trust_service.dart';

/// Summary of a stored invite code.
class InviteCodeRecord {
  const InviteCodeRecord({
    required this.code,
    required this.redemptions,
    required this.maxRedemptions,
    required this.createdAt,
  });

  final String code;
  final int redemptions;
  final int maxRedemptions;
  final DateTime? createdAt;

  int get remaining => (maxRedemptions - redemptions).clamp(0, maxRedemptions);
  bool get isExhausted => redemptions >= maxRedemptions;
}

/// Local invite codes for Track B pre-arrival contact (POC).
abstract final class InviteCodeService {
  static const _storageKey = 'circlekey_invite_codes_v1';
  static const maxRedemptionsPerCode = 5;

  /// Demo code seeded for local testing when no Stage 3 user exists yet.
  static const demoCode = 'DUBLIN-DEMO';
  static const demoInviterId = 'demo-stage3-host';

  static String get currentUserId =>
      AuthScreen.currentUserSession?['supabase_user_id']?.toString() ??
      AuthScreen.currentUserSession?['email']?.toString() ??
      'local-user';

  /// Generates a shareable invite code for the current Stage 3 user.
  static Future<String> generateForCurrentUser() async {
    if (TrustService.currentStage().level < TrustStage.idVerified.level) {
      throw StateError('Only Stage 3 users can generate invite codes.');
    }

    final userId = currentUserId;
    final code = _randomCode();
    final store = await _loadStore();
    store[code] = {
      'inviter_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'redemptions': 0,
    };
    await _saveStore(store);
    return code;
  }

  /// Active and exhausted codes created by the current user, newest first.
  static Future<List<InviteCodeRecord>> listForCurrentUser() async {
    if (TrustService.currentStage().level < TrustStage.idVerified.level) {
      return const [];
    }

    final userId = currentUserId;
    final store = await _loadStore();
    final records = <InviteCodeRecord>[];

    for (final entry in store.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      if (data['inviter_id']?.toString() != userId) continue;

      final redemptions = data['redemptions'];
      final count = redemptions is int ? redemptions : 0;
      final createdRaw = data['created_at']?.toString();
      records.add(
        InviteCodeRecord(
          code: entry.key,
          redemptions: count,
          maxRedemptions: maxRedemptionsPerCode,
          createdAt: createdRaw != null ? DateTime.tryParse(createdRaw) : null,
        ),
      );
    }

    records.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return records;
  }

  /// Validates [code] and returns inviter user id if redeemable.
  static Future<String?> validateCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    if (normalized == demoCode) {
      await _ensureDemoCode();
      return demoInviterId;
    }

    final store = await _loadStore();
    final entry = store[normalized];
    if (entry is! Map) return null;

    final redemptions = entry['redemptions'];
    if (redemptions is int && redemptions >= maxRedemptionsPerCode) {
      return null;
    }

    final inviterId = entry['inviter_id']?.toString();
    if (inviterId == null || inviterId.isEmpty) return null;
    return inviterId;
  }

  /// Marks [code] as redeemed once validation succeeds.
  static Future<void> recordRedemption(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized == demoCode) return;

    final store = await _loadStore();
    final entry = store[normalized];
    if (entry is! Map) return;

    final current = entry['redemptions'];
    entry['redemptions'] = current is int ? current + 1 : 1;
    store[normalized] = entry;
    await _saveStore(store);
  }

  static Future<void> _ensureDemoCode() async {
    final store = await _loadStore();
    if (store.containsKey(demoCode)) return;
    store[demoCode] = {
      'inviter_id': demoInviterId,
      'created_at': DateTime.now().toIso8601String(),
      'redemptions': 0,
      'demo': true,
    };
    await _saveStore(store);
  }

  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    final suffix = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'CK-$suffix';
  }

  static Future<Map<String, dynamic>> _loadStore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _saveStore(Map<String, dynamic> store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(store));
  }
}
