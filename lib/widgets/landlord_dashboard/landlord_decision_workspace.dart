import 'package:flutter/material.dart';

import '../../models/landlord_applicant_card_model.dart';
import 'landlord_applicant_queue.dart';
import 'landlord_dashboard_theme.dart';
import 'landlord_decision_pane.dart';
import 'landlord_listings_rail.dart';

/// Centered fixed-width 3-column landlord decision workspace.
class LandlordDecisionWorkspace extends StatelessWidget {
  const LandlordDecisionWorkspace({
    super.key,
    required this.railItems,
    required this.selectedListingIndex,
    required this.onListingSelected,
    required this.applicants,
    required this.selectedApplicantId,
    required this.onApplicantSelected,
    required this.onInvite,
    required this.onReschedule,
    required this.onCancelViewing,
    required this.onArchive,
    this.actionLoadingId,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final List<LandlordListingRailItem> railItems;
  final int selectedListingIndex;
  final ValueChanged<int> onListingSelected;
  final List<LandlordApplicantCardModel> applicants;
  final String? selectedApplicantId;
  final ValueChanged<LandlordApplicantCardModel> onApplicantSelected;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onReschedule;
  final ValueChanged<LandlordApplicantCardModel> onCancelViewing;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  static const double maxWidth = 1360;

  LandlordApplicantCardModel? get _selected {
    if (applicants.isEmpty) return null;
    if (selectedApplicantId == null) return applicants.first;
    return applicants.cast<LandlordApplicantCardModel?>().firstWhere(
          (a) => a!.applicationId == selectedApplicantId,
          orElse: () => applicants.first,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          decoration: BoxDecoration(
            color: LandlordDashboardTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LandlordDashboardTheme.border),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A1917).withValues(alpha: 0.06),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 980;
              if (narrow) {
                return _NarrowWorkspace(
                  railItems: railItems,
                  selectedListingIndex: selectedListingIndex,
                  onListingSelected: onListingSelected,
                  applicants: applicants,
                  selectedApplicantId: selectedApplicantId,
                  onApplicantSelected: onApplicantSelected,
                  selected: _selected,
                  onInvite: onInvite,
                  onReschedule: onReschedule,
                  onCancelViewing: onCancelViewing,
                  onArchive: onArchive,
                  actionLoadingId: actionLoadingId,
                  hostPhoneE164: hostPhoneE164,
                  hostPrefersWhatsapp: hostPrefersWhatsapp,
                  listingTitle: listingTitle,
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LandlordListingsRail(
                    items: railItems,
                    selectedIndex: selectedListingIndex,
                    onSelected: onListingSelected,
                  ),
                  LandlordApplicantQueue(
                    applicants: applicants,
                    selectedId: _selected?.applicationId,
                    onSelect: onApplicantSelected,
                  ),
                  Expanded(
                    child: LandlordDecisionPane(
                      applicant: _selected,
                      onInvite: onInvite,
                      onReschedule: onReschedule,
                      onCancelViewing: onCancelViewing,
                      onArchive: onArchive,
                      actionLoadingId: actionLoadingId,
                      hostPhoneE164: hostPhoneE164,
                      hostPrefersWhatsapp: hostPrefersWhatsapp,
                      listingTitle: listingTitle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NarrowWorkspace extends StatelessWidget {
  const _NarrowWorkspace({
    required this.railItems,
    required this.selectedListingIndex,
    required this.onListingSelected,
    required this.applicants,
    required this.selectedApplicantId,
    required this.onApplicantSelected,
    required this.selected,
    required this.onInvite,
    required this.onReschedule,
    required this.onCancelViewing,
    required this.onArchive,
    this.actionLoadingId,
    this.hostPhoneE164,
    this.hostPrefersWhatsapp = false,
    this.listingTitle = '',
  });

  final List<LandlordListingRailItem> railItems;
  final int selectedListingIndex;
  final ValueChanged<int> onListingSelected;
  final List<LandlordApplicantCardModel> applicants;
  final String? selectedApplicantId;
  final ValueChanged<LandlordApplicantCardModel> onApplicantSelected;
  final LandlordApplicantCardModel? selected;
  final ValueChanged<LandlordApplicantCardModel> onInvite;
  final ValueChanged<LandlordApplicantCardModel> onReschedule;
  final ValueChanged<LandlordApplicantCardModel> onCancelViewing;
  final ValueChanged<LandlordApplicantCardModel> onArchive;
  final String? actionLoadingId;
  final String? hostPhoneE164;
  final bool hostPrefersWhatsapp;
  final String listingTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: LandlordListingsRail(
            items: railItems,
            selectedIndex: selectedListingIndex,
            onSelected: onListingSelected,
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LandlordApplicantQueue(
                applicants: applicants,
                selectedId: selected?.applicationId,
                onSelect: onApplicantSelected,
              ),
              Expanded(
                child: LandlordDecisionPane(
                  applicant: selected,
                  onInvite: onInvite,
                  onReschedule: onReschedule,
                  onCancelViewing: onCancelViewing,
                  onArchive: onArchive,
                  actionLoadingId: actionLoadingId,
                  hostPhoneE164: hostPhoneE164,
                  hostPrefersWhatsapp: hostPrefersWhatsapp,
                  listingTitle: listingTitle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
