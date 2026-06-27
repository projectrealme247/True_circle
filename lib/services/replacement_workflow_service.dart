import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/profile_data.dart';

class ReplacementWorkflow {
  const ReplacementWorkflow({
    required this.id,
    required this.listingId,
    required this.outgoingTenantId,
    required this.status,
    this.moveOutDate,
    this.progress = const {},
  });

  final String id;
  final String listingId;
  final String outgoingTenantId;
  final String status;
  final String? moveOutDate;
  final Map<String, dynamic> progress;

  factory ReplacementWorkflow.fromMap(Map<String, dynamic> map) {
    return ReplacementWorkflow(
      id: ProfileData.text(map['id']),
      listingId: ProfileData.text(map['listing_id']),
      outgoingTenantId: ProfileData.text(map['outgoing_tenant_id']),
      status: ProfileData.text(map['status']).isEmpty
          ? 'draft'
          : ProfileData.text(map['status']),
      moveOutDate: ProfileData.text(map['move_out_date']).isEmpty
          ? null
          : ProfileData.text(map['move_out_date']),
      progress: map['progress'] is Map
          ? Map<String, dynamic>.from(map['progress'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'listing_id': listingId,
        'outgoing_tenant_id': outgoingTenantId,
        'status': status,
        if (moveOutDate != null) 'move_out_date': moveOutDate,
        'progress': progress,
      };

  int get completedSteps {
    final steps = progress['steps'];
    if (steps is! List) return 0;
    return steps.where((s) => s == true).length;
  }

  int get totalSteps {
    final steps = progress['steps'];
    if (steps is! List) return 4;
    return steps.length;
  }
}

/// Local stub for Share-only lease replacement workflows.
abstract final class ReplacementWorkflowService {
  static const _storageKey = 'circlekey_replacement_workflows';

  static Future<List<ReplacementWorkflow>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            ReplacementWorkflow.fromMap(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<ReplacementWorkflow> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(rows.map((r) => r.toMap()).toList()),
    );
  }

  static Future<ReplacementWorkflow?> activeForUser(
    Map<String, dynamic>? session,
  ) async {
    final userId = ProfileData.text(session?['supabase_user_id']);
    if (userId.isEmpty) return null;
    final rows = await loadAll();
    for (final row in rows) {
      if (row.outgoingTenantId != userId) continue;
      if (row.status == 'completed' || row.status == 'cancelled') continue;
      return row;
    }
    return null;
  }

  static Future<ReplacementWorkflow> startDraft({
    required String listingId,
    required Map<String, dynamic> session,
  }) async {
    final userId = ProfileData.text(session['supabase_user_id']);
    final rows = await loadAll();
    final workflow = ReplacementWorkflow(
      id: 'repl-${DateTime.now().millisecondsSinceEpoch}',
      listingId: listingId,
      outgoingTenantId: userId,
      status: 'draft',
      progress: {
        'steps': [true, false, false, false],
        'labels': [
          'Start replacement',
          'Room details',
          'Seeker profile',
          'Publish listing',
        ],
      },
    );
    rows.add(workflow);
    await _saveAll(rows);
    return workflow;
  }

  static Future<ReplacementWorkflow> advanceStep(String workflowId) async {
    final rows = await loadAll();
    final index = rows.indexWhere((r) => r.id == workflowId);
    if (index < 0) {
      throw StateError('Workflow not found');
    }
    final current = rows[index];
    final steps = List<bool>.from(
      (current.progress['steps'] as List?)?.cast<bool>() ??
          [true, false, false, false],
    );
    for (var i = 0; i < steps.length; i++) {
      if (!steps[i]) {
        steps[i] = true;
        break;
      }
    }
    final allDone = steps.every((s) => s);
    final updated = ReplacementWorkflow(
      id: current.id,
      listingId: current.listingId,
      outgoingTenantId: current.outgoingTenantId,
      status: allDone ? 'published' : current.status,
      moveOutDate: current.moveOutDate,
      progress: {...current.progress, 'steps': steps},
    );
    rows[index] = updated;
    await _saveAll(rows);
    return updated;
  }

  static Future<void> cancel(String workflowId) async {
    final rows = await loadAll();
    final index = rows.indexWhere((r) => r.id == workflowId);
    if (index < 0) return;
    final current = rows[index];
    rows[index] = ReplacementWorkflow(
      id: current.id,
      listingId: current.listingId,
      outgoingTenantId: current.outgoingTenantId,
      status: 'cancelled',
      moveOutDate: current.moveOutDate,
      progress: current.progress,
    );
    await _saveAll(rows);
  }
}
