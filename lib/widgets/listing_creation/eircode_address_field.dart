import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/irish_address_suggestion.dart';
import '../../services/fast_location_service.dart';
import '../../services/nominatim_forward.dart';
import '../../utils/address_privacy.dart';
import 'listing_creation_primitives.dart';

/// Full address search field with Nominatim forward geocoding.
///
/// The user types a street address (e.g. "40 Ailesbury Road, Ballsbridge") and
/// we resolve coordinates via Nominatim. Eircode is captured as a separate
/// optional text input — it is never used for geocoding.
class EircodeAddressField extends StatefulWidget {
  const EircodeAddressField({
    super.key,
    required this.controller,
    required this.enabled,
    this.eircodeController,
    this.selected,
    this.hideExactAddress = false,
    this.fetchingLocation = false,
    this.onSelected,
    this.onHideExactAddressChanged,
    this.onUseCurrentLocation,
    this.showPrivacyGate = true,
    this.showLocationButton = false,
  });

  final TextEditingController controller;
  final TextEditingController? eircodeController;
  final bool enabled;
  final IrishAddressSuggestion? selected;
  final bool hideExactAddress;
  final bool fetchingLocation;
  final ValueChanged<IrishAddressSuggestion>? onSelected;
  final ValueChanged<bool>? onHideExactAddressChanged;
  final VoidCallback? onUseCurrentLocation;
  final bool showPrivacyGate;
  final bool showLocationButton;

  @override
  State<EircodeAddressField> createState() => _EircodeAddressFieldState();
}

