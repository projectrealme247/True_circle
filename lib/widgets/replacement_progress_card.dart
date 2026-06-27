import 'package:flutter/material.dart';

import '../services/replacement_workflow_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';

/// Sticky progress card for in-flight Share lease replacements.
class ReplacementProgressCard extends StatelessWidget {
  const ReplacementProgressCard({
    super.key,
    required this.workflow,
    required this.onContinue,
    required this.onCancel,
  });

  final ReplacementWorkflow workflow;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final labels = (workflow.progress['labels'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [
          'Start replacement',
          'Room details',
          'Seeker profile',
          'Publish listing',
        ];
    final steps = (workflow.progress['steps'] as List?)?.cast<bool>() ??
        const [true, false, false, false];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lease replacement in progress',
                  style: AppTypography.cardTitle(),
                ),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${workflow.completedSteps} of ${workflow.totalSteps}',
            style: AppTypography.detail(),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < labels.length && i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    steps[i]
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: steps[i]
                        ? HomeMarketplaceTheme.primary
                        : HomeMarketplaceTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(labels[i], style: AppTypography.detail()),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: HomeMarketplaceTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue replacement'),
          ),
        ],
      ),
    );
  }
}
