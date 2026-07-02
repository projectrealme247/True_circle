import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../utils/profile_data.dart';
import '../utils/profile_progress.dart';

/// Compact onboarding prompt — avoids full-viewport blank states on web.
abstract final class ProfileCompletionDialog {
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic>? session,
    required int ownedListingCount,
  }) {
    final percent = ProfileProgress.percent(
      session,
      ownedListingCount: ownedListingCount,
    );
    final missing = ProfileProgress.missingFields(
      session,
      ownedListingCount: ownedListingCount,
    );
    final linkedInDone = session?['linkedin_verified'] == true;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.accent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Profile $percent% complete',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    linkedInDone
                        ? 'LinkedIn is connected. Finish a few profile fields to unlock tailored matching.'
                        : 'Complete identity, commute, and search preferences to reach 100%.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Still needed: ${missing.take(4).join(', ')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFBE123C),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.push(
                        '/profile/edit',
                        extra: session,
                      );
                    },
                    style: AppButtonStyles.primaryFilled,
                    child: const Text('Continue setup'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
