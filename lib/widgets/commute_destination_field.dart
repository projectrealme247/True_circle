import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../core/theme/app_theme.dart';
import '../models/dublin_destination_suggestion.dart';
import '../models/seeker_onboarding_enums.dart';
import '../services/fast_location_service.dart';
import '../services/seeker_destination_nominatim_service.dart';
import 'emoji_leading_row.dart';
import 'listing_creation/listing_creation_primitives.dart';
import 'onboarding/onboarding_field_block.dart';

/// Two-tier Dublin destination picker — macro presets + live Nominatim search.
class CommuteDestinationField extends StatefulWidget {
  const CommuteDestinationField({
    super.key,
    required this.selectedHub,
    required this.onHubSelected,
    this.onCleared,
    this.onCommuteDestinationUnknown,
    this.commuteDestinationUnknown = false,
    this.persona,
    this.label = 'Popular daily destinations',
    this.occupantType,
    this.enabled = true,
    this.compactPresets = false,
    this.maxPresetRows = 0,
    this.showPresets = true,
    this.presetOverride,
    this.seekerPolishStyle = false,
  });

  final DublinCommuterHub? selectedHub;
  final ValueChanged<DublinCommuterHub> onHubSelected;
  final VoidCallback? onCleared;
  final VoidCallback? onCommuteDestinationUnknown;
  final bool commuteDestinationUnknown;
  final SeekerPersona? persona;
  final String label;

  /// Retained for profile-edit compatibility.
  final String? occupantType;
  final bool enabled;

  /// Smaller chips + denser grid for scroll-constrained onboarding.
  final bool compactPresets;

  /// When > 0, caps popular hubs to [maxPresetRows] × 3 columns.
  final int maxPresetRows;

  /// When false, only the custom destination search field is shown.
  final bool showPresets;

  /// When set, replaces persona-filtered presets (family driver overrides).
  final List<SeekerMacroPreset>? presetOverride;

  /// Seeker polish: 44px search field, quieter chrome.
  final bool seekerPolishStyle;

  @override
  State<CommuteDestinationField> createState() =>
      _CommuteDestinationFieldState();
}

class _CommuteDestinationFieldState extends State<CommuteDestinationField> {
  static final Object _tapGroup = Object();

  static const _debounceDuration = Duration(milliseconds: 300);
  static const _minQueryLength = 2;

  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _fieldAnchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  int _searchGeneration = 0;

