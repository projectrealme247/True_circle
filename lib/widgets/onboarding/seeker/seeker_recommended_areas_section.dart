import 'package:flutter/material.dart';

import '../../../config/market/dublin_commuter_hubs.dart';
import '../../../config/market/dublin_macro_areas.dart';
import '../../../models/seeker_onboarding_enums.dart';
import '../../../services/commute_scoring_service.dart';
import '../../../services/listings_storage_service.dart';
import '../../../utils/accepted_district_recommendations.dart';
import '../../../utils/district_commute_snapshot.dart';
import '../../../utils/district_inventory_stats.dart';
import '../../../utils/district_recommendation_explainer.dart';
import '../../../utils/district_recommendation_ranker.dart';
import '../onboarding_choice_chip.dart';
import '../onboarding_design_tokens.dart';
import 'seeker_preferred_areas_selector.dart';

/// Live Recommended Areas panel (ranker + explainer).
///
/// Unmounted from onboarding (V1 simplification). Kept for tests and future
/// non-onboarding surfaces. Does not drive browse filters.
class SeekerRecommendedAreasSection extends StatefulWidget {
  const SeekerRecommendedAreasSection({
    super.key,
    required this.persona,
    required this.budgetMax,
    required this.destinationHub,
    required this.commuteDestinationUnknown,
    required this.transportMode,
    required this.maxTravelMinutes,
    required this.selectedTargetSearchAreas,
    required this.onToggleTargetSearchArea,
    required this.onAcceptRecommendations,
    this.inventoryOverride,
  });

  final SeekerPersona? persona;
  final int budgetMax;
  final DublinCommuterHub? destinationHub;
  final bool commuteDestinationUnknown;
  final CommuteMethod transportMode;
  final int maxTravelMinutes;
  final List<String> selectedTargetSearchAreas;
  final ValueChanged<String> onToggleTargetSearchArea;

  /// Explicit Accept — district signals + macro compatibility tokens.
  final ValueChanged<DistrictRecommendationAcceptance> onAcceptRecommendations;

  /// Test / preview injection — skips [ListingsStorageService] when set.
  final DistrictInventorySnapshot? inventoryOverride;

  static const topN = 3;

  @override
  State<SeekerRecommendedAreasSection> createState() =>
      _SeekerRecommendedAreasSectionState();
}

