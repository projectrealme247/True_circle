import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../services/nominatim_forward.dart';
import '../../utils/dublin_location_search_suggestions.dart';
import '../../utils/irish_address_format.dart';
import '../openstreetmap_attribution.dart';
import 'listing_creation_primitives.dart';

/// Interactive map widget for placing a location pin.
///
/// Pin placement and address search only centre the map until the user
/// confirms — [onPinPlaced] runs proximity + reverse geocode after confirm.
class LocationPinField extends StatefulWidget {
  const LocationPinField({
    super.key,
    this.initialLat,
    this.initialLon,
    this.pinLat,
    this.pinLon,
    this.externalLocationEpoch = 0,
    this.externalLocationLabel,
    required this.onPinPlaced,
    this.onPinDraft,
    this.enabled = true,
    this.mapHeight = 260,
    this.expandMap = false,
  });

  final double? initialLat;
  final double? initialLon;
  final double? pinLat;
  final double? pinLon;
  /// Bumped by the parent when GPS or another external source replaces the pin.
  final int externalLocationEpoch;
  /// Resolved label for [externalLocationEpoch] updates; `null` clears search/confirmation.
  final String? externalLocationLabel;
  final void Function(double lat, double lon) onPinPlaced;
  final VoidCallback? onPinDraft;
  final bool enabled;
  final double? mapHeight;
  final bool expandMap;

  @override
  State<LocationPinField> createState() => _LocationPinFieldState();
}

class _LocationPinFieldState extends State<LocationPinField> {
  static const _dublinCenter = LatLng(53.349805, -6.26031);
  static const _defaultZoom = 11.5;
  static const _dropdownMaxHeight = 176.0;