  List<DublinDestinationSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _fetchingGps = false;
  String? _searchError;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _customFieldLabel(widget.selectedHub),
    );
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant CommuteDestinationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hub = widget.selectedHub;
    if (hub != oldWidget.selectedHub) {
      final label = _customFieldLabel(hub);
      if (_controller.text.trim() != label) {
        _controller.text = label;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  bool _isMacroPresetHub(DublinCommuterHub? hub) {
    if (hub == null) return false;
    return DublinCommuterHubs.seekerOnboardingPresets
        .any((preset) => preset.hub.id == hub.id);
  }

  /// Custom search field shows only free-text / Nominatim picks — not macro presets.
  String _customFieldLabel(DublinCommuterHub? hub) {
    if (hub == null || _isMacroPresetHub(hub)) return '';
    return hub.label;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _focusNode.hasFocus) return;
        _removeOverlay();
      });
    } else if (_suggestions.isNotEmpty || _searching) {
      _renderOverlay();
    }
  }

  void _dismissOverlay() {
    _debounce?.cancel();
    _removeOverlay();
  }

  void _onQueryChanged(String value) {
    final query = value.trim();

    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchError = null;
      });
      _removeOverlay();
      widget.onCleared?.call();
      return;
    }

    if (_isMacroPresetHub(widget.selectedHub)) {
      widget.onCleared?.call();
    }

    _debounce?.cancel();

    if (query.length < _minQueryLength) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchError = null;
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _gpsError = null;
      _suggestions = const [];
    });
    if (_focusNode.hasFocus) {
      _renderOverlay();
    }

    _debounce = Timer(_debounceDuration, _runSearch);
  }

  void _selectPreset(SeekerMacroPreset preset) {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _suggestions = const [];
      _searching = false;
      _searchError = null;
      _gpsError = null;
    });
    _removeOverlay();
    _focusNode.unfocus();
    widget.onHubSelected(preset.hub);
  }

  Future<void> _runSearch() async {
    final gen = ++_searchGeneration;
    final query = _controller.text.trim();

    if (query.length < _minQueryLength) return;

    if (mounted && gen == _searchGeneration) {
      setState(() {
        _searching = true;
        _searchError = null;
        _gpsError = null;
      });
      if (_focusNode.hasFocus) {
        _renderOverlay();
      }
    }

    try {
      final results =
          await SeekerDestinationNominatimService.searchOnSubmit(query);
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        if (results.isEmpty) {
          _searchError =
              'No Dublin matches found. Try a neighbourhood or campus name.';
        }
      });
      if (_focusNode.hasFocus) {
        _renderOverlay();
      } else {
        _removeOverlay();
      }
    } catch (_) {
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searchError = 'Search failed — try again in a moment.';
      });
      _removeOverlay();
    }
  }

  void _applySuggestion(DublinDestinationSuggestion suggestion) {
    final selectedLocation = suggestion.displayLabel.trim();
    final hub = SeekerDestinationNominatimService.hubFromSuggestion(suggestion);

    _debounce?.cancel();
    _searchGeneration++;

    // 1. Force the text input state update before hiding the overlay.
    _controller.text = selectedLocation;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );

    // 2. Commit selection to the parent onboarding / profile payload.
    widget.onHubSelected(hub);

    // 3. Clear focus and hide the suggestion list.
    setState(() {
      _suggestions = const [];
      _searching = false;
      _searchError = null;
      _gpsError = null;
    });
    _removeOverlay();
    _focusNode.unfocus();
  }

  Future<void> _useCurrentLocation() async {
    if (_fetchingGps || !widget.enabled) return;

    setState(() {
      _fetchingGps = true;
      _gpsError = null;
      _searchError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _gpsError =
              'Location services are off. Search for your destination instead.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _gpsError =
              'Location permission denied. Search for your destination instead.';
        });
        return;
      }

      final resolved = await FastLocationService.resolveForUserAction();
      if (resolved == null) {
        setState(() {
          _gpsError =
              'Could not read GPS. Search for your destination instead.';
        });
        return;
      }

      final suggestion = await SeekerDestinationNominatimService.reverseGeocode(
        resolved.latitude,
        resolved.longitude,
      );
      if (suggestion == null) {
        setState(() {
          _gpsError =
              'Your location is outside Dublin. Search for a Dublin destination.';
        });
        return;
      }

      _applySuggestion(suggestion);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsError = 'Could not read GPS. Search for your destination instead.';
      });
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  void _renderOverlay() {
    final showLoading = _searching;
    final showSuggestions = _suggestions.isNotEmpty;
    if (!showLoading && !showSuggestions) {
      _removeOverlay();
      return;
    }

    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlay(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlay() {
    final showLoading = _searching && _suggestions.isEmpty;
    final showSuggestions = _suggestions.isNotEmpty;

    return Positioned(
      width: _fieldWidth(),
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, listingFieldHeight + 4),
        child: TapRegion(
          groupId: _tapGroup,
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
            elevation: 12,
            color: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: listingDaftBorderColor, width: 1),
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: showLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Searching Dublin…',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : showSuggestions
                      ? ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            return InkWell(
                              onTap: () => _applySuggestion(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                child: EmojiLeadingRow(
                                  emoji: '📍',
                                  text: item.displayLabel,
                                  style: listingFieldValueStyle.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  emojiWidth: 20,
                                  emojiFontSize: 14,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                ),
                              ),
                            );
                          },
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      ),
    );
  }

  double _fieldWidth() {
    final box =
        _fieldAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width ?? MediaQuery.sizeOf(context).width - 48;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _searchPrefix() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: _searching
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.search,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
    );
  }

  Widget _locationSuffix() {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: TextButton(
        onPressed: widget.enabled && !_fetchingGps ? _useCurrentLocation : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF374151),
        ),
        child: _fetchingGps
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    child: Text(
                      '📍',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Use Current Location',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Set<int> _selectedIndicesForRow(List<SeekerMacroPreset> rowPresets) {
    final hub = widget.selectedHub;
    if (hub == null) return const {};
    for (var i = 0; i < rowPresets.length; i++) {
      if (rowPresets[i].hub.id == hub.id) return {i};
    }
    return const {};
  }

  Widget _buildPresetGrid() {
    var presets = widget.presetOverride ??
        DublinCommuterHubs.seekerOnboardingPresetsForPersona(widget.persona);
    const columns = 3;
    if (widget.maxPresetRows > 0) {
      final cap = widget.maxPresetRows * columns;
      if (presets.length > cap) {
        presets = presets.take(cap).toList(growable: false);
      }
    }
    final rows = <List<SeekerMacroPreset>>[];
    for (var i = 0; i < presets.length; i += columns) {
      rows.add(presets.sublist(i, (i + columns).clamp(0, presets.length)));
    }

    final rowGap = widget.compactPresets ? 6.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: rowGap),
          OnboardingEqualGridRow(
            labels: [for (final preset in rows[r]) preset.chipLabel],
            selectedIndices: _selectedIndicesForRow(rows[r]),
            onSelected: widget.enabled
                ? (index) => _selectPreset(rows[r][index])
                : (_) {},
            compactLabel: true,
            dense: widget.compactPresets,
            seekerOptionStyle: true,
          ),
        ],
        SizedBox(height: rowGap),
        OnboardingEqualGridRow(
          labels: const ['Not sure yet'],
          selectedIndices: widget.commuteDestinationUnknown ? {0} : const {},
          onSelected: widget.enabled
              ? (_) => widget.onCommuteDestinationUnknown?.call()
              : (_) {},
          compactLabel: true,
          dense: widget.compactPresets,
          seekerOptionStyle: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldHeight =
        widget.seekerPolishStyle ? 44.0 : listingFieldHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPresets) ...[
          if (widget.label.isNotEmpty) ...[
            Text(widget.label, style: listingFieldLabelStyle),
            const SizedBox(height: listingLabelSpacing),
          ],
          _buildPresetGrid(),
          const SizedBox(height: listingFieldSpacing),
        ],
        if (!widget.seekerPolishStyle)
          OnboardingFieldBlock(
            labelEmoji: '🎯',
            label: 'Custom destination',
            child: TapRegion(
              groupId: _tapGroup,
              onTapOutside: (_) {
                _focusNode.unfocus();
                _dismissOverlay();
              },
              child: CompositedTransformTarget(
                link: _layerLink,
                child: SizedBox(
                  key: _fieldAnchorKey,
                  height: fieldHeight,
                  child: TextFormField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    textInputAction: TextInputAction.done,
                    onChanged: _onQueryChanged,
                    onTap: () {
                      if (_suggestions.isNotEmpty || _searching) {
                        _renderOverlay();
                      }
                    },
                    style: listingFieldValueStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: listingInlineInputDecoration(
                      hint: 'Neighbourhood, campus, or workplace…',
                    ).copyWith(
                      prefixIcon: _searchPrefix(),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 40,
                      ),
                      suffixIcon: _locationSuffix(),
                      suffixIconConstraints: const BoxConstraints(
                        minHeight: 40,
                        minWidth: 0,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.accent,
                          width: listingDaftBorderWidth,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          TapRegion(
            groupId: _tapGroup,
            onTapOutside: (_) {
              _focusNode.unfocus();
              _dismissOverlay();
            },
            child: CompositedTransformTarget(
              link: _layerLink,
              child: SizedBox(
                key: _fieldAnchorKey,
                height: fieldHeight,
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  textInputAction: TextInputAction.done,
                  onChanged: _onQueryChanged,
                  onTap: () {
                    if (_suggestions.isNotEmpty || _searching) {
                      _renderOverlay();
                    }
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Neighbourhood, campus, or workplace…',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    prefixIcon: _searchPrefix(),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 40,
                    ),
                    suffixIcon: _locationSuffix(),
                    suffixIconConstraints: const BoxConstraints(
                      minHeight: 40,
                      minWidth: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A1A1A),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_searchError != null) ...[
          const SizedBox(height: 6),
          Text(
            _searchError!,
            style: listingSubLabelStyle.copyWith(
              color: const Color(0xFFB45309),
            ),
          ),
        ],
        if (_gpsError != null) ...[
          const SizedBox(height: 6),
          Text(
            _gpsError!,
            style: listingSubLabelStyle.copyWith(
              color: const Color(0xFFBE123C),
            ),
          ),
        ],
      ],
    );
  }
}
