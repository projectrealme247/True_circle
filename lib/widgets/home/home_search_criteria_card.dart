import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/market/dublin_commuter_hubs.dart';
import '../../config/market/market_config.dart';
import '../../core/theme/app_theme.dart' show AppColors, AppFormFields, AppRadius;
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/thousands_separator_formatter.dart';

/// Commute hub + max budget block with integrated Find spaces CTA.
class HomeSearchCriteriaCard extends StatelessWidget {
  const HomeSearchCriteriaCard({
    super.key,
    required this.commuteHubLabel,
    required this.budgetController,
    required this.onCommuteHubTap,
    required this.onFindSpaces,
    this.onAdvancedFilters,
    this.budgetHint = 'e.g. 1200',
  });

  final String commuteHubLabel;
  final TextEditingController budgetController;
  final VoidCallback onCommuteHubTap;
  final VoidCallback onFindSpaces;
  final VoidCallback? onAdvancedFilters;
  final String budgetHint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CriteriaRow(
            icon: Icons.directions_bus_outlined,
            label: 'COMMUTE HUB',
            value: commuteHubLabel,
            onTap: onCommuteHubTap,
          ),
          const Divider(height: 1, color: HomeMarketplaceTheme.border),
          _BudgetRow(
            controller: budgetController,
            hint: budgetHint,
            onAdvancedFilters: onAdvancedFilters,
          ),
          Material(
            color: AppColors.executiveCta,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            child: InkWell(
              onTap: onFindSpaces,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Find spaces',
                      style: AppTypography.button().copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: HomeMarketplaceTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.meta().copyWith(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: HomeMarketplaceTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.searchInputProminent().copyWith(
                        fontWeight: FontWeight.w600,
                        color: HomeMarketplaceTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.controller,
    required this.hint,
    this.onAdvancedFilters,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onAdvancedFilters;

  @override
  Widget build(BuildContext context) {
    final symbol = MarketConfig.current.currencySymbol;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Text(
              symbol,
              style: AppTypography.searchInputProminent().copyWith(
                fontWeight: FontWeight.w600,
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAX BUDGET / MONTH',
                  style: AppTypography.meta().copyWith(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: HomeMarketplaceTheme.textSecondary,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorFormatter(),
                  ],
                  style: AppTypography.searchInputProminent().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTypography.searchHint().copyWith(
                      color: HomeMarketplaceTheme.textSecondary
                          .withValues(alpha: 0.65),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 2, bottom: 4),
                  ),
                  onSubmitted: (_) {},
                ),
              ],
            ),
          ),
          if (onAdvancedFilters != null)
            IconButton(
              tooltip: 'More filters',
              onPressed: onAdvancedFilters,
              icon: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet hub picker wired to [DublinCommuterHubs].
Future<DublinCommuterHub?> showCommuteHubPickerSheet(BuildContext context) {
  return showModalBottomSheet<DublinCommuterHub>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeMarketplaceTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final hubs = DublinCommuterHubs.all;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commute hub',
                      style: AppTypography.sectionTitle(),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hubs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Material(
                      color: Colors.white,
                      child: ListTile(
                        title: const Text('Any stop'),
                        onTap: () => Navigator.pop(ctx),
                      ),
                    );
                  }
                  final hub = hubs[index - 1];
                  return Material(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(hub.label),
                      onTap: () => Navigator.pop(ctx, hub),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