class _SeekerRecommendedAreasSectionState
    extends State<SeekerRecommendedAreasSection> {
  DistrictInventorySnapshot? _inventory;
  bool _loadingInventory = true;
  bool _modifying = false;
  bool _accepted = false;
  List<String> _lastAcceptedMacros = const [];

  @override
  void initState() {
    super.initState();
    if (widget.inventoryOverride != null) {
      _inventory = widget.inventoryOverride;
      _loadingInventory = false;
    } else {
      _loadInventory();
    }
  }

  @override
  void didUpdateWidget(covariant SeekerRecommendedAreasSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final inputsChanged =
        oldWidget.destinationHub?.id != widget.destinationHub?.id ||
            oldWidget.transportMode != widget.transportMode ||
            oldWidget.maxTravelMinutes != widget.maxTravelMinutes ||
            oldWidget.budgetMax != widget.budgetMax ||
            oldWidget.persona != widget.persona ||
            oldWidget.commuteDestinationUnknown !=
                widget.commuteDestinationUnknown;
    if (inputsChanged && (_accepted || _modifying)) {
      setState(() {
        _accepted = false;
        _lastAcceptedMacros = const [];
      });
    }
  }

  Future<void> _loadInventory() async {
    try {
      final listings = await ListingsStorageService.load();
      if (!mounted) return;
      setState(() {
        _inventory = DistrictInventorySnapshot.build(listings);
        _loadingInventory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inventory = DistrictInventorySnapshot(
          byDistrict: const {},
          totalListingsScanned: 0,
          unresolvedListingCount: 0,
          builtAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        _loadingInventory = false;
      });
    }
  }

  bool get _canRank =>
      widget.destinationHub != null && !widget.commuteDestinationUnknown;

  _RankedBundle? _computeBundle() {
    if (!_canRank || _inventory == null) return null;
    final hub = widget.destinationHub!;
    final request = DistrictRecommendationRequest(
      persona: widget.persona,
      budgetMax: widget.budgetMax,
      destinationHub: hub,
      transportMode: widget.transportMode,
      maxTravelMinutes: widget.maxTravelMinutes,
    );
    final commute = DistrictCommuteSnapshot.build(
      destinationHub: hub,
      transportMode: widget.transportMode,
      maxTravelMinutes: widget.maxTravelMinutes,
    );
    final ranked = DistrictRecommendationRanker.rank(
      request: request,
      inventory: _inventory!,
      commute: commute,
    );
    if (ranked.isEmpty) {
      return _RankedBundle(
        recommendations: const [],
        explanations: const [],
        macros: const [],
      );
    }
    final top = ranked.take(SeekerRecommendedAreasSection.topN).toList();
    final context = DistrictExplanationContext.fromRequest(request);
    final explanations = <DistrictRecommendationExplanation>[];
    for (final row in top) {
      final stats = _inventory![row.districtKey];
      final eligibility = commute[row.districtKey];
      if (stats == null || eligibility == null) continue;
      explanations.add(
        DistrictRecommendationExplainer.explain(
          recommendation: row,
          inventory: stats,
          commute: eligibility,
          context: context,
        ),
      );
    }
    return _RankedBundle(
      recommendations: top,
      explanations: explanations,
      macros: _macrosForDistricts(
        explanations.map((e) => e.districtKey),
      ),
    );
  }

  void _onAccept(_RankedBundle bundle) {
    if (bundle.recommendations.isEmpty || widget.destinationHub == null) {
      return;
    }
    final acceptance = AcceptedDistrictRecommendations.fromRanked(
      recommendations: bundle.recommendations,
      macros: bundle.macros,
      destinationHub: widget.destinationHub!,
      transportMode: widget.transportMode,
      maxTravelMinutes: widget.maxTravelMinutes,
    );
    widget.onAcceptRecommendations(acceptance);
    setState(() {
      _accepted = true;
      _lastAcceptedMacros = bundle.macros;
      _modifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInventory) {
      return Text(
        'Loading area recommendations…',
        style: OnboardingTokens.helperTextStyle,
      );
    }

    if (!_canRank) {
      return Text(
        'Choose a primary destination to see recommended areas.',
        style: OnboardingTokens.helperTextStyle,
      );
    }

    final bundle = _computeBundle();
    if (bundle == null || bundle.explanations.isEmpty) {
      return Text(
        'No eligible areas for this destination and travel time yet. '
        'Try a longer maximum travel time, or modify areas manually.',
        style: OnboardingTokens.helperTextStyle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: bundle.explanations.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: OnboardingTokens.space8),
            itemBuilder: (context, index) {
              final explanation = bundle.explanations[index];
              return _RecommendationBlock(explanation: explanation);
            },
          ),
        ),
        const SizedBox(height: OnboardingTokens.space8),
        OnboardingChoiceChip(
          label: _accepted ? 'Accepted' : 'Accept recommendations',
          selected: _accepted,
          expand: true,
          dense: true,
          seekerOptionStyle: true,
          onTap: () => _onAccept(bundle),
        ),
        const SizedBox(height: OnboardingTokens.space8),
        OnboardingChoiceChip(
          label: _modifying ? 'Hide area picker' : 'Modify areas',
          selected: _modifying,
          expand: true,
          dense: true,
          seekerOptionStyle: true,
          onTap: () => setState(() => _modifying = !_modifying),
        ),
        if (_accepted && _lastAcceptedMacros.isNotEmpty) ...[
          const SizedBox(height: OnboardingTokens.space4),
          Text(
            'Saved to preferred areas — change anytime via Modify.',
            style: OnboardingTokens.helperTextStyle,
          ),
        ],
        if (_modifying) ...[
          const SizedBox(height: OnboardingTokens.space8),
          Text(
            'Preferred areas (optional)',
            style: SeekerOnboardingLayout.fieldLabel,
          ),
          const SizedBox(height: OnboardingTokens.space4),
          SeekerPreferredAreasSelector(
            selectedTargetSearchAreas: widget.selectedTargetSearchAreas,
            onToggleTargetSearchArea: widget.onToggleTargetSearchArea,
          ),
        ],
      ],
    );
  }
}

class _RankedBundle {
  const _RankedBundle({
    required this.recommendations,
    required this.explanations,
    required this.macros,
  });

  final List<DistrictRecommendation> recommendations;
  final List<DistrictRecommendationExplanation> explanations;
  final List<String> macros;
}

class _RecommendationBlock extends StatelessWidget {
  const _RecommendationBlock({required this.explanation});

  final DistrictRecommendationExplanation explanation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          explanation.districtLabel,
          style: SeekerOnboardingLayout.fieldLabel.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: OnboardingTokens.space4),
        for (final reason in explanation.reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✓ ',
                  style: OnboardingTokens.helperTextStyle.copyWith(
                    color: const Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                Expanded(
                  child: Text(
                    reason.text,
                    style: OnboardingTokens.helperTextStyle.copyWith(
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Maps recommended district keys → covering macro tokens (deduped, stable order).
List<String> _macrosForDistricts(Iterable<String> districtKeys) {
  final out = <String>[];
  for (final district in districtKeys) {
    final macro = _macroTokenForDistrict(district);
    if (macro != null && !out.contains(macro)) {
      out.add(macro);
    }
  }
  return out;
}

String? _macroTokenForDistrict(String districtKey) {
  final key = districtKey.trim().toLowerCase();
  for (final (token, _) in DublinMacroAreas.primaryOptions) {
    if (DublinMacroAreas.districtKeysFor(token).contains(key)) {
      return token;
    }
  }
  return null;
}
