import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' show AppColors, AppButtonStyles;
import '../services/marketplace_context_notifier.dart';
import '../services/replacement_workflow_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';
import '../services/listings_storage_service.dart';

/// Share-only wizard for lease replacement (steps 2–4 simplified).
class LeaseReplacementWizardScreen extends StatefulWidget {
  const LeaseReplacementWizardScreen({
    super.key,
    required this.workflowId,
  });

  final String workflowId;

  @override
  State<LeaseReplacementWizardScreen> createState() =>
      _LeaseReplacementWizardScreenState();
}

class _LeaseReplacementWizardScreenState
    extends State<LeaseReplacementWizardScreen> {
  Map<String, dynamic>? _listing;
  ReplacementWorkflow? _workflow;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final workflows = await ReplacementWorkflowService.loadAll();
    ReplacementWorkflow? workflow;
    for (final row in workflows) {
      if (row.id == widget.workflowId) {
        workflow = row;
        break;
      }
    }
    Map<String, dynamic>? listing;
    if (workflow != null) {
      listing = await ListingsStorageService.getById(workflow.listingId);
    }
    if (!mounted) return;
    setState(() {
      _workflow = workflow;
      _listing = listing;
      _loading = false;
    });
  }

  Future<void> _advance() async {
    await ReplacementWorkflowService.advanceStep(widget.workflowId);
    await marketplaceContextNotifier.refresh();
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeMarketplaceTheme.canvas,
      appBar: AppBar(
        backgroundColor: HomeMarketplaceTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Lease replacement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workflow == null
              ? const Center(child: Text('Workflow not found'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Replace your room',
                        style: AppTypography.sectionTitle(),
                      ),
                      const SizedBox(height: 8),
                      if (_listing != null)
                        Text(
                          ListingData.title(_listing!),
                          style: AppTypography.cardTitle(),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Step ${_workflow!.completedSteps + 1} of ${_workflow!.totalSteps}',
                        style: AppTypography.detail(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Confirm room details and publish your replacement listing. '
                        'Your progress will appear on the home feed.',
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _advance,
                        style: AppButtonStyles.primaryFilled,
                        child: const Text('Save and continue'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
