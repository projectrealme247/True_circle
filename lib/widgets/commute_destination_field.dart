import 'package:flutter/material.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../core/theme/app_theme.dart';
import '../services/commute_destination_geocoding_service.dart';
import 'onboarding/onboarding_design_tokens.dart';
import 'shadcn_select.dart';

/// Static commute destination picker with curated hubs and GIS-backed custom entry.
class CommuteDestinationField extends StatefulWidget {
  const CommuteDestinationField({
    super.key,
    required this.selectedHub,
    required this.occupantType,
    required this.onHubSelected,
    this.onCleared,
    this.label = 'Destination',
  });

  final DublinCommuterHub? selectedHub;
  final String? occupantType;
  final ValueChanged<DublinCommuterHub> onHubSelected;
  final VoidCallback? onCleared;
  final String label;

  @override
  State<CommuteDestinationField> createState() =>
      _CommuteDestinationFieldState();
}

class _CommuteDestinationFieldState extends State<CommuteDestinationField> {
  late final TextEditingController _customController;
  bool _customMode = false;
  bool _resolving = false;
  String? _resolveError;

  List<DublinCommuterHub> get _presetHubs =>
      DublinCommuterHubs.hubsForOccupantType(widget.occupantType);

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(
      text: widget.selectedHub != null &&
              DublinCommuterHubs.isCustomHub(widget.selectedHub!)
          ? widget.selectedHub!.label
          : '',
    );
    _customMode = widget.selectedHub != null &&
        (DublinCommuterHubs.isCustomHub(widget.selectedHub!) ||
            !_presetHubs.any((hub) => hub.id == widget.selectedHub!.id));
  }

  @override
  void didUpdateWidget(covariant CommuteDestinationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.occupantType != widget.occupantType &&
        widget.selectedHub != null &&
        !_presetHubs.any((hub) => hub.id == widget.selectedHub!.id) &&
        !DublinCommuterHubs.isCustomHub(widget.selectedHub!)) {
      setState(() {
        _customMode = false;
        _customController.clear();
        _resolveError = null;
      });
      widget.onCleared?.call();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String? get _selectValue {
    if (_customMode) return DublinCommuterHubs.otherLocationLabel;
    final hub = widget.selectedHub;
    if (hub == null) return null;
    if (_presetHubs.any((preset) => preset.id == hub.id)) return hub.label;
    return DublinCommuterHubs.otherLocationLabel;
  }

  Future<void> _resolveCustomDestination() async {
    final query = _customController.text.trim();
    if (query.isEmpty) {
      setState(() => _resolveError = 'Enter a Dublin-area place or address.');
      return;
    }

    setState(() {
      _resolving = true;
      _resolveError = null;
    });

    final hub = await CommuteDestinationGeocodingService.resolveCustomDestination(
      query,
    );

    if (!mounted) return;
    setState(() => _resolving = false);

    if (hub == null) {
      setState(() {
        _resolveError =
            'Could not locate that place in Dublin. Try a neighbourhood or landmark.';
      });
      return;
    }

    widget.onHubSelected(hub);
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      ..._presetHubs.map((hub) => hub.label),
      DublinCommuterHubs.otherLocationLabel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadcnSelect(
          label: widget.label,
          value: _selectValue ?? '',
          hint: 'Select destination',
          options: options,
          onChanged: (value) {
            if (value == DublinCommuterHubs.otherLocationLabel) {
              setState(() {
                _customMode = true;
                _resolveError = null;
              });
              widget.onCleared?.call();
              return;
            }

            final hub = _presetHubs.firstWhere(
              (preset) => preset.label == value,
              orElse: () => _presetHubs.first,
            );
            setState(() {
              _customMode = false;
              _customController.clear();
              _resolveError = null;
            });
            widget.onHubSelected(hub);
          },
        ),
        if (_customMode) ...[
          const SizedBox(height: 12),
          Text(
            'Custom destination',
            style: OnboardingTokens.sectionLabelStyle,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _customController,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
            decoration: OnboardingTokens.inputDecoration(
              hint: 'e.g. Smithfield, Sandyford Industrial Estate',
            ),
            onFieldSubmitted: (_) => _resolveCustomDestination(),
          ),
          if (_resolveError != null) ...[
            const SizedBox(height: 6),
            Text(
              _resolveError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resolving ? null : _resolveCustomDestination,
              icon: _resolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pin_drop_outlined, size: 18),
              label: Text(
                _resolving ? 'Locating…' : 'Use this location',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
              ),
            ),
          ),
          if (widget.selectedHub != null &&
              DublinCommuterHubs.isCustomHub(widget.selectedHub!)) ...[
            const SizedBox(height: 4),
            Text(
              'Pinned: ${widget.selectedHub!.label}',
              style: const TextStyle(
                fontSize: 12,
                color: OnboardingTokens.subtitleColor,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