  late final MapController _mapController;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _searchFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<LocationSearchSuggestion> _suggestions = const [];
  bool _searching = false;
  int _searchGeneration = 0;
  int _highlightedIndex = -1;
  bool _pinConfirmed = false;
  String? _pendingLabel;
  String? _confirmedLabel;
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchController.addListener(_onQueryChanged);
    _focusNode.addListener(_onFocusChanged);
    if (widget.pinLat != null && widget.pinLon != null) {
      _pin = LatLng(widget.pinLat!, widget.pinLon!);
      _pinConfirmed = true;
    }
  }

  @override
  void didUpdateWidget(LocationPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalLocationEpoch != oldWidget.externalLocationEpoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncFromExternalLocation();
      });
      return;
    }
    if (widget.pinLat != oldWidget.pinLat ||
        widget.pinLon != oldWidget.pinLon) {
      if (widget.pinLat != null && widget.pinLon != null) {
        final newPin = LatLng(widget.pinLat!, widget.pinLon!);
        if (_pin != newPin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _pin = newPin);
            _mapController.move(newPin, 15.0);
          });
        }
      }
    }
  }

  void _setHighlightedIndex(int index) {
    if (_highlightedIndex == index) return;
    _highlightedIndex = index;
    _scheduleOverlayRefresh();
  }

  void _scheduleOverlayRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _syncFromExternalLocation() {
    _debounce?.cancel();
    _searchGeneration++;
    _removeOverlay();
    _focusNode.unfocus();

    final label = widget.externalLocationLabel?.trim();
    _searchController.removeListener(_onQueryChanged);
    _searchController.text = label ?? '';
    _searchController.addListener(_onQueryChanged);

    LatLng? newPin;
    if (widget.pinLat != null && widget.pinLon != null) {
      newPin = LatLng(widget.pinLat!, widget.pinLon!);
    }

    setState(() {
      _suggestions = const [];
      _searching = false;
      _highlightedIndex = -1;
      _pendingLabel = null;
      if (newPin != null) {
        _pin = newPin;
        _pinConfirmed = true;
        _confirmedLabel = label != null && label.isNotEmpty ? label : null;
      } else {
        _pin = null;
        _pinConfirmed = false;
        _confirmedLabel = null;
      }
    });

    if (newPin != null) {
      _mapController.move(newPin, 15.0);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _searchController.removeListener(_onQueryChanged);
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _focusNode.hasFocus) return;
        setState(() => _highlightedIndex = -1);
        _removeOverlay();
      });
    } else if (_shouldShowDropdown) {
      _renderOverlay();
    }
  }

  bool get _shouldShowDropdown {
    final query = _searchController.text.trim();
    if (query.length < 3) return false;
    return _searching || _suggestions.isNotEmpty || _focusNode.hasFocus;
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _highlightedIndex = -1;
        });
      }
      _removeOverlay();
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(applyFirst: false),
    );
  }

  Future<void> _runSearch({required bool applyFirst}) async {
    if (!widget.enabled) return;
    final gen = ++_searchGeneration;
    final query = _searchController.text.trim();
    if (query.length < 3) return;

    final local = searchLocalDublinAreaSuggestions(query);
    if (mounted && gen == _searchGeneration) {
      setState(() {
        _searching = true;
        _suggestions = local;
        _highlightedIndex = local.isNotEmpty ? 0 : -1;
      });
      if (!applyFirst && _focusNode.hasFocus) {
        _renderOverlay();
      }
    }

    try {
      final remote = await NominatimForward.searchAddress(query);
      if (!mounted || gen != _searchGeneration) return;

      final ranked = rankLocationSearchSuggestions(query, local, remote);
      setState(() {
        _suggestions = ranked;
        _searching = false;
        _highlightedIndex = ranked.isNotEmpty ? 0 : -1;
      });

      if (applyFirst && ranked.isNotEmpty) {
        _applySuggestion(ranked.first);
      } else if (_focusNode.hasFocus) {
        _renderOverlay();
      } else {
        _removeOverlay();
      }
    } catch (_) {
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _searching = false;
        _highlightedIndex = local.isNotEmpty ? 0 : -1;
      });
      if (applyFirst && local.isNotEmpty) {
        _applySuggestion(local.first);
      } else if (_focusNode.hasFocus) {
        _renderOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _applySuggestion(LocationSearchSuggestion suggestion) {
    final result = suggestion.result;
    final label = IrishAddressFormat.sanitizeCommaSeparatedLabel(
      result.displayLabel,
    );
    _searchController.removeListener(_onQueryChanged);
    _searchController.text = label;
    _searchController.addListener(_onQueryChanged);
    _searchGeneration++;

    final target = LatLng(result.lat, result.lon);
    _mapController.move(target, 15.0);
    _setPendingPin(target, label: label);

    setState(() {
      _suggestions = const [];
      _searching = false;
      _highlightedIndex = -1;
    });
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _setPendingPin(LatLng point, {String? label}) {
    setState(() {
      _pin = point;
      _pinConfirmed = false;
      _pendingLabel = label;
      _confirmedLabel = null;
    });
    widget.onPinDraft?.call();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.enabled) return;
    _setPendingPin(point);
  }

  void _confirmPin() {
    if (_pin == null || !widget.enabled) return;
    setState(() {
      _pinConfirmed = true;
      _confirmedLabel = _pendingLabel;
      _pendingLabel = null;
    });
    widget.onPinPlaced(_pin!.latitude, _pin!.longitude);
  }

  void _discardPendingPin() {
    setState(() {
      _pin = null;
      _pinConfirmed = false;
      _pendingLabel = null;
      _confirmedLabel = null;
    });
    widget.onPinDraft?.call();
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _setHighlightedIndex(
        (_highlightedIndex + 1).clamp(0, _suggestions.length - 1),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final next = _highlightedIndex - 1;
      _setHighlightedIndex(next < 0 ? _suggestions.length - 1 : next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final index = _highlightedIndex >= 0 ? _highlightedIndex : 0;
      if (index < _suggestions.length) {
        _debounce?.cancel();
        _applySuggestion(_suggestions[index]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _renderOverlay() {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      _removeOverlay();
      return;
    }

    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        width: _searchFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, listingFieldHeight + 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: _AnimatedSuggestionDropdown(
              child: _buildDropdownPanel(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildDropdownPanel() {
    final showEmpty = !_searching && _suggestions.isEmpty;

    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: listingDaftBorderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              if (_searching)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Searching locations…',
                        style: listingFieldLabelStyle.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              if (showEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Text(
                    'No locations found — try a street name or area',
                    style: listingFieldLabelStyle.copyWith(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                )
              else if (_suggestions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _dropdownMaxHeight,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      final highlighted = index == _highlightedIndex;
                      return _SuggestionRow(
                        suggestion: item,
                        highlighted: highlighted,
                        onTap: () => _applySuggestion(item),
                        onHover: (hovering) {
                          if (!hovering) return;
                          _setHighlightedIndex(index);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
    );
  }

  double _searchFieldWidth() {
    final box =
        _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width ?? 280;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildMap(LatLng center, double zoom, {double? height}) {
    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: _onMapTap,
        interactionOptions: InteractionOptions(
          flags: widget.enabled ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.truecircle.app',
        ),
        if (_pin != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _pin!,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_pin,
                  size: 40,
                  color: _pinConfirmed
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF97316),
                ),
              ),
            ],
          ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: height == null ? StackFit.expand : StackFit.loose,
          children: [
            map,
            Positioned(
              right: 6,
              bottom: _pin != null && !_pinConfirmed ? 56 : 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: OpenStreetMapAttribution(),
                ),
              ),
            ),
            if (_pin != null && !_pinConfirmed)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _mapConfirmCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mapConfirmCard() {
    final subtitle = _pendingLabel ??
        '${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}';

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Confirm this location?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.enabled ? _discardPendingPin : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: BorderSide(color: listingDaftBorderColor, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Move pin'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.enabled ? _confirmPin : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _pin ??
        (widget.initialLat != null && widget.initialLon != null
            ? LatLng(widget.initialLat!, widget.initialLon!)
            : _dublinCenter);
    final zoom = _pin != null ? 15.0 : _defaultZoom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CompositedTransformTarget(
                link: _layerLink,
                child: SizedBox(
                  key: _searchFieldKey,
                  height: listingFieldHeight,
                  child: Focus(
                    onKeyEvent: _handleSearchKey,
                    child: TextFormField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) {
                        _debounce?.cancel();
                        if (_highlightedIndex >= 0 &&
                            _highlightedIndex < _suggestions.length) {
                          _applySuggestion(_suggestions[_highlightedIndex]);
                          return;
                        }
                        _runSearch(applyFirst: true);
                      },
                      style: listingFieldValueStyle,
                      decoration: listingInlineInputDecoration(
                        hint: 'Search by location or address…',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                      ).copyWith(
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: listingFieldHeight,
              width: listingFieldHeight,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: widget.enabled && !_searching
                      ? () {
                          _debounce?.cancel();
                          _runSearch(applyFirst: true);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: listingDaftBorderColor,
                        width: listingDaftBorderWidth,
                      ),
                    ),
                    child: Center(
                      child: _searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.search,
                              size: 22,
                              color: Color(0xFF374151),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.expandMap)
          Expanded(child: _buildMap(center, zoom))
        else
          _buildMap(center, zoom, height: widget.mapHeight ?? 260),
        if (_pin != null && _pinConfirmed) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _confirmedLabel != null
                        ? 'Location confirmed — $_confirmedLabel'
                        : 'Location confirmed at ${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF15803D),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ] else if (_pin != null) ...[
          const SizedBox(height: 8),
          Text(
            'Tap Confirm on the map when the pin is in the right place.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade800,
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Search to centre the map, or tap to drop a pin — then confirm.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  final LocationSearchSuggestion suggestion;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      child: Material(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.08)
            : Colors.white,
        child: InkWell(
          onTap: onTap,
          hoverColor: AppColors.accent.withValues(alpha: 0.06),
          splashColor: AppColors.accent.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: highlighted ? AppColors.accentDark : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.primaryTitle,
                        style: listingFieldValueStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (suggestion.secondaryTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          suggestion.secondaryTitle,
                          style: listingFieldLabelStyle.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSuggestionDropdown extends StatefulWidget {
  const _AnimatedSuggestionDropdown({required this.child});

  final Widget child;

  @override
  State<_AnimatedSuggestionDropdown> createState() =>
      _AnimatedSuggestionDropdownState();
}

class _AnimatedSuggestionDropdownState extends State<_AnimatedSuggestionDropdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topCenter,
        child: widget.child,
      ),
    );
  }
}
