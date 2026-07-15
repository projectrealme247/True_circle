import 'package:flutter/material.dart';

import '../../utils/contextual_passport_snapshot.dart';
import 'onboarding/contextual_passport_card.dart';

/// Modal wrapper for the contextual 4-track passport view.
class ProfileDetailPassportDialog extends StatelessWidget {
  const ProfileDetailPassportDialog({
    super.key,
    required this.snapshot,
    this.headerCaption = 'Public Passport',
  });

  final ContextualPassportSnapshot snapshot;
  final String headerCaption;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> session,
    int? listingBudgetRequirement,
    String headerCaption = 'Public Passport',
  }) {
    final snapshot = ContextualPassportSnapshot.fromSession(
      session,
      listingBudgetRequirement: listingBudgetRequirement,
    );
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => ProfileDetailPassportDialog(
        snapshot: snapshot,
        headerCaption: headerCaption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ContextualPassportCard(
            snapshot: snapshot,
            headerCaption: headerCaption,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