class _EircodeAddressFieldState extends State<EircodeAddressField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<NominatimAddressResult> _suggestions = const [];
  bool _searching = false;
  int _searchGeneration = 0;
  String? _searchError;
  bool _isManualFallback = false;

  static const _borderColor = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onQueryChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(EircodeAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onQueryChanged);
      widget.controller.addListener(_onQueryChanged);
    }
    final selected = widget.selected;
    if (selected != oldWidget.selected && selected != null) {
      final label = selected.displayLabel.trim();
      if (widget.controller.text.trim() != label) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = widget.selected;
          if (current != null && current.displayLabel.trim() == label) {
            _syncFromSelected(current);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onQueryChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _focusNode.hasFocus) return;
        _removeOverlay();
        _acceptManualIfEdited();
      });
    } else if (_suggestions.isNotEmpty || _searching) {
      _renderOverlay();
    }
  }

  void _acceptManualIfEdited() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    final selectedLabel = widget.selected?.displayLabel.trim() ?? '';
    if (text == selectedLabel) return;
    final manual = _manualSuggestionFromText(text);
    widget.onSelected?.call(manual);
  }

  void _onQueryChanged() {
    final query = widget.controller.text.trim();
    final selectedLabel = widget.selected?.displayLabel.trim() ?? '';
    if (selectedLabel.isNotEmpty && query == selectedLabel) return;

    _debounce?.cancel();

    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _searchError = null;
        });
      }
      _removeOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    final gen = ++_searchGeneration;
    final query = widget.controller.text.trim();

    if (query.length < 3) return;

    if (mounted && gen == _searchGeneration) {
      setState(() {
        _searching = true;
        _searchError = null;
        _isManualFallback = false;
      });
      _renderOverlay();
    }

    try {
      final results = await NominatimForward.searchAddress(query);
      if (!mounted || gen != _searchGeneration) return;

      if (results.isNotEmpty) {
        setState(() {
          _suggestions = results;
          _searchError = null;
          _isManualFallback = false;
        });
      } else {
        setState(() {
          _suggestions = [
            NominatimAddressResult(
              displayLabel: query,
              lat: 0,
              lon: 0,
              streetLine: query,
              area: '',
              county: 'Dublin',
            ),
          ];
          _searchError = null;
          _isManualFallback = true;
        });
      }
    } catch (e) {
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _suggestions = [
          NominatimAddressResult(
            displayLabel: query,
            lat: 0,
            lon: 0,
            streetLine: query,
            area: '',
            county: 'Dublin',
          ),
        ];
        _searchError = null;
        _isManualFallback = true;
      });
    } finally {
      if (mounted && gen == _searchGeneration) {
        setState(() => _searching = false);
        if (_focusNode.hasFocus) {
          _renderOverlay();
        } else {
          _removeOverlay();
        }
      }
    }
  }

  IrishAddressSuggestion _manualSuggestionFromText(String text) {
    final parts =
        text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final streetLine = parts.isNotEmpty ? parts.first : text;
    final area = parts.length > 1 ? parts[1] : '';
    final county = parts.length > 2 ? parts[2] : 'Dublin';
    final lat = widget.selected?.latitude ?? 0;
    final lon = widget.selected?.longitude ?? 0;
    return IrishAddressSuggestion(
      displayLabel: text,
      streetLine: streetLine,
      area: area,
      county: county,
      eircode: widget.eircodeController?.text.trim(),
      latitude: lat,
      longitude: lon,
    );
  }

  void _applySuggestion(NominatimAddressResult result) {
    final eircode = widget.eircodeController?.text.trim();
    final suggestion = IrishAddressSuggestion(
      displayLabel: result.displayLabel,
      streetLine: result.streetLine,
      area: result.area,
      county: result.county,
      eircode: eircode?.isNotEmpty == true ? eircode : null,
      latitude: result.lat,
      longitude: result.lon,
    );
    widget.controller.removeListener(_onQueryChanged);
    widget.controller.text = result.displayLabel;
    widget.controller.addListener(_onQueryChanged);
    _searchGeneration++;
    setState(() {
      _suggestions = const [];
      _searchError = null;
      _searching = false;
      _isManualFallback = false;
    });
    _removeOverlay();
    _focusNode.unfocus();
    widget.onSelected?.call(suggestion);
  }

  void _syncFromSelected(IrishAddressSuggestion suggestion) {
    final label = suggestion.displayLabel.trim();
    if (widget.controller.text.trim() == label) {
      _removeOverlay();
      return;
    }
    widget.controller.removeListener(_onQueryChanged);
    widget.controller.text = label;
    widget.controller.addListener(_onQueryChanged);
    _searchGeneration++;
    if (!mounted) return;
    setState(() {
      _suggestions = const [];
      _searchError = null;
      _searching = false;
    });
    _removeOverlay();
  }

  void _renderOverlay() {
    final showLoading = _searching && _suggestions.isEmpty;
    final showSuggestions = _suggestions.isNotEmpty;
    if (!showLoading && !showSuggestions) {
      _removeOverlay();
      return;
    }
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _fieldWidth(context),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _borderColor, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: showLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          final isManual = _isManualFallback &&
                              _suggestions.length == 1;
                          return InkWell(
                            onTap: () => _applySuggestion(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isManual
                                        ? Icons.check_circle_outline
                                        : Icons.location_on_outlined,
                                    size: 16,
                                    color: isManual
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isManual
                                          ? 'Use: ${item.displayLabel}'
                                          : item.displayLabel,
                                      style: listingFieldValueStyle.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isManual
                                            ? const Color(0xFF059669)
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  double _fieldWidth(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? MediaQuery.sizeOf(context).width - 48;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final showGate = widget.showPrivacyGate && selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: SizedBox(
            height: listingFieldHeight,
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) {
                _debounce?.cancel();
                _runSearch();
              },
              style: listingFieldValueStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: listingInlineInputDecoration(
                hint: 'e.g. 40 Ailesbury Road, Ballsbridge, Dublin 4',
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
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
        if (widget.eircodeController != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: listingFieldHeight,
            child: TextFormField(
              controller: widget.eircodeController,
              enabled: widget.enabled,
              textCapitalization: TextCapitalization.characters,
              style: listingFieldValueStyle.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
              decoration: listingInlineInputDecoration(
                hint: 'Eircode (optional) e.g. D04 V9H2',
              ),
            ),
          ),
        ],
        if (widget.showLocationButton) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.enabled &&
                    !widget.fetchingLocation &&
                    widget.onUseCurrentLocation != null
                ? widget.onUseCurrentLocation
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: _borderColor, width: 1),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: widget.fetchingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined, size: 18),
            label: const Text('Use current location'),
          ),
        ],
        if (showGate) ...[
          const SizedBox(height: 14),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: widget.hideExactAddress,
            onChanged: widget.enabled
                ? (v) => widget.onHideExactAddressChanged?.call(v ?? false)
                : null,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              "I don't want to display the exact address",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            activeColor: const Color(0xFF4B5563),
            checkColor: Colors.white,
            side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
          ),
          if (widget.hideExactAddress) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Public preview',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PreviewRow(label: 'Area', value: selected.area),
                  const SizedBox(height: 6),
                  _PreviewRow(label: 'County', value: selected.county),
                  const SizedBox(height: 8),
                  Text(
                    AddressPrivacy.publicLocationFrom(
                      area: selected.area,
                      county: selected.county,
                      hideExact: true,
                    ),
                    style: listingFieldValueStyle.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

/// Documents the coarse GPS timeout used by [FastLocationService].
const Duration eircodeFieldGpsTimeout = FastLocationService.gpsTimeout;
